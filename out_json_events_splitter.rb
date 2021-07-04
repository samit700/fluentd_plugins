require 'fluent/plugin/output'
require 'fluent/mixin'
require 'fluent/mixin/config_placeholders'
require 'fluent/mixin/rewrite_tag_name'

module Fluent
  module Plugin
    class JsonEventsSplitterOutput < Output
      Fluent::Plugin.register_output('json_events_splitter', self)

      config_param :tag, :string, default: nil
      config_param :events_key, :string
      config_param :props_key, :string, default: nil
      config_param :keep_props, :bool, default: true
      config_param :stringify_keys, :array, default: []

      include SetTagKeyMixin
      include Fluent::Mixin::ConfigPlaceholders
      include HandleTagNameMixin
      include Fluent::Mixin::RewriteTagName

      helpers :event_emitter

      def multi_workers_ready?
        true
      end

      def configure(conf)
        super
        if @events_key.empty?
          raise Fluent::ConfigError, 'events_key must be set.'
        end
        if @keep_props && @props_key.empty?
          raise Fluent::ConfigError, 'props_key must be set when keep_props is enabled.'
        end
      end

      def process(tag, es)
        emit_tag = tag.dup

        es.each do |time, record|
          filter_record(emit_tag, time, record)

		  events = Array.new
		  props = Hash.new
		  record.each do |k, v|
		    if k.eql?("jsonString")
			  events = Yajl.load(v)	
		    elsif @keep_props && k.eql?("properties")
			  props = v
		    end
		  end

		  events.each do |e|
		    e.merge!(props)
			(e.keys & stringify_keys).each {|k| e[k] = e[k].to_json}
            router.emit(emit_tag, time, e)
          end
        end
      end
    end
  end
end