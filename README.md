# Dome

Ruby client for the Polymarket CLOB. Full API documentation can be found [here](https://docs.polymarket.com/developers/dev-resources/main). Ported from [py-dome-api](https://github.com/Polymarket/py-dome-api).

It's a work in progress, not every part of the client has been tested. But you can place orders so wen lambo? 

### Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add 'dome'

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install 'dome'

### Requisites

#### Allowances

See guidance on [py-dome-api](https://github.com/Polymarket/py-dome-api).

### Usage

Below is a comprehensive usage guide for the DomeAPI gem. This client supports both Level 1 (private key) and Level 2 (API credentials) authentication modes.

#### Basic Setup

First, require the gem and initialize a client:

```ruby
require 'dome-api'

# Initialize with host URL (use appropriate environment)
client = DomeAPI::Client.new(
  host: 'https://clob.polymarket.com',  # Production
  # host: 'https://clob-staging.polymarket.com',  # Staging
  chain_id: DomeAPI::Constants::POLYGON  # 137 for Polygon mainnet
)
```

#### Authentication

The client supports two authentication levels:

**Level 1 Authentication (Private Key)**
```ruby
# Initialize with private key for Level 1 auth
client = DomeAPI::Client.new(
  host: 'https://clob.polymarket.com',
  chain_id: DomeAPI::Constants::POLYGON,
  key: 'your_private_key_here'  # 0x-prefixed private key
)

# Get your wallet address
address = client.get_address
puts "Wallet address: #{address}"
```

**Level 2 Authentication (API Credentials)**
```ruby
# Create API credentials (requires Level 1 auth first)
creds = client.create_api_key
puts DomeAPI::Constants::CREDENTIAL_CREATION_WARNING
puts "API Key: #{creds.api_key}"
puts "Secret: #{creds.api_secret}"
puts "Passphrase: #{creds.api_passphrase}"

# Set credentials for Level 2 auth
client.set_api_creds(creds)
```

#### Market Data

Get market information and pricing data:

```ruby
# Get all markets
markets = client.get_markets
puts "Available markets: #{markets}"

# Get order book for a specific token
token_id = "0x1234567890abcdef..."  # Replace with actual token ID
order_book = client.get_order_book(token_id)
puts "Order book: #{order_book}"

# Get current price for a token
price_response = client.get_price(token_id, "BUY")
puts "Current buy price: #{price_response.body}"

# Get spread information
spread_response = client.get_spread(token_id)
puts "Spread: #{spread_response.body}"
```

#### Placing Orders

**Limit Orders**
```ruby
# Create order arguments
order_args = DomeAPI::OrderArgs.new(
  token_id: "0x1234567890abcdef...",  # Token ID
  price: 0.65,                        # Price in USD
  size: 100,                          # Size in token units
  side: "BUY",                        # "BUY" or "SELL"
  fee_rate_bps: 0,                    # Fee rate in basis points
  nonce: Time.now.to_i,               # Nonce for order uniqueness
  expiration: Time.now.to_i + 3600    # Expiration timestamp
)

# Create and post the order
order = client.create_and_post_order(order_args)
puts "Order created: #{order}"
```

**Market Orders**
```ruby
# Create market order arguments
market_order_args = DomeAPI::MarketOrderArgs.new(
  token_id: "0x1234567890abcdef...",
  amount: 100,                        # Amount in USD
  side: "BUY",
  order_type: DomeAPI::OrderType::FOK  # Fill or Kill
)

# Create and post market order
market_order = client.create_and_post_order(market_order_args)
puts "Market order created: #{market_order}"
```

#### Order Management

```ruby
# Get your open orders
orders = client.get_orders
puts "Open orders: #{orders}"

# Get specific order details
order_id = "your_order_id"
order_details = client.get_order(order_id)
puts "Order details: #{order_details}"

# Cancel a specific order
cancel_response = client.cancel(order_id)
puts "Cancel response: #{cancel_response}"

# Cancel all orders
cancel_all_response = client.cancel_all
puts "Cancel all response: #{cancel_all_response}"
```

#### Trading History

```ruby
# Get your trade history
trades = client.get_trades
puts "Trade history: #{trades}"

# Get last trade price for a token
last_trade = client.get_last_trade_price(token_id)
puts "Last trade price: #{last_trade.body}"
```

#### Balance and Allowances

```ruby
# Check balance and allowance (requires Level 2 auth)
# Note: This feature is currently under development
balance = client.get_balance_allowance
puts "Balance and allowance: #{balance}"

# Update allowance (requires Level 2 auth)
# Note: This feature is currently under development
update_response = client.update_balance_allowance
puts "Allowance update: #{update_response}"
```

#### Complete Example

Here's a complete example showing how to place a limit order:

```ruby
require 'dome-api'

# Initialize client with private key
client = DomeAPI::Client.new(
  host: 'https://clob.polymarket.com',
  chain_id: DomeAPI::Constants::POLYGON,
  key: 'your_private_key_here'
)

# Get market data
token_id = "0x1234567890abcdef..."  # Replace with actual token ID
order_book = client.get_order_book(token_id)
puts "Order book retrieved"

# Place a limit order
order_args = DomeAPI::OrderArgs.new(
  token_id: token_id,
  price: 0.65,
  size: 100,
  side: "BUY",
  fee_rate_bps: 0,
  nonce: Time.now.to_i,
  expiration: Time.now.to_i + 3600
)

order = client.create_and_post_order(order_args)
puts "Order placed successfully: #{order}"

# Monitor the order
sleep(5)
orders = client.get_orders
puts "Current orders: #{orders}"
```

#### Error Handling

The client includes comprehensive error handling:

```ruby
begin
  order = client.create_and_post_order(order_args)
  puts "Order successful: #{order}"
rescue DomeAPI::Error => e
  puts "CLOB error: #{e.message}"
rescue StandardError => e
  puts "Unexpected error: #{e.message}"
end
```

#### Important Notes

1. **Token Allowances**: Ensure proper token allowances are set before trading (see Requisites section above)
2. **Network Selection**: Use appropriate `chain_id` for your target network (Polygon mainnet or Amoy testnet)
3. **Rate Limiting**: Be mindful of API rate limits when making multiple requests
4. **Order Expiration**: Always set appropriate expiration times for your orders
5. **Security**: Keep your private keys and API credentials secure
6. **Development Status**: This gem is currently in development. Some features may be incomplete or subject to change

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).
