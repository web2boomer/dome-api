# frozen_string_literal: true

module DomeAPI
  class CandlestickResponse
    attr_reader :candlesticks, :token_id

    def initialize(candlesticks: [], token_id: nil)
      @candlesticks = candlesticks.map { |data| CandlestickData.new(data) }
      @token_id = token_id
    end

    def empty?
      candlesticks.empty?
    end

    def size
      candlesticks.size
    end

    def each(&block)
      candlesticks.each(&block)
    end

    def [](index)
      candlesticks[index]
    end

    def first
      candlesticks.first
    end

    def last
      candlesticks.last
    end

    def price_data
      candlesticks.map(&:price)
    end

    def volume_data
      candlesticks.map(&:volume)
    end

    def open_interest_data
      candlesticks.map(&:open_interest)
    end

    def time_series
      candlesticks.map { |c| [c.end_time, c.price&.close] }.compact
    end

    def price_range
      return 0 if candlesticks.empty?
      
      prices = candlesticks.flat_map { |c| [c.price&.high, c.price&.low] }.compact
      return 0 if prices.empty?
      
      prices.max - prices.min
    end

    def total_volume
      candlesticks.sum(&:volume)
    end

    def average_volume
      return 0 if candlesticks.empty?
      total_volume / candlesticks.size.to_f
    end

    def price_trend
      return :unknown if candlesticks.size < 2
      
      first_price = candlesticks.first.price&.close
      last_price = candlesticks.last.price&.close
      
      return :unknown unless first_price && last_price
      
      if last_price > first_price
        :up
      elsif last_price < first_price
        :down
      else
        :flat
      end
    end

    def to_a
      candlesticks
    end

    def to_h
      {
        candlesticks: candlesticks.map(&:to_h),
        token_id: token_id
      }
    end

    def to_json(*args)
      to_h.to_json(*args)
    end
  end
end
