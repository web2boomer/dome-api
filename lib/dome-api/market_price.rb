# frozen_string_literal: true

module DomeAPI
  class MarketPrice
    attr_reader :price, :at_time

    def initialize(attributes = {})
      @price = attributes[:price]
      @at_time = attributes[:at_time]
    end

    def current?
      # Consider price current if at_time is within the last 5 minutes
      return false unless @at_time
      
      current_time = Time.now.to_i
      (current_time - @at_time) <= 300 # 5 minutes in seconds
    end

    def historical?
      !current?
    end

    def timestamp
      return nil unless @at_time
      Time.at(@at_time)
    end

    def formatted_time(format = :default)
      return nil unless timestamp
      
      case format
      when :iso
        timestamp.iso8601
      when :readable
        timestamp.strftime("%Y-%m-%d %H:%M:%S UTC")
      else
        timestamp.to_s
      end
    end

    def to_h
      {
        price: @price,
        at_time: @at_time
      }
    end

    def to_json(*args)
      to_h.to_json(*args)
    end

    def to_s
      "Market Price: $#{@price} at #{formatted_time(:readable)}"
    end
  end
end
