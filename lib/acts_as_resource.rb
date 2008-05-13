module Labs23
  module Acts #:nodoc:
    module Resource #:nodoc:

      def self.included(mod)
        mod.extend(ClassMethods)
      end
        
      module ClassMethods
        def acts_as_resource
          class_eval <<-END
            extend Labs23::Acts::Resource::SingletonMethods
            class Local < LocalResource
              set_table_name "#{self.name.downcase.tableize}"
            end
            class Remote < RemoteResource
              set_element_name "#{self.name.downcase}"
            end
          END
          include Labs23::Acts::Resource::InstanceMethods
        end
        
        def method_missing(method_name, *args)
          remote = remote_request?(*args)
          result = instantiate_storage(remote).class.send(method_name, *args)
          result = wrap_storages_into_resources(result, remote) if !result.nil? and
                                                                   /^find_(all_by|by)_([_a-zA-Z]\w*)$/.match(method_name.to_s) or
                                                                   /^find_or_(initialize|create)_by_([_a-zA-Z]\w*)$/.match(method_name.to_s)
          result
        end
        
        def remote_request?(*args)
          if args.last.is_a?(Hash)
            args.last.delete(:remote)
          else
            false
          end
        end
        
        def instantiate_storage(remote, params = {})
          remote ? self::Remote.new(params) : self::Local.new(params)
        end
        
        def find_method(*args)
          arg = args.first.is_a?(Array) ? args.first.first : args.first
          arg.to_s[/^select([\w\s\*\.\,\_\-]*)from/mi] ? 'find_by_sql' : 'find'
        end
      end

      module SingletonMethods
        def find(*args)
          remote, method = remote_request?(*args), find_method(*args)
          storages = instantiate_storage(remote).class.send(method, *args)
          wrap_storages_into_resources(storages, remote)
        end
        
        alias_method :find_by_sql, :find
        
        def site=(site)
          self::Remote.site = site
        end
                
        def wrap_storages_into_resources(storages, remote)
          resources = []
          storages = storages.kind_of?(Array) ? storages : [storages]
          storages.each do |storage|
            resources << self.new(:remote => remote, :storage => storage)
          end

          resources.size == 1 ? resources.first : resources
        end
      end

      module InstanceMethods
        attr_reader :remote, :storage
        
        def initialize(params = {})
          @remote = params.delete(:remote) || false
          @storage = params.delete(:storage) || self.class.instantiate_storage(@remote, params)
        end

        def id; @storage.id end
        def remote?; @remote end
                
        def to_xml(*args)
          @storage.to_xml(*args)
        end
        alias_method :to_s, :to_xml
        alias_method :to_param, :id

        protected
        def method_missing(method_name, *args)
          @storage.send(method_name, *args)
        end        
      end
      
      class LocalResource < ActiveRecord::Base
        alias_method :active_record_method_missing, :method_missing
        def method_missing(method_name, *args)
          obj = self.class.name[/^[\w\s]+/].constantize.new
          if obj.methods.include?(method_name.to_s)
            obj.instance_variable_set(:@remote, false)
            obj.instance_variable_set(:@storage, self)
            obj.send(method_name, *args)
          else
            obj = nil
            active_record_method_missing(method_name, *args)
          end
        end
      end
      
      class RemoteResource < ActiveResource::Base
      end
    end
  end
end

module ActiveRecord
  class XmlSerializer
    alias_method :xml_serializer_root, :root
    def root
      xml_serializer_root.split('/').first
    end
  end
end