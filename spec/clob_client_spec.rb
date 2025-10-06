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
  end
end
