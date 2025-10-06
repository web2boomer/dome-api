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

    private

    def validate_order_history_params(options)
      if options[:limit] && (options[:limit] < 1 || options[:limit] > 1000)
        raise ArgumentError, "Limit must be between 1 and 1000"
      end
      
      if options[:offset] && options[:offset] < 0
        raise ArgumentError, "Offset must be >= 0"
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
      params[:limit] = options[:limit] || 100
      params[:offset] = options[:offset] || 0
      params[:user] = options[:user] if options[:user]
      
      uri.query = URI.encode_www_form(params) unless params.empty?
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
  end
end 