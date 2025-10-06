# frozen_string_literal: true

module DomeAPI
  class OrderHistoryResponse
    attr_reader :orders, :pagination

    def initialize(orders: [], pagination: {})
      @orders = orders.map { |order_data| Order.new(order_data) }
      @pagination = pagination
    end

    def total_orders
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
      orders.empty?
    end

    def size
      orders.size
    end

    def each(&block)
      orders.each(&block)
    end

    def [](index)
      orders[index]
    end

    def to_a
      orders
    end

    def to_h
      {
        orders: orders.map(&:to_h),
        pagination: pagination
      }
    end

    def to_json(*args)
      to_h.to_json(*args)
    end
  end
end
