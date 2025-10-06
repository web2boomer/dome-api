# frozen_string_literal: true

module DomeAPI
  class PnLData
    attr_reader :timestamp, :pnl_to_date

    def initialize(attributes = {})
      @timestamp = attributes[:timestamp]
      @pnl_to_date = attributes[:pnl_to_date]
    end

    def time
      return nil unless @timestamp
      Time.at(@timestamp)
    end

    def formatted_time(format = :default)
      return nil unless time
      
      case format
      when :iso
        time.iso8601
      when :readable
        time.strftime("%Y-%m-%d %H:%M:%S UTC")
      when :date_only
        time.strftime("%Y-%m-%d")
      else
        time.to_s
      end
    end

    def pnl_dollars
      return nil unless @pnl_to_date
      @pnl_to_date / 100.0 # Assuming PnL is in cents
    end

    def profit?
      return false unless @pnl_to_date
      @pnl_to_date > 0
    end

    def loss?
      return false unless @pnl_to_date
      @pnl_to_date < 0
    end

    def break_even?
      return false unless @pnl_to_date
      @pnl_to_date == 0
    end

    def to_h
      {
        timestamp: @timestamp,
        pnl_to_date: @pnl_to_date
      }
    end

    def to_json(*args)
      to_h.to_json(*args)
    end

    def to_s
      pnl_str = @pnl_to_date ? "$#{pnl_dollars.round(2)}" : "N/A"
      "PnL: #{pnl_str} at #{formatted_time(:readable)}"
    end
  end
end
