# frozen_string_literal: true

require "dome-api"

RSpec.describe DomeAPI do
  it "has a version number" do
    expect(DomeAPI::VERSION).not_to be nil
  end

  describe "Client" do
    let(:api_key) { "test_api_key" }
    let(:client) { DomeAPI::Client.new(api_key: api_key) }

    describe "#create_order" do
      let(:order_args) do
        DomeAPI::OrderArgs.new(
          token_id: "",
          price: 0.5,
          size: 100,
          side: "BUY",
          fee_rate_bps: 10,
          nonce: 12345,
          expiration: 1234567890,
          taker: "0x0000000000000000000000000000000000000000"
        )
      end

      it "creates an order with proper validation" do
        # Mock the tick_size and neg_risk methods
        allow(client).to receive(:get_tick_size).and_return("0.1")
        allow(client).to receive(:get_neg_risk).and_return(false)
        
        # Mock the builder
        mock_builder = double("OrderBuilder")
        allow(mock_builder).to receive(:create_order).and_return({ order: "data" })
        client.instance_variable_set(:@builder, mock_builder)
        
        result = client.create_order(order_args)
        expect(result).to eq({ order: "data" })
      end

      it "raises error for invalid price" do
        allow(client).to receive(:get_tick_size).and_return("0.1")
        
        order_args.price = 0.05  # Invalid price for tick size 0.1
        
        expect { client.create_order(order_args) }.to raise_error(ArgumentError, /Price.*is not valid for tick size/)
      end
    end

    describe "#create_market_order" do
      let(:order_args) do
        DomeAPI::MarketOrderArgs.new(
          token_id: "0x1234567890123456789012345678901234567890",
          amount: 100,
          side: "BUY",
          price: nil,  # Will be fetched from market
          fee_rate_bps: 10,
          nonce: 12345,
          taker: "0x0000000000000000000000000000000000000000",
          order_type: DomeAPI::OrderType::FOK
        )
      end

      it "creates a market order with price fetching" do
        # Mock the tick_size and neg_risk methods
        allow(client).to receive(:get_tick_size).and_return("0.1")
        allow(client).to receive(:get_neg_risk).and_return(false)
        
        # Mock the price response
        mock_response = double("Net::HTTPSuccess")
        allow(mock_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        allow(mock_response).to receive(:body).and_return('{"price": 0.5}')
        allow(client).to receive(:get_price).and_return(mock_response)
        
        # Mock the builder
        mock_builder = double("OrderBuilder")
        allow(mock_builder).to receive(:create_market_order).and_return({ order: "data" })
        client.instance_variable_set(:@builder, mock_builder)
        
        result = client.create_market_order(order_args)
        expect(result).to eq({ order: "data" })
      end
    end

    describe "#get_order_history" do
      let(:mock_response) do
        double("Net::HTTPSuccess").tap do |response|
          allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
          allow(response).to receive(:body).and_return({
            orders: [
              {
                token_id: "58519484510520807142687824915233722607092670035910114837910294451210534222702",
                side: "BUY",
                market_slug: "bitcoin-up-or-down-july-25-8pm-et",
                condition_id: "0x4567b275e6b667a6217f5cb4f06a797d3a1eaf1d0281fb5bc8c75e2046ae7e57",
                shares: 4995000,
                shares_normalized: 4.995,
                price: 0.65,
                tx_hash: "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef12",
                title: "Will Bitcoin be above $50,000 on July 25, 2025 at 8:00 PM ET?",
                timestamp: 1757008834,
                order_hash: "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
                user: "0x7c3db723f1d4d8cb9c550095203b686cb11e5c6b"
              }
            ],
            pagination: {
              limit: 50,
              offset: 0,
              total: 1250,
              has_more: true
            }
          }.to_json)
        end
      end

      before do
        allow(client).to receive(:make_request).and_return(mock_response)
      end

      it "fetches order history with default parameters" do
        result = client.get_order_history
        
        expect(result).to be_a(DomeAPI::OrderHistoryResponse)
        expect(result.orders.size).to eq(1)
        expect(result.orders.first).to be_a(DomeAPI::Order)
        expect(result.orders.first.side).to eq("BUY")
        expect(result.orders.first.price).to eq(0.65)
        expect(result.pagination[:total]).to eq(1250)
      end

      it "fetches order history with custom parameters" do
        options = {
          market_slug: "bitcoin-up-or-down-july-25-8pm-et",
          limit: 25,
          offset: 10,
          user: "0x7c3db723f1d4d8cb9c550095203b686cb11e5c6b"
        }
        
        result = client.get_order_history(options)
        
        expect(result).to be_a(DomeAPI::OrderHistoryResponse)
        expect(client).to have_received(:make_request)
      end

      it "validates limit parameter" do
        expect { client.get_order_history(limit: 0) }.to raise_error(ArgumentError, /Limit must be between 1 and 1000/)
        expect { client.get_order_history(limit: 1001) }.to raise_error(ArgumentError, /Limit must be between 1 and 1000/)
      end

      it "validates offset parameter" do
        expect { client.get_order_history(offset: -1) }.to raise_error(ArgumentError, /Offset must be >= 0/)
      end

      it "handles empty response" do
        empty_response = double("Net::HTTPSuccess").tap do |response|
          allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
          allow(response).to receive(:body).and_return({ orders: [], pagination: {} }.to_json)
        end
        
        allow(client).to receive(:make_request).and_return(empty_response)
        
        result = client.get_order_history
        expect(result.orders).to be_empty
        expect(result.empty?).to be true
      end

      it "handles HTTP errors" do
        error_response = double("Net::HTTPUnauthorized").tap do |response|
          allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
          allow(response).to receive(:is_a?).with(Net::HTTPUnauthorized).and_return(true)
        end
        
        allow(client).to receive(:make_request).and_return(error_response)
        
        expect { client.get_order_history }.to raise_error(DomeAPI::Error, /Unauthorized/)
      end
    end

    describe "Order class" do
      let(:order_data) do
        {
          token_id: "58519484510520807142687824915233722607092670035910114837910294451210534222702",
          side: "BUY",
          market_slug: "bitcoin-up-or-down-july-25-8pm-et",
          condition_id: "0x4567b275e6b667a6217f5cb4f06a797d3a1eaf1d0281fb5bc8c75e2046ae7e57",
          shares: 4995000,
          shares_normalized: 4.995,
          price: 0.65,
          tx_hash: "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef12",
          title: "Will Bitcoin be above $50,000 on July 25, 2025 at 8:00 PM ET?",
          timestamp: 1757008834,
          order_hash: "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
          user: "0x7c3db723f1d4d8cb9c550095203b686cb11e5c6b"
        }
      end

      let(:order) { DomeAPI::Order.new(order_data) }

      it "initializes with correct attributes" do
        expect(order.token_id).to eq(order_data[:token_id])
        expect(order.side).to eq("BUY")
        expect(order.price).to eq(0.65)
        expect(order.shares_normalized).to eq(4.995)
      end

      it "identifies buy orders" do
        expect(order.buy?).to be true
        expect(order.sell?).to be false
      end

      it "identifies sell orders" do
        sell_order = DomeAPI::Order.new(order_data.merge(side: "SELL"))
        expect(sell_order.sell?).to be true
        expect(sell_order.buy?).to be false
      end

      it "converts to hash" do
        expect(order.to_h).to eq(order_data)
      end

      it "converts to JSON" do
        expect(JSON.parse(order.to_json)).to eq(order_data.transform_keys(&:to_s))
      end
    end

    describe "OrderHistoryResponse class" do
      let(:orders_data) do
        [
          {
            token_id: "token1",
            side: "BUY",
            price: 0.5,
            shares_normalized: 1.0
          },
          {
            token_id: "token2", 
            side: "SELL",
            price: 0.7,
            shares_normalized: 2.0
          }
        ]
      end

      let(:pagination_data) do
        {
          limit: 50,
          offset: 0,
          total: 100,
          has_more: true
        }
      end

      let(:response) { DomeAPI::OrderHistoryResponse.new(orders: orders_data, pagination: pagination_data) }

      it "initializes with orders and pagination" do
        expect(response.orders.size).to eq(2)
        expect(response.orders.first).to be_a(DomeAPI::Order)
        expect(response.pagination).to eq(pagination_data)
      end

      it "provides pagination helpers" do
        expect(response.total_orders).to eq(100)
        expect(response.limit).to eq(50)
        expect(response.offset).to eq(0)
        expect(response.has_more?).to be true
      end

      it "provides collection methods" do
        expect(response.size).to eq(2)
        expect(response.empty?).to be false
        expect(response[0].side).to eq("BUY")
        expect(response[1].side).to eq("SELL")
      end

      it "converts to hash and JSON" do
        hash = response.to_h
        expect(hash[:orders].size).to eq(2)
        expect(hash[:pagination]).to eq(pagination_data)
        
        json = JSON.parse(response.to_json)
        expect(json["orders"].size).to eq(2)
        expect(json["pagination"]).to eq(pagination_data.transform_keys(&:to_s))
      end
    end

    describe "#get_market_price" do
      let(:token_id) { "58519484510520807142687824915233722607092670035910114837910294451210534222702" }
      let(:mock_response) do
        double("Net::HTTPSuccess").tap do |response|
          allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
          allow(response).to receive(:body).and_return({
            price: 0.215,
            at_time: 1757008834
          }.to_json)
        end
      end

      before do
        allow(client).to receive(:make_request).and_return(mock_response)
      end

      it "fetches current market price" do
        result = client.get_market_price(token_id)
        
        expect(result).to be_a(DomeAPI::MarketPrice)
        expect(result.price).to eq(0.215)
        expect(result.at_time).to eq(1757008834)
      end

      it "fetches historical market price" do
        historical_time = 1740000000
        result = client.get_market_price(token_id, at_time: historical_time)
        
        expect(result).to be_a(DomeAPI::MarketPrice)
        expect(result.price).to eq(0.215)
        expect(result.at_time).to eq(1757008834)
      end

      it "validates token_id parameter" do
        expect { client.get_market_price(nil) }.to raise_error(ArgumentError, /Token ID cannot be empty/)
        expect { client.get_market_price("") }.to raise_error(ArgumentError, /Token ID cannot be empty/)
        expect { client.get_market_price("   ") }.to raise_error(ArgumentError, /Token ID cannot be empty/)
      end

      it "validates at_time parameter" do
        expect { client.get_market_price(token_id, at_time: -1) }.to raise_error(ArgumentError, /at_time must be a positive integer/)
        expect { client.get_market_price(token_id, at_time: 0) }.to raise_error(ArgumentError, /at_time must be a positive integer/)
        expect { client.get_market_price(token_id, at_time: "invalid") }.to raise_error(ArgumentError, /at_time must be a positive integer/)
      end

      it "handles HTTP errors" do
        error_response = double("Net::HTTPNotFound").tap do |response|
          allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
          allow(response).to receive(:is_a?).with(Net::HTTPUnauthorized).and_return(false)
          allow(response).to receive(:is_a?).with(Net::HTTPTooManyRequests).and_return(false)
          allow(response).to receive(:is_a?).with(Net::HTTPBadRequest).and_return(false)
          allow(response).to receive(:code).and_return("404")
          allow(response).to receive(:message).and_return("Not Found")
        end
        
        allow(client).to receive(:make_request).and_return(error_response)
        
        expect { client.get_market_price(token_id) }.to raise_error(DomeAPI::Error, /HTTP error: 404 - Not Found/)
      end
    end

    describe "MarketPrice class" do
      let(:current_time) { Time.now.to_i }
      let(:recent_time) { current_time - 60 } # 1 minute ago
      let(:old_time) { current_time - 600 } # 10 minutes ago
      
      let(:current_price_data) do
        {
          price: 0.75,
          at_time: recent_time
        }
      end

      let(:historical_price_data) do
        {
          price: 0.65,
          at_time: old_time
        }
      end

      let(:current_price) { DomeAPI::MarketPrice.new(current_price_data) }
      let(:historical_price) { DomeAPI::MarketPrice.new(historical_price_data) }

      it "initializes with correct attributes" do
        expect(current_price.price).to eq(0.75)
        expect(current_price.at_time).to eq(recent_time)
      end

      it "identifies current vs historical prices" do
        expect(current_price.current?).to be true
        expect(current_price.historical?).to be false
        
        expect(historical_price.current?).to be false
        expect(historical_price.historical?).to be true
      end

      it "provides timestamp conversion" do
        expect(current_price.timestamp).to be_a(Time)
        expect(current_price.timestamp.to_i).to eq(recent_time)
      end

      it "formats time in different formats" do
        expect(current_price.formatted_time(:iso)).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
        expect(current_price.formatted_time(:readable)).to match(/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} UTC/)
        expect(current_price.formatted_time).to be_a(String)
      end

      it "handles nil timestamp gracefully" do
        price_without_time = DomeAPI::MarketPrice.new(price: 0.5, at_time: nil)
        
        expect(price_without_time.timestamp).to be_nil
        expect(price_without_time.formatted_time).to be_nil
        expect(price_without_time.current?).to be false
        expect(price_without_time.historical?).to be true
      end

      it "converts to hash and JSON" do
        expect(current_price.to_h).to eq(current_price_data)
        expect(JSON.parse(current_price.to_json)).to eq(current_price_data.transform_keys(&:to_s))
      end

      it "provides string representation" do
        expect(current_price.to_s).to include("Market Price: $0.75")
        expect(current_price.to_s).to include("UTC")
      end
    end

    describe "#get_candlesticks" do
      let(:condition_id) { "0x4567b275e6b667a6217f5cb4f06a797d3a1eaf1d0281fb5bc8c75e2046ae7e57" }
      let(:start_time) { 1640995200 }
      let(:end_time) { 1641081600 }
      let(:mock_response) do
        double("Net::HTTPSuccess").tap do |response|
          allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
          allow(response).to receive(:body).and_return({
            candlesticks: [
              [
                [
                  {
                    end_period_ts: 1727827200,
                    open_interest: 8456498,
                    price: {
                      open: 0.0049,
                      high: 0.0049,
                      low: 0.0048,
                      close: 0.0048,
                      open_dollars: "0.0049",
                      high_dollars: "0.0049",
                      low_dollars: "0.0048",
                      close_dollars: "0.0048",
                      mean: 0.0049,
                      mean_dollars: "0.0049",
                      previous: 0.0049,
                      previous_dollars: "0.0049"
                    },
                    volume: 8456498,
                    yes_ask: {
                      open: 0.00489,
                      close: 0.00482,
                      high: 0.00491,
                      low: 0.0048,
                      open_dollars: "0.0049",
                      close_dollars: "0.0048",
                      high_dollars: "0.0049",
                      low_dollars: "0.0048"
                    },
                    yes_bid: {
                      open: 0.00489,
                      close: 0.00483,
                      high: 0.00491,
                      low: 0.0048,
                      open_dollars: "0.0049",
                      close_dollars: "0.0048",
                      high_dollars: "0.0049",
                      low_dollars: "0.0048"
                    }
                  }
                ],
                {
                  token_id: "21742633143463906290569050155826241533067272736897614950488156847949938836455"
                }
              ]
            ]
          }.to_json)
        end
      end

      before do
        allow(client).to receive(:make_request).and_return(mock_response)
      end

      it "fetches candlestick data with required parameters" do
        result = client.get_candlesticks(condition_id, start_time: start_time, end_time: end_time)
        
        expect(result).to be_a(DomeAPI::CandlestickResponse)
        expect(result.candlesticks.size).to eq(1)
        expect(result.token_id).to eq("21742633143463906290569050155826241533067272736897614950488156847949938836455")
      end

      it "fetches candlestick data with custom interval" do
        result = client.get_candlesticks(condition_id, start_time: start_time, end_time: end_time, interval: 60)
        
        expect(result).to be_a(DomeAPI::CandlestickResponse)
        expect(client).to have_received(:make_request)
      end

      it "validates condition_id parameter" do
        expect { client.get_candlesticks(nil, start_time: start_time, end_time: end_time) }.to raise_error(ArgumentError, /Condition ID cannot be empty/)
        expect { client.get_candlesticks("", start_time: start_time, end_time: end_time) }.to raise_error(ArgumentError, /Condition ID cannot be empty/)
      end

      it "validates time range parameters" do
        expect { client.get_candlesticks(condition_id, start_time: -1, end_time: end_time) }.to raise_error(ArgumentError, /start_time must be a positive integer/)
        expect { client.get_candlesticks(condition_id, start_time: start_time, end_time: -1) }.to raise_error(ArgumentError, /end_time must be a positive integer/)
        expect { client.get_candlesticks(condition_id, start_time: end_time, end_time: start_time) }.to raise_error(ArgumentError, /start_time must be less than end_time/)
      end

      it "validates interval parameter" do
        expect { client.get_candlesticks(condition_id, start_time: start_time, end_time: end_time, interval: 30) }.to raise_error(ArgumentError, /interval must be one of: 1, 60, 1440/)
        expect { client.get_candlesticks(condition_id, start_time: start_time, end_time: end_time, interval: 0) }.to raise_error(ArgumentError, /interval must be one of: 1, 60, 1440/)
      end

      it "handles empty response" do
        empty_response = double("Net::HTTPSuccess").tap do |response|
          allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
          allow(response).to receive(:body).and_return({ candlesticks: [] }.to_json)
        end
        
        allow(client).to receive(:make_request).and_return(empty_response)
        
        result = client.get_candlesticks(condition_id, start_time: start_time, end_time: end_time)
        expect(result.candlesticks).to be_empty
        expect(result.empty?).to be true
      end

      it "handles HTTP errors" do
        error_response = double("Net::HTTPBadRequest").tap do |response|
          allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
          allow(response).to receive(:is_a?).with(Net::HTTPUnauthorized).and_return(false)
          allow(response).to receive(:is_a?).with(Net::HTTPTooManyRequests).and_return(false)
          allow(response).to receive(:is_a?).with(Net::HTTPBadRequest).and_return(true)
          allow(response).to receive(:body).and_return("Bad Request")
        end
        
        allow(client).to receive(:make_request).and_return(error_response)
        
        expect { client.get_candlesticks(condition_id, start_time: start_time, end_time: end_time) }.to raise_error(DomeAPI::Error, /Bad request: Bad Request/)
      end
    end

    describe "CandlestickData class" do
      let(:candlestick_data) do
        {
          end_period_ts: 1727827200,
          open_interest: 8456498,
          volume: 8456498,
          price: {
            open: 0.0049,
            high: 0.0049,
            low: 0.0048,
            close: 0.0048,
            mean: 0.0049,
            previous: 0.0049,
            open_dollars: "0.0049",
            high_dollars: "0.0049",
            low_dollars: "0.0048",
            close_dollars: "0.0048",
            mean_dollars: "0.0049",
            previous_dollars: "0.0049"
          },
          yes_ask: {
            open: 0.00489,
            close: 0.00482,
            high: 0.00491,
            low: 0.0048,
            open_dollars: "0.0049",
            close_dollars: "0.0048",
            high_dollars: "0.0049",
            low_dollars: "0.0048"
          },
          yes_bid: {
            open: 0.00489,
            close: 0.00483,
            high: 0.00491,
            low: 0.0048,
            open_dollars: "0.0049",
            close_dollars: "0.0048",
            high_dollars: "0.0049",
            low_dollars: "0.0048"
          }
        }
      end

      let(:candlestick) { DomeAPI::CandlestickData.new(candlestick_data) }

      it "initializes with correct attributes" do
        expect(candlestick.end_period_ts).to eq(1727827200)
        expect(candlestick.open_interest).to eq(8456498)
        expect(candlestick.volume).to eq(8456498)
        expect(candlestick.price).to be_a(DomeAPI::PriceData)
        expect(candlestick.yes_ask).to be_a(DomeAPI::BidAskData)
        expect(candlestick.yes_bid).to be_a(DomeAPI::BidAskData)
      end

      it "provides time conversion" do
        expect(candlestick.end_time).to be_a(Time)
        expect(candlestick.end_time.to_i).to eq(1727827200)
        expect(candlestick.formatted_end_time(:iso)).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
        expect(candlestick.formatted_end_time(:readable)).to match(/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} UTC/)
      end

      it "calculates price metrics" do
        expect(candlestick.price_range).to eq(0.0001) # high - low
        expect(candlestick.price_change).to eq(-0.0001) # close - open
        expect(candlestick.price_change_percent).to be_within(0.01).of(-2.04) # (change/open) * 100
      end

      it "converts to hash and JSON" do
        expect(candlestick.to_h).to be_a(Hash)
        expect(candlestick.to_h[:end_period_ts]).to eq(1727827200)
        expect(JSON.parse(candlestick.to_json)).to be_a(Hash)
      end

      it "provides string representation" do
        expect(candlestick.to_s).to include("O:0.0049")
        expect(candlestick.to_s).to include("H:0.0049")
        expect(candlestick.to_s).to include("L:0.0048")
        expect(candlestick.to_s).to include("C:0.0048")
        expect(candlestick.to_s).to include("V:8456498")
      end
    end

    describe "PriceData class" do
      let(:price_data) do
        {
          open: 0.0049,
          high: 0.0049,
          low: 0.0048,
          close: 0.0048,
          mean: 0.0049,
          previous: 0.0049,
          open_dollars: "0.0049",
          high_dollars: "0.0049",
          low_dollars: "0.0048",
          close_dollars: "0.0048",
          mean_dollars: "0.0049",
          previous_dollars: "0.0049"
        }
      end

      let(:price) { DomeAPI::PriceData.new(price_data) }

      it "initializes with correct attributes" do
        expect(price.open).to eq(0.0049)
        expect(price.high).to eq(0.0049)
        expect(price.low).to eq(0.0048)
        expect(price.close).to eq(0.0048)
        expect(price.mean).to eq(0.0049)
        expect(price.previous).to eq(0.0049)
      end

      it "converts to hash and JSON" do
        expect(price.to_h).to eq(price_data)
        expect(JSON.parse(price.to_json)).to eq(price_data.transform_keys(&:to_s))
      end
    end

    describe "BidAskData class" do
      let(:bid_ask_data) do
        {
          open: 0.00489,
          close: 0.00482,
          high: 0.00491,
          low: 0.0048,
          open_dollars: "0.0049",
          close_dollars: "0.0048",
          high_dollars: "0.0049",
          low_dollars: "0.0048"
        }
      end

      let(:bid_ask) { DomeAPI::BidAskData.new(bid_ask_data) }

      it "initializes with correct attributes" do
        expect(bid_ask.open).to eq(0.00489)
        expect(bid_ask.close).to eq(0.00482)
        expect(bid_ask.high).to eq(0.00491)
        expect(bid_ask.low).to eq(0.0048)
      end

      it "calculates spread" do
        expect(bid_ask.spread).to eq(0.00007) # open - close
      end

      it "converts to hash and JSON" do
        expect(bid_ask.to_h).to eq(bid_ask_data)
        expect(JSON.parse(bid_ask.to_json)).to eq(bid_ask_data.transform_keys(&:to_s))
      end
    end

    describe "CandlestickResponse class" do
      let(:candlesticks_data) do
        [
          {
            end_period_ts: 1727827200,
            open_interest: 1000,
            volume: 500,
            price: { open: 0.5, high: 0.6, low: 0.4, close: 0.55 }
          },
          {
            end_period_ts: 1727830800,
            open_interest: 1200,
            volume: 600,
            price: { open: 0.55, high: 0.7, low: 0.45, close: 0.65 }
          }
        ]
      end

      let(:response) { DomeAPI::CandlestickResponse.new(candlesticks: candlesticks_data, token_id: "test_token") }

      it "initializes with candlesticks and token_id" do
        expect(response.candlesticks.size).to eq(2)
        expect(response.candlesticks.first).to be_a(DomeAPI::CandlestickData)
        expect(response.token_id).to eq("test_token")
      end

      it "provides collection methods" do
        expect(response.size).to eq(2)
        expect(response.empty?).to be false
        expect(response[0]).to be_a(DomeAPI::CandlestickData)
        expect(response.first).to be_a(DomeAPI::CandlestickData)
        expect(response.last).to be_a(DomeAPI::CandlestickData)
      end

      it "provides data analysis methods" do
        expect(response.price_data.size).to eq(2)
        expect(response.volume_data).to eq([500, 600])
        expect(response.open_interest_data).to eq([1000, 1200])
        expect(response.total_volume).to eq(1100)
        expect(response.average_volume).to eq(550.0)
      end

      it "calculates price metrics" do
        expect(response.price_range).to eq(0.3) # max high - min low
        expect(response.price_trend).to eq(:up) # first close < last close
      end

      it "provides time series data" do
        time_series = response.time_series
        expect(time_series.size).to eq(2)
        expect(time_series[0][1]).to eq(0.55) # first close price
        expect(time_series[1][1]).to eq(0.65) # last close price
      end

      it "converts to hash and JSON" do
        hash = response.to_h
        expect(hash[:candlesticks].size).to eq(2)
        expect(hash[:token_id]).to eq("test_token")
        
        json = JSON.parse(response.to_json)
        expect(json["candlesticks"].size).to eq(2)
        expect(json["token_id"]).to eq("test_token")
      end
    end

    describe "#get_wallet_pnl" do
      let(:wallet_address) { "0x7c3db723f1d4d8cb9c550095203b686cb11e5c6b" }
      let(:granularity) { "day" }
      let(:start_time) { 1726857600 }
      let(:end_time) { 1758316829 }
      let(:mock_response) do
        double("Net::HTTPSuccess").tap do |response|
          allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
          allow(response).to receive(:body).and_return({
            granularity: "day",
            start_time: 1726857600,
            end_time: 1758316829,
            wallet_address: "0x7c3db723f1d4d8cb9c550095203b686cb11e5c6b",
            pnl_over_time: [
              {
                timestamp: 1726857600,
                pnl_to_date: 2001
              },
              {
                timestamp: 1726944000,
                pnl_to_date: 2150
              },
              {
                timestamp: 1727030400,
                pnl_to_date: 1980
              }
            ]
          }.to_json)
        end
      end

      before do
        allow(client).to receive(:make_request).and_return(mock_response)
      end

      it "fetches wallet PnL with required parameters" do
        result = client.get_wallet_pnl(wallet_address, granularity: granularity)
        
        expect(result).to be_a(DomeAPI::WalletPnLResponse)
        expect(result.wallet_address).to eq(wallet_address)
        expect(result.granularity).to eq("day")
        expect(result.pnl_over_time.size).to eq(3)
      end

      it "fetches wallet PnL with time range" do
        result = client.get_wallet_pnl(
          wallet_address,
          granularity: granularity,
          start_time: start_time,
          end_time: end_time
        )
        
        expect(result).to be_a(DomeAPI::WalletPnLResponse)
        expect(client).to have_received(:make_request)
      end

      it "validates wallet address parameter" do
        expect { client.get_wallet_pnl(nil, granularity: granularity) }.to raise_error(ArgumentError, /Wallet address cannot be empty/)
        expect { client.get_wallet_pnl("", granularity: granularity) }.to raise_error(ArgumentError, /Wallet address cannot be empty/)
        expect { client.get_wallet_pnl("invalid", granularity: granularity) }.to raise_error(ArgumentError, /Invalid wallet address format/)
        expect { client.get_wallet_pnl("0x123", granularity: granularity) }.to raise_error(ArgumentError, /Invalid wallet address format/)
      end

      it "validates granularity parameter" do
        expect { client.get_wallet_pnl(wallet_address, granularity: "invalid") }.to raise_error(ArgumentError, /granularity must be one of: day, week, month, year, all/)
        expect { client.get_wallet_pnl(wallet_address, granularity: nil) }.to raise_error(ArgumentError, /granularity must be one of: day, week, month, year, all/)
      end

      it "validates optional time range parameters" do
        expect { client.get_wallet_pnl(wallet_address, granularity: granularity, start_time: -1) }.to raise_error(ArgumentError, /start_time must be a positive integer/)
        expect { client.get_wallet_pnl(wallet_address, granularity: granularity, end_time: -1) }.to raise_error(ArgumentError, /end_time must be a positive integer/)
        expect { client.get_wallet_pnl(wallet_address, granularity: granularity, start_time: end_time, end_time: start_time) }.to raise_error(ArgumentError, /start_time must be less than end_time/)
      end

      it "handles empty response" do
        empty_response = double("Net::HTTPSuccess").tap do |response|
          allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
          allow(response).to receive(:body).and_return({
            granularity: "day",
            start_time: 1726857600,
            end_time: 1758316829,
            wallet_address: wallet_address,
            pnl_over_time: []
          }.to_json)
        end
        
        allow(client).to receive(:make_request).and_return(empty_response)
        
        result = client.get_wallet_pnl(wallet_address, granularity: granularity)
        expect(result.pnl_over_time).to be_empty
        expect(result.empty?).to be true
      end

      it "handles HTTP errors" do
        error_response = double("Net::HTTPNotFound").tap do |response|
          allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
          allow(response).to receive(:is_a?).with(Net::HTTPUnauthorized).and_return(false)
          allow(response).to receive(:is_a?).with(Net::HTTPTooManyRequests).and_return(false)
          allow(response).to receive(:is_a?).with(Net::HTTPBadRequest).and_return(false)
          allow(response).to receive(:code).and_return("404")
          allow(response).to receive(:message).and_return("Not Found")
        end
        
        allow(client).to receive(:make_request).and_return(error_response)
        
        expect { client.get_wallet_pnl(wallet_address, granularity: granularity) }.to raise_error(DomeAPI::Error, /HTTP error: 404 - Not Found/)
      end
    end

    describe "PnLData class" do
      let(:pnl_data) do
        {
          timestamp: 1726857600,
          pnl_to_date: 2001
        }
      end

      let(:pnl) { DomeAPI::PnLData.new(pnl_data) }

      it "initializes with correct attributes" do
        expect(pnl.timestamp).to eq(1726857600)
        expect(pnl.pnl_to_date).to eq(2001)
      end

      it "provides time conversion" do
        expect(pnl.time).to be_a(Time)
        expect(pnl.time.to_i).to eq(1726857600)
        expect(pnl.formatted_time(:iso)).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
        expect(pnl.formatted_time(:readable)).to match(/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} UTC/)
        expect(pnl.formatted_time(:date_only)).to match(/\d{4}-\d{2}-\d{2}/)
      end

      it "converts PnL to dollars" do
        expect(pnl.pnl_dollars).to eq(20.01) # 2001 cents = $20.01
      end

      it "identifies profit/loss/break-even" do
        profit_pnl = DomeAPI::PnLData.new(timestamp: 1726857600, pnl_to_date: 100)
        loss_pnl = DomeAPI::PnLData.new(timestamp: 1726857600, pnl_to_date: -50)
        break_even_pnl = DomeAPI::PnLData.new(timestamp: 1726857600, pnl_to_date: 0)

        expect(profit_pnl.profit?).to be true
        expect(profit_pnl.loss?).to be false
        expect(profit_pnl.break_even?).to be false

        expect(loss_pnl.profit?).to be false
        expect(loss_pnl.loss?).to be true
        expect(loss_pnl.break_even?).to be false

        expect(break_even_pnl.profit?).to be false
        expect(break_even_pnl.loss?).to be false
        expect(break_even_pnl.break_even?).to be true
      end

      it "handles nil PnL gracefully" do
        nil_pnl = DomeAPI::PnLData.new(timestamp: 1726857600, pnl_to_date: nil)
        
        expect(nil_pnl.pnl_dollars).to be_nil
        expect(nil_pnl.profit?).to be false
        expect(nil_pnl.loss?).to be false
        expect(nil_pnl.break_even?).to be false
      end

      it "converts to hash and JSON" do
        expect(pnl.to_h).to eq(pnl_data)
        expect(JSON.parse(pnl.to_json)).to eq(pnl_data.transform_keys(&:to_s))
      end

      it "provides string representation" do
        expect(pnl.to_s).to include("PnL: $20.01")
        expect(pnl.to_s).to include("UTC")
      end
    end

    describe "WalletPnLResponse class" do
      let(:pnl_data) do
        [
          { timestamp: 1726857600, pnl_to_date: 1000 },
          { timestamp: 1726944000, pnl_to_date: 1500 },
          { timestamp: 1727030400, pnl_to_date: 1200 },
          { timestamp: 1727116800, pnl_to_date: 800 },
          { timestamp: 1727203200, pnl_to_date: 2000 }
        ]
      end

      let(:response) do
        DomeAPI::WalletPnLResponse.new(
          granularity: "day",
          start_time: 1726857600,
          end_time: 1727203200,
          wallet_address: "0x7c3db723f1d4d8cb9c550095203b686cb11e5c6b",
          pnl_over_time: pnl_data
        )
      end

      it "initializes with correct attributes" do
        expect(response.granularity).to eq("day")
        expect(response.wallet_address).to eq("0x7c3db723f1d4d8cb9c550095203b686cb11e5c6b")
        expect(response.pnl_over_time.size).to eq(5)
        expect(response.pnl_over_time.first).to be_a(DomeAPI::PnLData)
      end

      it "provides collection methods" do
        expect(response.size).to eq(5)
        expect(response.empty?).to be false
        expect(response[0]).to be_a(DomeAPI::PnLData)
        expect(response.first).to be_a(DomeAPI::PnLData)
        expect(response.last).to be_a(DomeAPI::PnLData)
      end

      it "provides date formatting" do
        expect(response.start_date).to be_a(Time)
        expect(response.end_date).to be_a(Time)
        expect(response.formatted_start_date).to match(/\d{4}-\d{2}-\d{2}/)
        expect(response.formatted_end_date).to match(/\d{4}-\d{2}-\d{2}/)
      end

      it "calculates current PnL" do
        expect(response.current_pnl).to eq(2000)
        expect(response.current_pnl_dollars).to eq(20.0)
      end

      it "calculates total PnL" do
        expect(response.total_pnl).to eq(2000)
        expect(response.total_pnl_dollars).to eq(20.0)
      end

      it "calculates peak and trough PnL" do
        expect(response.peak_pnl).to eq(2000)
        expect(response.peak_pnl_dollars).to eq(20.0)
        expect(response.trough_pnl).to eq(800)
        expect(response.trough_pnl_dollars).to eq(8.0)
      end

      it "calculates max drawdown" do
        expect(response.max_drawdown).to eq(1200) # 2000 - 800
        expect(response.max_drawdown_dollars).to eq(12.0)
        expect(response.max_drawdown_percent).to eq(60.0) # (1200 / 2000) * 100
      end

      it "counts profit/loss days" do
        expect(response.profit_days).to eq(4) # 4 positive PnL days
        expect(response.loss_days).to eq(0) # 0 negative PnL days
        expect(response.break_even_days).to eq(0) # 0 zero PnL days
      end

      it "calculates win rate" do
        expect(response.win_rate).to eq(80.0) # 4/5 * 100
      end

      it "provides PnL series data" do
        series = response.pnl_series
        expect(series.size).to eq(5)
        expect(series[0][1]).to eq(1000) # first PnL value
        expect(series[4][1]).to eq(2000) # last PnL value
      end

      it "calculates daily changes" do
        changes = response.daily_changes
        expect(changes.size).to eq(4) # 5 days = 4 changes
        expect(changes[0][:change]).to eq(500) # 1500 - 1000
        expect(changes[1][:change]).to eq(-300) # 1200 - 1500
        expect(changes[2][:change]).to eq(-400) # 800 - 1200
        expect(changes[3][:change]).to eq(1200) # 2000 - 800
      end

      it "finds best and worst days" do
        best = response.best_day
        worst = response.worst_day

        expect(best[:change]).to eq(1200)
        expect(worst[:change]).to eq(-400)
      end

      it "calculates average daily PnL" do
        expect(response.average_daily_pnl).to eq(250.0) # (500 - 300 - 400 + 1200) / 4
        expect(response.average_daily_pnl_dollars).to eq(2.5)
      end

      it "converts to hash and JSON" do
        hash = response.to_h
        expect(hash[:granularity]).to eq("day")
        expect(hash[:wallet_address]).to eq("0x7c3db723f1d4d8cb9c550095203b686cb11e5c6b")
        expect(hash[:pnl_over_time].size).to eq(5)
        
        json = JSON.parse(response.to_json)
        expect(json["granularity"]).to eq("day")
        expect(json["wallet_address"]).to eq("0x7c3db723f1d4d8cb9c550095203b686cb11e5c6b")
        expect(json["pnl_over_time"].size).to eq(5)
      end
    end
  end
end
