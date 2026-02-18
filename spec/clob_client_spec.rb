# frozen_string_literal: true

require "dome-api"

RSpec.describe DomeAPI do
  it "has a version number" do
    expect(DomeAPI::VERSION).not_to be nil
  end

  describe "Client" do
    let(:api_key) { "test_api_key" }
    let(:client) { DomeAPI::Client.new(api_key: api_key) }

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
              has_more: true,
              pagination_key: "eyJibG9ja190aW1lc3RhbXAiOiIyMDI1LTAxLTE5VDEyOjAwOjAwLjAwMFoifQ=="
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
          user: "0x7c3db723f1d4d8cb9c550095203b686cb11e5c6b"
        }
        
        result = client.get_order_history(options)
        
        expect(result).to be_a(DomeAPI::OrderHistoryResponse)
        expect(client).to have_received(:make_request)
      end

      it "uses pagination_key instead of offset when provided" do
        cursor = "eyJibG9ja190aW1lc3RhbXAiOiIyMDI1LTAxLTE5VDEyOjAwOjAwLjAwMFoifQ=="
        client.get_order_history(limit: 50, pagination_key: cursor)
        
        expect(client).to have_received(:make_request) do |uri|
          params = URI.decode_www_form(uri.query).to_h
          expect(params["pagination_key"]).to eq(cursor)
          expect(params).not_to have_key("offset")
        end
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
        allow(client).to receive(:make_request).and_raise(DomeAPI::Error, "Unauthorized: Invalid API key")
        
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
          has_more: true,
          pagination_key: "eyJibG9ja190aW1lc3RhbXAiOiIyMDI1LTAxLTE5VDEyOjAwOjAwLjAwMFoifQ=="
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
        expect(response.pagination_key).to eq("eyJibG9ja190aW1lc3RhbXAiOiIyMDI1LTAxLTE5VDEyOjAwOjAwLjAwMFoifQ==")
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
        allow(client).to receive(:make_request).and_raise(DomeAPI::Error, "HTTP error: 404 - Not Found")
        
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
        allow(client).to receive(:make_request).and_raise(DomeAPI::Error, "Bad request: Bad Request")
        
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
        expect(candlestick.price_range).to be_within(0.00001).of(0.0001) # high - low
        expect(candlestick.price_change).to be_within(0.00001).of(-0.0001) # close - open
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
        expect(bid_ask.spread).to be_within(0.00001).of(0.00007) # open - close
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
        expect(response.price_range).to be_within(0.001).of(0.3) # max high - min low
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
        allow(client).to receive(:make_request).and_raise(DomeAPI::Error, "HTTP error: 404 - Not Found")
        
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
        expect(response.profit_days).to eq(5) # 5 positive PnL days (all values are positive)
        expect(response.loss_days).to eq(0) # 0 negative PnL days
        expect(response.break_even_days).to eq(0) # 0 zero PnL days
      end

      it "calculates win rate" do
        expect(response.win_rate).to eq(100.0) # 5/5 * 100 (all days profitable)
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

    describe "#get_activity" do
      let(:user_address) { "0x7c3db723f1d4d8cb9c550095203b686cb11e5c6b" }
      let(:mock_response) do
        double("Net::HTTPSuccess").tap do |response|
          allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
          allow(response).to receive(:body).and_return({
            activities: [
              {
                token_id: "",
                side: "REDEEM",
                market_slug: "will-the-doj-charge-boeing",
                condition_id: "0x92e4b1b8e0621fab0537486e7d527322569d7a8fd394b3098ff4bb1d6e1c0bbd",
                shares: 187722726,
                shares_normalized: 187.722726,
                price: 1,
                tx_hash: "0x028baff23a90c10728606781d15077098ee93c991ea204aa52a0bd2869187574",
                title: "Will the DOJ charge Boeing?",
                timestamp: 1721263049,
                order_hash: "",
                user: "0x7c3db723f1d4d8cb9c550095203b686cb11e5c6b"
              },
              {
                token_id: "",
                side: "MERGE",
                market_slug: "bitcoin-price-test",
                condition_id: "0x4567b275e6b667a6217f5cb4f06a797d3a1eaf1d0281fb5bc8c75e2046ae7e57",
                shares: 5000000,
                shares_normalized: 5.0,
                price: 0.75,
                tx_hash: "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
                title: "Test Market",
                timestamp: 1721176649,
                order_hash: "",
                user: "0x7c3db723f1d4d8cb9c550095203b686cb11e5c6b"
              }
            ],
            pagination: {
              limit: 50,
              offset: 0,
              count: 1250,
              has_more: true,
              pagination_key: "eyJibG9ja190aW1lc3RhbXAiOiIyMDI1LTAxLTE5VDEyOjAwOjAwLjAwMFoifQ=="
            }
          }.to_json)
        end
      end

      before do
        allow(client).to receive(:make_request).and_return(mock_response)
      end

      it "fetches activity with default parameters" do
        result = client.get_activity(user_address)
        
        expect(result).to be_a(DomeAPI::ActivityResponse)
        expect(result.activities.size).to eq(2)
        expect(result.activities.first).to be_a(DomeAPI::Order)
        expect(result.activities.first.side).to eq("REDEEM")
        expect(result.activities.first.shares_normalized).to eq(187.722726)
        expect(result.pagination[:count]).to eq(1250)
        expect(result.total_activities).to eq(1250)
        expect(result.has_more?).to be true
      end

      it "fetches activity with custom parameters" do
        options = {
          market_slug: "will-the-doj-charge-boeing",
          limit: 25
        }
        
        result = client.get_activity(user_address, options)
        
        expect(result).to be_a(DomeAPI::ActivityResponse)
        expect(client).to have_received(:make_request)
      end

      it "uses pagination_key instead of offset when provided" do
        cursor = "eyJibG9ja190aW1lc3RhbXAiOiIyMDI1LTAxLTE5VDEyOjAwOjAwLjAwMFoifQ=="
        client.get_activity(user_address, limit: 50, pagination_key: cursor)
        
        expect(client).to have_received(:make_request) do |uri|
          params = URI.decode_www_form(uri.query).to_h
          expect(params["pagination_key"]).to eq(cursor)
          expect(params).not_to have_key("offset")
        end
      end

      it "fetches activity with time range" do
        start_time = 1721176000
        end_time = 1721264000
        options = {
          start_time: start_time,
          end_time: end_time,
          limit: 10
        }
        
        result = client.get_activity(user_address, options)
        
        expect(result).to be_a(DomeAPI::ActivityResponse)
        expect(client).to have_received(:make_request)
      end

      it "fetches activity with condition_id filter" do
        options = {
          condition_id: "0x92e4b1b8e0621fab0537486e7d527322569d7a8fd394b3098ff4bb1d6e1c0bbd",
          limit: 10
        }
        
        result = client.get_activity(user_address, options)
        
        expect(result).to be_a(DomeAPI::ActivityResponse)
        expect(client).to have_received(:make_request)
      end

      it "validates user wallet address parameter" do
        expect { client.get_activity(nil) }.to raise_error(ArgumentError, /Wallet address cannot be empty/)
        expect { client.get_activity("") }.to raise_error(ArgumentError, /Wallet address cannot be empty/)
        expect { client.get_activity("invalid") }.to raise_error(ArgumentError, /Invalid wallet address format/)
        expect { client.get_activity("0x123") }.to raise_error(ArgumentError, /Invalid wallet address format/)
      end

      it "validates limit parameter" do
        expect { client.get_activity(user_address, limit: 0) }.to raise_error(ArgumentError, /Limit must be between 1 and 1000/)
        expect { client.get_activity(user_address, limit: 1001) }.to raise_error(ArgumentError, /Limit must be between 1 and 1000/)
      end

      it "validates offset parameter" do
        expect { client.get_activity(user_address, offset: -1) }.to raise_error(ArgumentError, /Offset must be >= 0/)
      end

      it "validates time range parameters" do
        expect { client.get_activity(user_address, start_time: -1) }.to raise_error(ArgumentError, /start_time must be a positive integer/)
        expect { client.get_activity(user_address, end_time: -1) }.to raise_error(ArgumentError, /end_time must be a positive integer/)
        expect { client.get_activity(user_address, start_time: 100, end_time: 50) }.to raise_error(ArgumentError, /start_time must be less than end_time/)
      end

      it "handles empty response" do
        empty_response = double("Net::HTTPSuccess").tap do |response|
          allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
          allow(response).to receive(:body).and_return({ activities: [], pagination: {} }.to_json)
        end
        
        allow(client).to receive(:make_request).and_return(empty_response)
        
        result = client.get_activity(user_address)
        expect(result.activities).to be_empty
        expect(result.empty?).to be true
      end

      it "handles HTTP errors" do
        allow(client).to receive(:make_request).and_raise(DomeAPI::Error, "Unauthorized: Invalid API key")
        
        expect { client.get_activity(user_address) }.to raise_error(DomeAPI::Error, /Unauthorized/)
      end
    end

    describe "ActivityResponse class" do
      let(:activities_data) do
        [
          {
            token_id: "",
            side: "REDEEM",
            market_slug: "will-the-doj-charge-boeing",
            condition_id: "0x92e4b1b8e0621fab0537486e7d527322569d7a8fd394b3098ff4bb1d6e1c0bbd",
            shares: 187722726,
            shares_normalized: 187.722726,
            price: 1,
            tx_hash: "0x028baff23a90c10728606781d15077098ee93c991ea204aa52a0bd2869187574",
            title: "Will the DOJ charge Boeing?",
            timestamp: 1721263049,
            order_hash: "",
            user: "0x7c3db723f1d4d8cb9c550095203b686cb11e5c6b"
          },
          {
            token_id: "",
            side: "MERGE",
            market_slug: "bitcoin-price-test",
            condition_id: "0x4567b275e6b667a6217f5cb4f06a797d3a1eaf1d0281fb5bc8c75e2046ae7e57",
            shares: 5000000,
            shares_normalized: 5.0,
            price: 0.75,
            tx_hash: "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
            title: "Test Market",
            timestamp: 1721176649,
            order_hash: "",
            user: "0x7c3db723f1d4d8cb9c550095203b686cb11e5c6b"
          }
        ]
      end

      let(:pagination_data) do
        {
          limit: 50,
          offset: 0,
          count: 1250,
          has_more: true,
          pagination_key: "eyJibG9ja190aW1lc3RhbXAiOiIyMDI1LTAxLTE5VDEyOjAwOjAwLjAwMFoifQ=="
        }
      end

      let(:response) { DomeAPI::ActivityResponse.new(activities: activities_data, pagination: pagination_data) }

      it "initializes with activities and pagination" do
        expect(response.activities.size).to eq(2)
        expect(response.activities.first).to be_a(DomeAPI::Order)
        expect(response.pagination).to eq(pagination_data)
      end

      it "provides pagination helpers" do
        expect(response.total_activities).to eq(1250)
        expect(response.limit).to eq(50)
        expect(response.offset).to eq(0)
        expect(response.has_more?).to be true
        expect(response.pagination_key).to eq("eyJibG9ja190aW1lc3RhbXAiOiIyMDI1LTAxLTE5VDEyOjAwOjAwLjAwMFoifQ==")
      end

      it "provides collection methods" do
        expect(response.size).to eq(2)
        expect(response.empty?).to be false
        expect(response[0].side).to eq("REDEEM")
        expect(response[1].side).to eq("MERGE")
      end

      it "converts to hash and JSON" do
        hash = response.to_h
        expect(hash[:activities].size).to eq(2)
        expect(hash[:pagination]).to eq(pagination_data)
        
        json = JSON.parse(response.to_json)
        expect(json["activities"].size).to eq(2)
        expect(json["pagination"]).to eq(pagination_data.transform_keys(&:to_s))
      end
    end

    describe "#get_markets" do
      let(:mock_response) do
        double("Net::HTTPSuccess").tap do |response|
          allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
          allow(response).to receive(:body).and_return({
            markets: [
              {
                market_slug: "bitcoin-up-or-down-july-25-8pm-et",
                condition_id: "0x4567b275e6b667a6217f5cb4f06a797d3a1eaf1d0281fb5bc8c75e2046ae7e57",
                title: "Will Bitcoin be above $50,000 on July 25, 2025 at 8:00 PM ET?",
                description: "This market will resolve to Yes if Bitcoin (BTC) is trading above $50,000 at 8:00 PM ET on July 25, 2025.",
                outcomes: [
                  {
                    outcome: "Yes",
                    token_id: "58519484510520807142687824915233722607092670035910114837910294451210534222702"
                  },
                  {
                    outcome: "No",
                    token_id: "104612081187206848956763018128517335758189185749897027211060738913329108425255"
                  }
                ],
                start_time: 1757008834,
                end_time: 1757008834,
                volume: 1250000.5,
                liquidity: 500000.25,
                tags: ["crypto", "bitcoin", "price-prediction"],
                status: "ACTIVE"
              },
              {
                market_slug: "will-the-doj-charge-boeing",
                condition_id: "0x92e4b1b8e0621fab0537486e7d527322569d7a8fd394b3098ff4bb1d6e1c0bbd",
                title: "Will the DOJ charge Boeing?",
                description: "This market will resolve to Yes if the DOJ charges Boeing.",
                outcomes: [
                  {
                    outcome: "Yes",
                    token_id: "1234567890123456789012345678901234567890123456789012345678901234567890"
                  },
                  {
                    outcome: "No",
                    token_id: "9876543210987654321098765432109876543210987654321098765432109876543210"
                  }
                ],
                start_time: 1721263049,
                end_time: 1721263049,
                volume: 500000.0,
                liquidity: 250000.0,
                tags: ["politics", "legal"],
                status: "ACTIVE"
              }
            ],
            pagination: {
              limit: 20,
              offset: 0,
              total: 150,
              has_more: true,
              pagination_key: "eyJibG9ja190aW1lc3RhbXAiOiIyMDI1LTAxLTE5VDEyOjAwOjAwLjAwMFoifQ=="
            }
          }.to_json)
        end
      end

      before do
        allow(client).to receive(:make_request).and_return(mock_response)
      end

      it "fetches markets with default parameters" do
        result = client.get_markets
        
        expect(result).to be_a(DomeAPI::MarketsResponse)
        expect(result.markets.size).to eq(2)
        expect(result.markets.first).to be_a(DomeAPI::Market)
        expect(result.markets.first.title).to eq("Will Bitcoin be above $50,000 on July 25, 2025 at 8:00 PM ET?")
        expect(result.markets.first.status).to eq("ACTIVE")
        expect(result.pagination[:total]).to eq(150)
        expect(result.total_markets).to eq(150)
        expect(result.has_more?).to be true
      end

      it "fetches markets with custom parameters" do
        options = {
          tags: ["crypto", "bitcoin"],
          limit: 10
        }
        
        result = client.get_markets(options)
        
        expect(result).to be_a(DomeAPI::MarketsResponse)
        expect(client).to have_received(:make_request)
      end

      it "uses pagination_key instead of offset when provided" do
        cursor = "eyJibG9ja190aW1lc3RhbXAiOiIyMDI1LTAxLTE5VDEyOjAwOjAwLjAwMFoifQ=="
        client.get_markets(limit: 20, pagination_key: cursor)
        
        expect(client).to have_received(:make_request) do |uri|
          params = URI.decode_www_form(uri.query).to_h
          expect(params["pagination_key"]).to eq(cursor)
          expect(params).not_to have_key("offset")
        end
      end

      it "fetches markets with market slug filter" do
        options = {
          market_slug: ["bitcoin-up-or-down-july-25-8pm-et"],
          limit: 5
        }
        
        result = client.get_markets(options)
        
        expect(result).to be_a(DomeAPI::MarketsResponse)
        expect(client).to have_received(:make_request)
      end

      it "fetches markets with condition ID filter" do
        options = {
          condition_id: ["0x4567b275e6b667a6217f5cb4f06a797d3a1eaf1d0281fb5bc8c75e2046ae7e57"],
          limit: 5
        }
        
        result = client.get_markets(options)
        
        expect(result).to be_a(DomeAPI::MarketsResponse)
        expect(client).to have_received(:make_request)
      end

      it "validates limit parameter" do
        expect { client.get_markets(limit: 0) }.to raise_error(ArgumentError, /Limit must be between 1 and 100/)
        expect { client.get_markets(limit: 101) }.to raise_error(ArgumentError, /Limit must be between 1 and 100/)
      end

      it "validates offset parameter" do
        expect { client.get_markets(offset: -1) }.to raise_error(ArgumentError, /Offset must be >= 0/)
      end

      it "validates array parameters" do
        expect { client.get_markets(market_slug: "not-an-array") }.to raise_error(ArgumentError, /market_slug must be an array/)
        expect { client.get_markets(event_slug: "not-an-array") }.to raise_error(ArgumentError, /event_slug must be an array/)
        expect { client.get_markets(condition_id: "not-an-array") }.to raise_error(ArgumentError, /condition_id must be an array/)
        expect { client.get_markets(tags: "not-an-array") }.to raise_error(ArgumentError, /tags must be an array/)
      end

      it "handles empty response" do
        empty_response = double("Net::HTTPSuccess").tap do |response|
          allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
          allow(response).to receive(:body).and_return({ markets: [], pagination: {} }.to_json)
        end
        
        allow(client).to receive(:make_request).and_return(empty_response)
        
        result = client.get_markets
        expect(result.markets).to be_empty
        expect(result.empty?).to be true
      end

      it "handles HTTP errors" do
        allow(client).to receive(:make_request).and_raise(DomeAPI::Error, "Unauthorized: Invalid API key")
        
        expect { client.get_markets }.to raise_error(DomeAPI::Error, /Unauthorized/)
      end
    end

    describe "Outcome class" do
      let(:outcome_data) do
        {
          outcome: "Yes",
          token_id: "58519484510520807142687824915233722607092670035910114837910294451210534222702"
        }
      end

      let(:outcome) { DomeAPI::Outcome.new(outcome_data) }

      it "initializes with correct attributes" do
        expect(outcome.outcome).to eq("Yes")
        expect(outcome.token_id).to eq("58519484510520807142687824915233722607092670035910114837910294451210534222702")
      end

      it "identifies yes outcomes" do
        expect(outcome.yes?).to be true
        expect(outcome.no?).to be false
      end

      it "identifies no outcomes" do
        no_outcome = DomeAPI::Outcome.new(outcome_data.merge(outcome: "No"))
        expect(no_outcome.no?).to be true
        expect(no_outcome.yes?).to be false
      end

      it "converts to hash and JSON" do
        expect(outcome.to_h).to eq(outcome_data)
        expect(JSON.parse(outcome.to_json)).to eq(outcome_data.transform_keys(&:to_s))
      end
    end

    describe "Market class" do
      let(:market_data) do
        {
          market_slug: "bitcoin-up-or-down-july-25-8pm-et",
          condition_id: "0x4567b275e6b667a6217f5cb4f06a797d3a1eaf1d0281fb5bc8c75e2046ae7e57",
          title: "Will Bitcoin be above $50,000 on July 25, 2025 at 8:00 PM ET?",
          description: "This market will resolve to Yes if Bitcoin (BTC) is trading above $50,000 at 8:00 PM ET on July 25, 2025.",
          outcomes: [
            {
              outcome: "Yes",
              token_id: "58519484510520807142687824915233722607092670035910114837910294451210534222702"
            },
            {
              outcome: "No",
              token_id: "104612081187206848956763018128517335758189185749897027211060738913329108425255"
            }
          ],
          start_time: 1757008834,
          end_time: 1757008834,
          volume: 1250000.5,
          liquidity: 500000.25,
          tags: ["crypto", "bitcoin", "price-prediction"],
          status: "ACTIVE"
        }
      end

      let(:market) { DomeAPI::Market.new(market_data) }

      it "initializes with correct attributes" do
        expect(market.market_slug).to eq("bitcoin-up-or-down-july-25-8pm-et")
        expect(market.title).to eq("Will Bitcoin be above $50,000 on July 25, 2025 at 8:00 PM ET?")
        expect(market.volume).to eq(1250000.5)
        expect(market.liquidity).to eq(500000.25)
        expect(market.tags).to eq(["crypto", "bitcoin", "price-prediction"])
        expect(market.status).to eq("ACTIVE")
      end

      it "provides outcome access" do
        expect(market.outcomes.size).to eq(2)
        expect(market.outcomes.first).to be_a(DomeAPI::Outcome)
        expect(market.yes_outcome).to be_a(DomeAPI::Outcome)
        expect(market.no_outcome).to be_a(DomeAPI::Outcome)
        expect(market.yes_token_id).to eq("58519484510520807142687824915233722607092670035910114837910294451210534222702")
        expect(market.no_token_id).to eq("104612081187206848956763018128517335758189185749897027211060738913329108425255")
      end

      it "identifies market status" do
        expect(market.active?).to be true
        expect(market.closed?).to be false
        expect(market.resolved?).to be false
      end

      it "provides time conversion" do
        expect(market.start_date).to be_a(Time)
        expect(market.end_date).to be_a(Time)
        expect(market.formatted_start_date).to match(/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} UTC/)
        expect(market.formatted_end_date).to match(/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} UTC/)
      end

      it "provides tag checking" do
        expect(market.has_tag?("crypto")).to be true
        expect(market.has_tag?("bitcoin")).to be true
        expect(market.has_tag?("politics")).to be false
        expect(market.crypto_market?).to be true
        expect(market.politics_market?).to be false
      end

      it "converts to hash and JSON" do
        expect(market.to_h).to be_a(Hash)
        expect(market.to_h[:market_slug]).to eq("bitcoin-up-or-down-july-25-8pm-et")
        expect(JSON.parse(market.to_json)).to be_a(Hash)
      end
    end

    describe "MarketsResponse class" do
      let(:markets_data) do
        [
          {
            market_slug: "bitcoin-up-or-down-july-25-8pm-et",
            condition_id: "0x4567b275e6b667a6217f5cb4f06a797d3a1eaf1d0281fb5bc8c75e2046ae7e57",
            title: "Will Bitcoin be above $50,000 on July 25, 2025 at 8:00 PM ET?",
            description: "This market will resolve to Yes if Bitcoin (BTC) is trading above $50,000 at 8:00 PM ET on July 25, 2025.",
            outcomes: [
              {
                outcome: "Yes",
                token_id: "58519484510520807142687824915233722607092670035910114837910294451210534222702"
              },
              {
                outcome: "No",
                token_id: "104612081187206848956763018128517335758189185749897027211060738913329108425255"
              }
            ],
            start_time: 1757008834,
            end_time: 1757008834,
            volume: 1250000.5,
            liquidity: 500000.25,
            tags: ["crypto", "bitcoin", "price-prediction"],
            status: "ACTIVE"
          },
          {
            market_slug: "will-the-doj-charge-boeing",
            condition_id: "0x92e4b1b8e0621fab0537486e7d527322569d7a8fd394b3098ff4bb1d6e1c0bbd",
            title: "Will the DOJ charge Boeing?",
            description: "This market will resolve to Yes if the DOJ charges Boeing.",
            outcomes: [
              {
                outcome: "Yes",
                token_id: "1234567890123456789012345678901234567890123456789012345678901234567890"
              },
              {
                outcome: "No",
                token_id: "9876543210987654321098765432109876543210987654321098765432109876543210"
              }
            ],
            start_time: 1721263049,
            end_time: 1721263049,
            volume: 500000.0,
            liquidity: 250000.0,
            tags: ["politics", "legal"],
            status: "ACTIVE"
          }
        ]
      end

      let(:pagination_data) do
        {
          limit: 20,
          offset: 0,
          total: 150,
          has_more: true,
          pagination_key: "eyJibG9ja190aW1lc3RhbXAiOiIyMDI1LTAxLTE5VDEyOjAwOjAwLjAwMFoifQ=="
        }
      end

      let(:response) { DomeAPI::MarketsResponse.new(markets: markets_data, pagination: pagination_data) }

      it "initializes with markets and pagination" do
        expect(response.markets.size).to eq(2)
        expect(response.markets.first).to be_a(DomeAPI::Market)
        expect(response.pagination).to eq(pagination_data)
      end

      it "provides pagination helpers" do
        expect(response.total_markets).to eq(150)
        expect(response.limit).to eq(20)
        expect(response.offset).to eq(0)
        expect(response.has_more?).to be true
        expect(response.pagination_key).to eq("eyJibG9ja190aW1lc3RhbXAiOiIyMDI1LTAxLTE5VDEyOjAwOjAwLjAwMFoifQ==")
      end

      it "provides collection methods" do
        expect(response.size).to eq(2)
        expect(response.empty?).to be false
        expect(response[0].market_slug).to eq("bitcoin-up-or-down-july-25-8pm-et")
        expect(response[1].market_slug).to eq("will-the-doj-charge-boeing")
      end

      it "converts to hash and JSON" do
        hash = response.to_h
        expect(hash[:markets].size).to eq(2)
        expect(hash[:pagination]).to eq(pagination_data)
        
        json = JSON.parse(response.to_json)
        expect(json["markets"].size).to eq(2)
        expect(json["pagination"]).to eq(pagination_data.transform_keys(&:to_s))
      end
    end
  end

  describe "WebSocket" do
    let(:api_key) { "test_websocket_api_key" }
    let(:websocket) { DomeAPI::WebSocket.new(api_key: api_key) }

    describe "#initialize" do
      it "initializes with provided API key" do
        ws = DomeAPI::WebSocket.new(api_key: "my_key")
        expect(ws.api_key).to eq("my_key")
      end

      it "initializes with empty subscription_ids" do
        expect(websocket.subscription_ids).to eq([])
      end

      it "falls back to ENV when no api_key provided" do
        allow(ENV).to receive(:[]).with("DOME_API_KEY").and_return("env_key")
        ws = DomeAPI::WebSocket.new
        expect(ws.api_key).to eq("env_key")
      end
    end

    describe "#on_event" do
      it "registers an event handler block" do
        handler_called = false
        websocket.on_event { |_data| handler_called = true }
        
        # Simulate receiving an event message
        event_message = { "type" => "event", "data" => { "token_id" => "123" } }.to_json
        websocket.send(:handle_message, event_message)
        
        expect(handler_called).to be true
      end

      it "returns self for chaining" do
        result = websocket.on_event { |_| }
        expect(result).to eq(websocket)
      end

      it "passes event data to the handler" do
        received_data = nil
        websocket.on_event { |data| received_data = data }
        
        event_data = { "token_id" => "123", "side" => "BUY", "price" => 0.5 }
        event_message = { "type" => "event", "data" => event_data }.to_json
        websocket.send(:handle_message, event_message)
        
        expect(received_data).to eq(event_data)
      end
    end

    describe "#on_ack" do
      it "registers an acknowledgment handler block" do
        handler_called = false
        websocket.on_ack { |_sid| handler_called = true }
        
        # Simulate receiving an ack message
        ack_message = { "type" => "ack", "subscription_id" => "sub_123" }.to_json
        websocket.send(:handle_message, ack_message)
        
        expect(handler_called).to be true
      end

      it "returns self for chaining" do
        result = websocket.on_ack { |_| }
        expect(result).to eq(websocket)
      end

      it "passes subscription_id to the handler" do
        received_sid = nil
        websocket.on_ack { |sid| received_sid = sid }
        
        ack_message = { "type" => "ack", "subscription_id" => "sub_456" }.to_json
        websocket.send(:handle_message, ack_message)
        
        expect(received_sid).to eq("sub_456")
      end

      it "stores subscription_id in subscription_ids array" do
        ack_message = { "type" => "ack", "subscription_id" => "sub_789" }.to_json
        websocket.send(:handle_message, ack_message)
        
        expect(websocket.subscription_ids).to include("sub_789")
      end
    end

    describe "#subscribe" do
      let(:mock_ws) { double("WebSocket::Client::Simple") }

      before do
        websocket.instance_variable_set(:@ws, mock_ws)
        allow(mock_ws).to receive(:__send__)
      end

      it "sends a subscribe message with correct payload" do
        expected_payload = {
          action: "subscribe",
          platform: "polymarket",
          version: 1,
          type: "orders",
          filters: { users: ["0xabc123"] }
        }.to_json

        expect(mock_ws).to receive(:__send__).with(:send, expected_payload)

        websocket.subscribe(
          platform: "polymarket",
          type: "orders",
          filters: { users: ["0xabc123"] }
        )
      end

      it "uses default version of 1" do
        websocket.subscribe(
          platform: "polymarket",
          type: "orders",
          filters: { users: [] }
        )

        expect(mock_ws).to have_received(:__send__) do |method, json|
          payload = JSON.parse(json)
          expect(payload["version"]).to eq(1)
        end
      end

      it "allows custom version" do
        websocket.subscribe(
          platform: "polymarket",
          type: "orders",
          filters: { users: [] },
          version: 2
        )

        expect(mock_ws).to have_received(:__send__) do |method, json|
          payload = JSON.parse(json)
          expect(payload["version"]).to eq(2)
        end
      end

      it "does nothing if websocket is not connected" do
        websocket.instance_variable_set(:@ws, nil)
        
        # Should not raise
        expect { 
          websocket.subscribe(platform: "polymarket", type: "orders", filters: {})
        }.not_to raise_error
      end
    end

    describe "#close" do
      it "closes the websocket connection if open" do
        mock_ws = double("WebSocket::Client::Simple")
        allow(mock_ws).to receive(:close)
        websocket.instance_variable_set(:@ws, mock_ws)

        websocket.close

        expect(mock_ws).to have_received(:close)
      end

      it "handles nil websocket gracefully" do
        websocket.instance_variable_set(:@ws, nil)
        
        expect { websocket.close }.not_to raise_error
      end

      it "handles close errors gracefully" do
        mock_ws = double("WebSocket::Client::Simple")
        allow(mock_ws).to receive(:close).and_raise(StandardError, "Connection error")
        websocket.instance_variable_set(:@ws, mock_ws)

        expect { websocket.close }.not_to raise_error
      end
    end

    describe "#run" do
      it "raises error if API key is blank" do
        ws = DomeAPI::WebSocket.new(api_key: nil)
        allow(ENV).to receive(:[]).with("DOME_API_KEY").and_return(nil)
        
        # Re-initialize to pick up nil API key
        ws = DomeAPI::WebSocket.new(api_key: "")
        
        expect { ws.run }.to raise_error(DomeAPI::Error, /DOME_API_KEY is not set/)
      end
    end

    describe "message handling" do
      it "handles event messages" do
        events = []
        websocket.on_event { |data| events << data }

        event_data = { "token_id" => "abc", "side" => "SELL" }
        websocket.send(:handle_message, { "type" => "event", "data" => event_data }.to_json)

        expect(events.size).to eq(1)
        expect(events.first["token_id"]).to eq("abc")
      end

      it "handles ack messages" do
        acks = []
        websocket.on_ack { |sid| acks << sid }

        websocket.send(:handle_message, { "type" => "ack", "subscription_id" => "sub_1" }.to_json)

        expect(acks).to eq(["sub_1"])
      end

      it "ignores empty messages" do
        events = []
        websocket.on_event { |data| events << data }

        websocket.send(:handle_message, "")
        websocket.send(:handle_message, "   ")
        websocket.send(:handle_message, nil)

        expect(events).to be_empty
      end

      it "ignores malformed JSON" do
        events = []
        websocket.on_event { |data| events << data }

        websocket.send(:handle_message, "not valid json {{{")

        expect(events).to be_empty
      end

      it "ignores unknown message types" do
        events = []
        acks = []
        websocket.on_event { |data| events << data }
        websocket.on_ack { |sid| acks << sid }

        websocket.send(:handle_message, { "type" => "unknown", "data" => {} }.to_json)

        expect(events).to be_empty
        expect(acks).to be_empty
      end

      it "ignores event messages without data" do
        events = []
        websocket.on_event { |data| events << data }

        websocket.send(:handle_message, { "type" => "event" }.to_json)

        expect(events).to be_empty
      end

      it "handles multiple events in sequence" do
        events = []
        websocket.on_event { |data| events << data }

        websocket.send(:handle_message, { "type" => "event", "data" => { "id" => 1 } }.to_json)
        websocket.send(:handle_message, { "type" => "event", "data" => { "id" => 2 } }.to_json)
        websocket.send(:handle_message, { "type" => "event", "data" => { "id" => 3 } }.to_json)

        expect(events.size).to eq(3)
        expect(events.map { |e| e["id"] }).to eq([1, 2, 3])
      end

      it "handles multiple subscription acks" do
        websocket.send(:handle_message, { "type" => "ack", "subscription_id" => "sub_1" }.to_json)
        websocket.send(:handle_message, { "type" => "ack", "subscription_id" => "sub_2" }.to_json)

        expect(websocket.subscription_ids).to eq(["sub_1", "sub_2"])
      end
    end

    describe "callback chaining" do
      it "allows chaining on_event and on_ack" do
        events = []
        acks = []

        result = websocket
          .on_event { |data| events << data }
          .on_ack { |sid| acks << sid }

        expect(result).to eq(websocket)

        websocket.send(:handle_message, { "type" => "event", "data" => { "x" => 1 } }.to_json)
        websocket.send(:handle_message, { "type" => "ack", "subscription_id" => "sub_x" }.to_json)

        expect(events.size).to eq(1)
        expect(acks).to eq(["sub_x"])
      end
    end

    describe "constants" do
      it "has correct WSS_URL" do
        expect(DomeAPI::WebSocket::WSS_URL).to eq("wss://ws.domeapi.io")
      end

      it "has correct DEFAULT_VERSION" do
        expect(DomeAPI::WebSocket::DEFAULT_VERSION).to eq(1)
      end
    end
  end
end
