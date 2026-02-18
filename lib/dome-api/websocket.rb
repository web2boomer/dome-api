# frozen_string_literal: true

require "websocket-client-simple"
# Capture the gem's client so Rails (e.g. ActionCable) cannot shadow ::WebSocket later
WS_CLIENT = ::WebSocket::Client::Simple

# Dome API WebSocket client. Connects to wss://ws.domeapi.io/<API_KEY>,
# subscribes to channels (e.g. Polymarket orders by user), and yields
# event data to the block passed to #on_event.
#
# See: https://docs.domeapi.io/websockets
# See: https://docs.domeapi.io/websockets/subscribe-users
# See: https://docs.domeapi.io/websockets/polymarket-websockets
#
module DomeAPI
  class WebSocket
    WSS_URL = "wss://ws.domeapi.io"
    DEFAULT_VERSION = 1

    attr_reader :api_key, :subscription_ids

    # @param api_key [String] Dome API key (default: ENV['DOME_API_KEY'])
    def initialize(api_key: nil)
      @api_key = (api_key && !api_key.to_s.strip.empty?) ? api_key : ENV["DOME_API_KEY"]
      @subscription_ids = []
      @on_event_block = nil
      @on_ack_block = nil
    end

    # Register a block to be called for each order/event. Receives the "data" hash.
    # @yield [Hash] event data (e.g. token_id, side, market_slug, user, timestamp, ...)
    def on_event(&block)
      @on_event_block = block
      self
    end

    # Optional: block called when subscription is acknowledged. Receives subscription_id.
    def on_ack(&block)
      @on_ack_block = block
      self
    end

    # Send a subscribe message. Call this after connection opens (e.g. from :open handler).
    # @param platform [String] e.g. "polymarket"
    # @param type [String] e.g. "orders"
    # @param filters [Hash] e.g. { users: ["0x...", "0x..."] }
    # @param version [Integer] protocol version (default 1)
    def subscribe(platform:, type:, filters:, version: DEFAULT_VERSION)
      payload = {
        action: "subscribe",
        platform: platform,
        version: version,
        type: type,
        filters: filters
      }
      __send_frame(payload.to_json)
    end

    # Connect and run the WebSocket loop. Blocks until the connection closes or run_until time.
    # Call #on_event before #run. Pass a block to #run; it is called when connected, with self,
    # so you can call #subscribe(platform:, type:, filters:) (e.g. chunk users and subscribe multiple times).
    #
    # @param run_until [Time, nil] stop at this time (nil = run until disconnect)
    # @yield [self] gem WebSocket instance so you can call subscribe(platform:, type:, filters:)
    # @return [void]
    def run(run_until: nil, &on_open)
      raise Error, "DOME_API_KEY is not set" if @api_key.nil? || @api_key.to_s.strip.empty?

      url = "#{WSS_URL}/#{@api_key}"
      @ws = nil
      connect_thread = Thread.new { connect_and_loop(url, run_until, &on_open) }
      while connect_thread.alive? && (run_until.nil? || Time.now < run_until)
        sleep 1
      end
      close
    end

    # Close the WebSocket connection if open.
    def close
      return unless @ws&.respond_to?(:close)
      @ws.close
    rescue
      nil
    end

    def connect_and_loop(url, run_until = nil, &on_open)
      gem_self = self
      @ws = WS_CLIENT.connect(url)

      @ws.on :open do
        on_open&.call(gem_self)
      end

      @ws.on :message do |msg|
        gem_self.send(:handle_message, msg.data)
      end

      @ws.on :close do |_e|
        # connection closed
      end

      @ws.on :error do |_e|
        # error emitted
      end

      # Block until the socket's read thread exits (connection closed). Otherwise
      # connect_and_loop returns immediately and the process exits.
      @ws.thread.join if @ws.respond_to?(:thread) && @ws.thread
    end

    # Send a JSON string over the WebSocket. Uses __send__ on the underlying client to avoid Object#send.
    def __send_frame(json_string)
      return unless @ws
      @ws.__send__(:send, json_string)
    end

    private

    def handle_message(raw)
      return if raw.to_s.strip.empty?
      data = JSON.parse(raw)
      case data["type"]
      when "ack"
        sid = data["subscription_id"]
        @subscription_ids << sid if sid
        @on_ack_block&.call(sid)
      when "event"
        payload = data["data"]
        @on_event_block&.call(payload) if payload
      end
    rescue JSON::ParserError
      # ignore malformed messages
    end
  end
end
