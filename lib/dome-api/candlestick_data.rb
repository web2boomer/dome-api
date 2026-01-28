# frozen_string_literal: true

require 'time'

module DomeAPI
  class CandlestickData
    attr_reader :end_period_ts, :open_interest, :volume, :price, :yes_ask, :yes_bid

    def initialize(attributes = {})
      @end_period_ts = attributes[:end_period_ts]
      @open_interest = attributes[:open_interest]
      @volume = attributes[:volume]
      @price = PriceData.new(attributes[:price] || {})
      @yes_ask = BidAskData.new(attributes[:yes_ask] || {})
      @yes_bid = BidAskData.new(attributes[:yes_bid] || {})
    end

    def end_time
      return nil unless @end_period_ts
      Time.at(@end_period_ts)
    end

    def formatted_end_time(format = :default)
      return nil unless end_time
      
      case format
      when :iso
        end_time.iso8601
      when :readable
        end_time.strftime("%Y-%m-%d %H:%M:%S UTC")
      else
        end_time.to_s
      end
    end

    def price_range
      return 0 unless @price
      @price.high - @price.low
    end

    def price_change
      return 0 unless @price
      @price.close - @price.open
    end

    def price_change_percent
      return 0 if @price&.open&.zero?
      (price_change / @price.open) * 100
    end

    def to_h
      {
        end_period_ts: @end_period_ts,
        open_interest: @open_interest,
        volume: @volume,
        price: @price&.to_h,
        yes_ask: @yes_ask&.to_h,
        yes_bid: @yes_bid&.to_h
      }
    end

    def to_json(*args)
      to_h.to_json(*args)
    end

    def to_s
      "Candlestick: O:#{@price&.open} H:#{@price&.high} L:#{@price&.low} C:#{@price&.close} V:#{@volume}"
    end
  end

  class PriceData
    attr_reader :open, :high, :low, :close, :mean, :previous,
                :open_dollars, :high_dollars, :low_dollars, :close_dollars,
                :mean_dollars, :previous_dollars

    def initialize(attributes = {})
      @open = attributes[:open]
      @high = attributes[:high]
      @low = attributes[:low]
      @close = attributes[:close]
      @mean = attributes[:mean]
      @previous = attributes[:previous]
      @open_dollars = attributes[:open_dollars]
      @high_dollars = attributes[:high_dollars]
      @low_dollars = attributes[:low_dollars]
      @close_dollars = attributes[:close_dollars]
      @mean_dollars = attributes[:mean_dollars]
      @previous_dollars = attributes[:previous_dollars]
    end

    def to_h
      {
        open: @open,
        high: @high,
        low: @low,
        close: @close,
        mean: @mean,
        previous: @previous,
        open_dollars: @open_dollars,
        high_dollars: @high_dollars,
        low_dollars: @low_dollars,
        close_dollars: @close_dollars,
        mean_dollars: @mean_dollars,
        previous_dollars: @previous_dollars
      }
    end

    def to_json(*args)
      to_h.to_json(*args)
    end
  end

  class BidAskData
    attr_reader :open, :close, :high, :low,
                :open_dollars, :close_dollars, :high_dollars, :low_dollars

    def initialize(attributes = {})
      @open = attributes[:open]
      @close = attributes[:close]
      @high = attributes[:high]
      @low = attributes[:low]
      @open_dollars = attributes[:open_dollars]
      @close_dollars = attributes[:close_dollars]
      @high_dollars = attributes[:high_dollars]
      @low_dollars = attributes[:low_dollars]
    end

    def spread
      return 0 unless @open && @close
      @open - @close
    end

    def to_h
      {
        open: @open,
        close: @close,
        high: @high,
        low: @low,
        open_dollars: @open_dollars,
        close_dollars: @close_dollars,
        high_dollars: @high_dollars,
        low_dollars: @low_dollars
      }
    end

    def to_json(*args)
      to_h.to_json(*args)
    end
  end
end
