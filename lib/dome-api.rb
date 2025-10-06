# frozen_string_literal: true

require_relative "dome-api/version"
require_relative "dome-api/client"
require_relative "dome-api/order"
require_relative "dome-api/order_history_response"
require_relative "dome-api/market_price"
require_relative "dome-api/candlestick_data"
require_relative "dome-api/candlestick_response"
require_relative "dome-api/pnl_data"
require_relative "dome-api/wallet_pnl_response"

module DomeAPI
  class Error < StandardError; end
  # Your code goes here...
end
