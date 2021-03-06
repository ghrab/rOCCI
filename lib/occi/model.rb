require 'hashie/mash'
require 'occi/log'

module OCCI
  class Model
    attr_accessor :categories
    attr_accessor :locations

    # @param [OCCI::Core::Collection] collection
    def initialize(collection=nil)
      @categories = { }
      @locations  = { }
      register_core
      register_collection collection if collection.kind_of? OCCI::Collection
    end

    # register OCCI Core categories enitity, resource and link
    def register_core
      OCCI::Log.info "### Registering OCCI Core categories enitity, resource and link ###"
      register OCCI::Core::Entity.kind_definition
      register OCCI::Core::Resource.kind_definition
      register OCCI::Core::Link.kind_definition
    end

    # register OCCI Infrastructure categories
    def register_infrastructure
      OCCI::Log.info "### Registering OCCI Infrastructure categories ###"
      register_files  File.dirname(__FILE__) + '/../../etc/model/infrastructure'
    end

    # register OCCI categories from files
    #
    # @param [String] path to a folder containing files which include OCCI collections in JSON format. The path is
    #  recursively searched for files with the extension .json .
    # @param [Sting] scheme_base_url base location for provider specific extensions of the OCCI model
    def register_files(path, scheme_base_url='http://localhost')
      OCCI::Log.info "### Initializing OCCI Model from #{path} ###"
      Dir.glob(path + '/**/*.json').each do |file|
        collection = OCCI::Collection.new(JSON.parse(File.read(file)))
        # add location of service provider to scheme if it has a relative location
        collection.kinds.collect { |kind| kind.scheme = scheme_base_url + kind.scheme if kind.scheme.start_with? '/' } if collection.kinds
        collection.mixins.collect { |mixin| mixin.scheme = scheme_base_url + mixin.scheme if mixin.scheme.start_with? '/' } if collection.mixins
        collection.actions.collect { |action| action.scheme = scheme_base_url + action.scheme if action.scheme.start_with? '/' } if collection.actions
        register_collection collection
      end
    end

    # register OCCI categories from OCCI collection
    def register_collection(collection)
      collection.categories.each { |category| register category }
    end

    # clear all entities from all categories
    def reset()
      @categories.each_value.each { |category| category.entities = [] if category.respond_to? :entities }
    end

    # @param [OCCI::Core::Category] category
    def register(category)
      OCCI::Log.debug "### Registering category #{category.type_identifier}"
      @categories[category.type_identifier] = category
      @locations[category.location] = category.type_identifier unless category.kind_of? OCCI::Core::Action
      # add model to category as back reference
      category.model = self
    end

    # @param [OCCI::Core::Category] category
    def unregister(category)
      OCCI::Log.debug "### Unregistering category #{category.type_identifier}"
      @categories.delete category.type_identifier
      @locations.delete category.location unless category.kind_of? OCCI :Core::Action
    end

    # Returns the category corresponding to a given type identifier
    #
    # @param [URI] id type identifier of a category
    # @return [OCCI::Core::Category]
    def get_by_id(id)
      @categories.fetch(id) { OCCI::Log.debug("Category with id #{id} not found"); nil }
    end

    # Returns the category corresponding to a given location
    #
    # @param [URI] location
    # @return [OCCI::Core::Category]
    def get_by_location(location)
      id = @locations.fetch(location) { OCCI::Log.debug("Category with location #{location} not found"); nil }
      get_by_id id
    end

    # Return all categories from model. If filter is present, return only the categories specified by filter
    #
    # @param [OCCI::Collection] filter
    # @return [OCCI::Collection] collection
    def get(filter = OCCI::Collection.new)
      collection = OCCI::Collection.new
      if filter.empty?
        @categories.each_value do |category|
          collection.kinds << category if category.kind_of? OCCI::Core::Kind
          collection.mixins << category if category.kind_of? OCCI::Core::Mixin
          collection.actions << category if category.kind_of? OCCI::Core::Action
        end
      else
        categories = filter.categories
        OCCI::Log.debug("### Filtering categories #{categories.collect { |c| c.type_identifier }.inspect}")
        while categories.any? do
          category = categories.pop
          categories.concat @categories.each_value.select { |cat| cat.related_to?(category.type_identifier) }
          collection.kinds << get_by_id(category.type_identifier) if category.kind_of? OCCI::Core::Kind
          collection.mixins << get_by_id(category.type_identifier) if category.kind_of? OCCI::Core::Mixin
          collection.actions << get_by_id(category.type_identifier) if category.kind_of? OCCI::Core::Action
        end
      end
      collection
    end

  end
end