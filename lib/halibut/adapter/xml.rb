require 'nokogiri'

require 'halibut/core/resource'
require 'halibut/core/link'

module Halibut::Adapter

  module XML
    def self.parse(xml)
      ResourceExtractor.new(xml).resource
    end

    def self.render(resource)
      raise NotImplementedError
    end

    private
    def self.extended(base)
      base.extend InstanceMethods
    end

    module InstanceMethods
      def to_xml
        raise NotImplementedError
      end
    end

    class ResourceExtractor

      attr_reader :resource

      def initialize(xml)
        xml = Nokogiri::XML(xml)

        @document = xml.root
        @resource = Halibut::Core::Resource.new Halibut::Core::Link.new(extract_self_link)

        extract_curie
        extract_properties
        extract_links
        extract_resources
      end

      private
      def extract_self_link
        @document.attr 'href'
      end

      def extract_curie
        @document.namespace_scopes
                 .reject {|ns| ns.prefix.eql? 'xsi' }
                 .each do |ns|
          @resource.add_link 'curie', Halibut::Core::Link.new(ns.href, name: ns.prefix)
        end
      end

      def extract_properties
        properties = @document.xpath '/resource/*[not(self::link) and not(self::resource)]'

        properties.each do |property|
          @resource[property.name] = property.content
        end
      end

      def extract_links
        links = @document.xpath('/resource/link')

        links.each do |link|
          @resource.add_link link['rel'],
                             Halibut::Core::Link.new(link['href'],
                                                     extract_link_options(link))
        end
      end

      # In case there are no options on the link, it returns an empty hash
      def extract_link_options(link)
        Hash[link.reject {|(key)| key.eql? 'rel'  }
                 .reject {|(key)| key.eql? 'href' }]
      end

      def extract_resources
        @document.xpath('/resource/resource')
                 .map  {|r| [] << r['rel'] << ResourceExtractor.new(r.to_xml).resource }
                 .each {|rel,res| @resource.embed_resource rel, res }
      end
    end
  end

end
