require 'yajl'
require 'fluent/parser'

module Fluent
  class TextParser
    class JSONInJSONParser < Parser
      Fluent::Plugin.register_parser('json_in_json', self)

      config_param :time_key, :string, :default => 'time'
      config_param :time_format, :string, :default => nil

      def configure(conf)
        super

        unless @time_format.nil?
          @time_parser = TimeParser.new(@time_format)
          @mutex = Mutex.new
        end
      end

      def parse(text)
        record = Yajl.load(text)

        value = @keep_time_key ? record[@time_key] : record.delete(@time_key)
        if value
          if @time_format
            time = @mutex.synchronize { @time_parser.parse(value) }
          else
            begin
              time = value.to_i
            rescue => e
              raise ParserError, "invalid time value: value = #{value}, error_class = #{e.class.name}, error = #{e.message}"
            end
          end
        else
          if @estimate_current_event
            time = Engine.now
          else
            time = nil
          end
        end

		events = Array.new
		properties = Hash.new
		record.each do |k, v|
		  if k.eql?("jsonString")
			events = Yajl.load(v)	
		  elsif k.eql?("properties")
			properties = v
		  end
		end

		events.each {|e| e.merge!(properties)}
		
        if block_given?
		  events.each {|e| yield time, e} 
          yield time, events
        else
		  events.each {|e| yield time, e} 
        end
      rescue Yajl::ParseError
        if block_given?
          yield nil, nil
        else
          return nil, nil
        end
      end
    end	
  end
end
