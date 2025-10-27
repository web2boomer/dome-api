# frozen_string_literal: true
require 'net/http'
require 'uri'
require 'json'

module DomeAPI
  class Client
    BASE_URL = 'https://api.domeapi.io/v1'
    
    def initialize(api_key: nil)
      @api_key = api_key
    end

    # Fetches historical order data with optional filtering
    # @param options [Hash] Query parameters for filtering orders
    # @option options [String] :market_slug Filter orders by market slug
    # @option options [String] :condition_id Filter orders by condition ID
    # @option options [String] :token_id Filter orders by token ID
    # @option options [Integer] :start_time Filter orders from this Unix timestamp in seconds (inclusive)
    # @option options [Integer] :end_time Filter orders until this Unix timestamp in seconds (inclusive)
    # @option options [Integer] :limit Number of orders to return (1-1000, default: 100)
    # @option options [Integer] :offset Number of orders to skip for pagination (default: 0)
    # @option options [String] :user Filter orders by user (wallet address)
    # @return [OrderHistoryResponse] Response containing orders array and pagination info
    def get_order_history(options = {})
      validate_order_history_params(options)
      
      uri = build_order_history_uri(options)
      response = make_request(uri)
      
      parse_order_history_response(response)
    end


    # Fetches activity data for a specific user with optional filtering
    # @param user [String] User wallet address to fetch activity for (required)
    # @param options [Hash] Query parameters for filtering activities
    # @option options [Integer] :start_time Filter activity from this Unix timestamp in seconds (inclusive)
    # @option options [Integer] :end_time Filter activity until this Unix timestamp in seconds (inclusive)
    # @option options [String] :market_slug Filter activity by market slug
    # @option options [String] :condition_id Filter activity by condition ID
    # @option options [Integer] :limit Number of activities to return (1-1000, default: 100)
    # @option options [Integer] :offset Number of activities to skip for pagination (default: 0)
    # @return [ActivityResponse] Response containing activities array and pagination info
    def get_activity(user, options = {})
      validate_wallet_address(user)
      validate_activity_params(options)
      
      uri = build_activity_uri(user, options)
      response = make_request(uri)
      
      parse_activity_response(response)
    end    

    # Fetches the current market price for a market by token_id
    # @param token_id [String] The token ID of the market
    # @param at_time [Integer, nil] Unix timestamp to fetch historical price (optional)
    # @return [MarketPrice] Market price data
    def get_market_price(token_id, at_time: nil)
      validate_token_id(token_id)
      validate_at_time(at_time) if at_time
      
      uri = build_market_price_uri(token_id, at_time)
      response = make_request(uri)
      
      parse_market_price_response(response)
    end

    # Fetches historical candlestick data for a market by condition_id
    # @param condition_id [String] The condition ID of the market
    # @param start_time [Integer] Unix timestamp for start of time range
    # @param end_time [Integer] Unix timestamp for end of time range
    # @param interval [Integer] Interval length: 1 = 1m, 60 = 1h, 1440 = 1d (default: 1)
    # @return [CandlestickResponse] Response containing candlestick data
    def get_candlesticks(condition_id, start_time:, end_time:, interval: 1)
      validate_condition_id(condition_id)
      validate_time_range(start_time, end_time)
      validate_interval(interval)
      
      uri = build_candlesticks_uri(condition_id, start_time, end_time, interval)
      response = make_request(uri)
      
      parse_candlesticks_response(response)
    end

    # Fetches the profit-and-loss over a time range for a given wallet address
    # @param wallet_address [String] The wallet address to get PnL for
    # @param granularity [String] Time granularity: "day", "week", "month", "year", "all"
    # @param start_time [Integer, nil] Unix timestamp for start of time range (optional)
    # @param end_time [Integer, nil] Unix timestamp for end of time range (optional)
    # @return [WalletPnLResponse] Response containing PnL data
    def get_wallet_pnl(wallet_address, granularity:, start_time: nil, end_time: nil)
      validate_wallet_address(wallet_address)
      validate_granularity(granularity)
      validate_optional_time_range(start_time, end_time) if start_time || end_time
      
      uri = build_wallet_pnl_uri(wallet_address, granularity, start_time, end_time)
      response = make_request(uri)
      
      parse_wallet_pnl_response(response)
    end


    private

    def validate_order_history_params(options)
      if options[:limit] && (options[:limit] < 1 || options[:limit] > 1000)
        raise ArgumentError, "Limit must be between 1 and 1000"
      end
      
      if options[:offset] && options[:offset] < 0
        raise ArgumentError, "Offset must be >= 0"
      end
    end

    def validate_token_id(token_id)
      if token_id.nil? || token_id.to_s.strip.empty?
        raise ArgumentError, "Token ID cannot be empty"
      end
    end

    def validate_at_time(at_time)
      unless at_time.is_a?(Integer) && at_time > 0
        raise ArgumentError, "at_time must be a positive integer (Unix timestamp)"
      end
    end

    def validate_condition_id(condition_id)
      if condition_id.nil? || condition_id.to_s.strip.empty?
        raise ArgumentError, "Condition ID cannot be empty"
      end
    end

    def validate_time_range(start_time, end_time)
      unless start_time.is_a?(Integer) && start_time > 0
        raise ArgumentError, "start_time must be a positive integer (Unix timestamp)"
      end
      
      unless end_time.is_a?(Integer) && end_time > 0
        raise ArgumentError, "end_time must be a positive integer (Unix timestamp)"
      end
      
      if start_time >= end_time
        raise ArgumentError, "start_time must be less than end_time"
      end
    end

    def validate_interval(interval)
      valid_intervals = [1, 60, 1440]
      unless valid_intervals.include?(interval)
        raise ArgumentError, "interval must be one of: #{valid_intervals.join(', ')} (1=1m, 60=1h, 1440=1d)"
      end
    end

    def validate_wallet_address(wallet_address)
      if wallet_address.nil? || wallet_address.to_s.strip.empty?
        raise ArgumentError, "Wallet address cannot be empty"
      end
      
      # Basic Ethereum address validation (42 characters, starts with 0x)
      unless wallet_address.to_s.match?(/\A0x[a-fA-F0-9]{40}\z/)
        raise ArgumentError, "Invalid wallet address format. Must be a valid Ethereum address (0x followed by 40 hex characters)"
      end
    end

    def validate_granularity(granularity)
      valid_granularities = %w[day week month year all]
      unless valid_granularities.include?(granularity.to_s)
        raise ArgumentError, "granularity must be one of: #{valid_granularities.join(', ')}"
      end
    end

    def validate_optional_time_range(start_time, end_time)
      if start_time && (!start_time.is_a?(Integer) || start_time <= 0)
        raise ArgumentError, "start_time must be a positive integer (Unix timestamp)"
      end
      
      if end_time && (!end_time.is_a?(Integer) || end_time <= 0)
        raise ArgumentError, "end_time must be a positive integer (Unix timestamp)"
      end
      
      if start_time && end_time && start_time >= end_time
        raise ArgumentError, "start_time must be less than end_time"
      end
    end

    def validate_activity_params(options)
      if options[:limit] && (options[:limit] < 1 || options[:limit] > 1000)
        raise ArgumentError, "Limit must be between 1 and 1000"
      end
      
      if options[:offset] && options[:offset] < 0
        raise ArgumentError, "Offset must be >= 0"
      end
      
      if options[:start_time] && (!options[:start_time].is_a?(Integer) || options[:start_time] <= 0)
        raise ArgumentError, "start_time must be a positive integer (Unix timestamp)"
      end
      
      if options[:end_time] && (!options[:end_time].is_a?(Integer) || options[:end_time] <= 0)
        raise ArgumentError, "end_time must be a positive integer (Unix timestamp)"
      end
      
      if options[:start_time] && options[:end_time] && options[:start_time] >= options[:end_time]
        raise ArgumentError, "start_time must be less than end_time"
      end
    end

    def build_order_history_uri(options)
      uri = URI("#{BASE_URL}/polymarket/orders")
      params = {}
      
      # Add query parameters if provided
      params[:market_slug] = options[:market_slug] if options[:market_slug]
      params[:condition_id] = options[:condition_id] if options[:condition_id]
      params[:token_id] = options[:token_id] if options[:token_id]
      params[:start_time] = options[:start_time] if options[:start_time]
      params[:end_time] = options[:end_time] if options[:end_time]
      params[:user] = options[:user] if options[:user]
      params[:limit] = options[:limit] || 100
      params[:offset] = options[:offset] || 0
      params[:user] = options[:user] if options[:user]
      
      uri.query = URI.encode_www_form(params) unless params.empty?
      uri
    end

    def build_market_price_uri(token_id, at_time)
      uri = URI("#{BASE_URL}/polymarket/market-price/#{token_id}")
      
      if at_time
        uri.query = URI.encode_www_form(at_time: at_time)
      end
      
      uri
    end

    def build_candlesticks_uri(condition_id, start_time, end_time, interval)
      uri = URI("#{BASE_URL}/polymarket/candlesticks/#{condition_id}")
      
      params = {
        start_time: start_time,
        end_time: end_time,
        interval: interval
      }
      
      uri.query = URI.encode_www_form(params)
      uri
    end

    def build_wallet_pnl_uri(wallet_address, granularity, start_time, end_time)
      uri = URI("#{BASE_URL}/polymarket/wallet/pnl/#{wallet_address}")
      
      params = { granularity: granularity }
      params[:start_time] = start_time if start_time
      params[:end_time] = end_time if end_time
      
      uri.query = URI.encode_www_form(params)
      uri
    end

    def build_activity_uri(user, options)
      uri = URI("#{BASE_URL}/polymarket/activity")
      params = {}
      
      # Required parameter
      params[:user] = user
      
      # Optional parameters
      params[:start_time] = options[:start_time] if options[:start_time]
      params[:end_time] = options[:end_time] if options[:end_time]
      params[:market_slug] = options[:market_slug] if options[:market_slug]
      params[:condition_id] = options[:condition_id] if options[:condition_id]
      params[:limit] = options[:limit] || 100
      params[:offset] = options[:offset] || 0
      
      uri.query = URI.encode_www_form(params)
      uri
    end

    def make_request(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      
      request = Net::HTTP::Get.new(uri)
      request['Accept'] = 'application/json'
      request['User-Agent'] = 'dome-api-ruby-gem'
      request['Authorization'] = "Bearer #{@api_key}" if @api_key
      
      response = http.request(request)
      
      case response
      when Net::HTTPSuccess
        response
      when Net::HTTPUnauthorized
        raise Error, "Unauthorized: Invalid API key"
      when Net::HTTPTooManyRequests
        raise Error, "Rate limit exceeded"
      when Net::HTTPBadRequest
        raise Error, "Bad request: #{response.body}"
      else
        raise Error, "HTTP error: #{response.code} - #{response.message}"
      end
    end

    def parse_order_history_response(response)
      data = JSON.parse(response.body, symbolize_names: true)
      
      OrderHistoryResponse.new(
        orders: data[:orders] || [],
        pagination: data[:pagination] || {}
      )
    end

    def parse_market_price_response(response)
      data = JSON.parse(response.body, symbolize_names: true)
      
      MarketPrice.new(
        price: data[:price],
        at_time: data[:at_time]
      )
    end

    def parse_candlesticks_response(response)
      data = JSON.parse(response.body, symbolize_names: true)
      
      # Extract candlestick data and token metadata from the response
      candlesticks_data = []
      token_id = nil
      
      if data[:candlesticks] && data[:candlesticks].any?
        # The response is an array of tuples [candlestick_data_array, token_metadata]
        data[:candlesticks].each do |candlestick_tuple|
          if candlestick_tuple.is_a?(Array) && candlestick_tuple.length >= 2
            candlestick_array = candlestick_tuple[0]
            token_metadata = candlestick_tuple[1]
            
            # Extract token_id from metadata
            token_id = token_metadata[:token_id] if token_metadata.is_a?(Hash)
            
            # Add all candlestick data points
            if candlestick_array.is_a?(Array)
              candlesticks_data.concat(candlestick_array)
            end
          end
        end
      end
      
      CandlestickResponse.new(
        candlesticks: candlesticks_data,
        token_id: token_id
      )
    end

    def parse_wallet_pnl_response(response)
      data = JSON.parse(response.body, symbolize_names: true)
      
      WalletPnLResponse.new(
        granularity: data[:granularity],
        start_time: data[:start_time],
        end_time: data[:end_time],
        wallet_address: data[:wallet_address],
        pnl_over_time: data[:pnl_over_time] || []
      )
    end

    def parse_activity_response(response)
      data = JSON.parse(response.body, symbolize_names: true)
      
      ActivityResponse.new(
        activities: data[:activities] || [],
        pagination: data[:pagination] || {}
      )
    end
  end
end 