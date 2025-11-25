# frozen_string_literal: true

module DomeAPI
  class MarketsResponse
    attr_reader :markets, :pagination

    def initialize(markets: [], pagination: {})
      @markets = markets.map { |market_data| Market.new(market_data) }
      @pagination = pagination
    end

    def total_markets
      pagination[:total] || 0
    end

    def limit
      pagination[:limit] || 0
    end

    def offset
      pagination[:offset] || 0
    end

    def has_more?
      pagination[:has_more] || false
    end

    def empty?
      markets.empty?
    end

    def size
      markets.size
    end

    def each(&block)
      markets.each(&block)
    end

    def [](index)
      markets[index]
    end

    def to_a
      markets
    end

    def to_h
      {
        markets: markets.map(&:to_h),
        pagination: pagination
      }
    end

    def to_json(*args)
      to_h.to_json(*args)
    end
  end
end
