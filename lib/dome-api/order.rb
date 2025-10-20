# frozen_string_literal: true

module DomeAPI
  class Order
    attr_reader :token_id, :side, :market_slug, :condition_id, :shares, 
                :shares_normalized, :price, :tx_hash, :title, :timestamp, 
                :order_hash, :user

    def initialize(attributes = {})
      # ap attributes
      @token_id = attributes[:token_id]
      @side = attributes[:side]
      @market_slug = attributes[:market_slug]
      @condition_id = attributes[:condition_id]
      @shares = attributes[:shares]
      @shares_normalized = attributes[:shares_normalized]
      @price = attributes[:price]
      @tx_hash = attributes[:tx_hash]
      @title = attributes[:title]
      @timestamp = attributes[:timestamp]
      @order_hash = attributes[:order_hash]
      @user = attributes[:user]
    end

    def buy?
      side == 'BUY'
    end

    def sell?
      side == 'SELL'
    end

    def to_h
      {
        token_id: @token_id,
        side: @side,
        market_slug: @market_slug,
        condition_id: @condition_id,
        shares: @shares,
        shares_normalized: @shares_normalized,
        price: @price,
        tx_hash: @tx_hash,
        title: @title,
        timestamp: @timestamp,
        order_hash: @order_hash,
        user: @user
      }
    end

    def to_json(*args)
      to_h.to_json(*args)
    end
  end
end
