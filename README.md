# Dome

Ruby client for the Polymarket CLOB. Full API documentation can be found [here](https://docs.polymarket.com/developers/dev-resources/main). Ported from [py-dome-api](https://github.com/Polymarket/py-dome-api).

It's a work in progress, not every part of the client has been tested. But you can place orders so wen lambo? 

### Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add 'dome-api'

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install 'dome-api'



## Usage

### Basic Setup

```ruby
require 'dome-api'

# Initialize the client with your API key
client = DomeAPI::Client.new(api_key: 'your_api_key_here')
```

### Order History

The gem provides access to the Dome API's Order History endpoint, allowing you to fetch historical order data with various filtering options.

#### Basic Usage

```ruby
# Get all orders with default parameters (limit: 100, offset: 0)
response = client.get_order_history

# Access the orders
response.orders.each do |order|
  puts "#{order.side} #{order.shares_normalized} shares at $#{order.price}"
  puts "Market: #{order.title}"
  puts "User: #{order.user}"
  puts "---"
end

# Check pagination info
puts "Total orders: #{response.total_orders}"
puts "Has more pages: #{response.has_more?}"
```

#### Filtering Orders

```ruby
# Filter by market slug
response = client.get_order_history(
  market_slug: "bitcoin-up-or-down-july-25-8pm-et"
)

# Filter by user wallet address
response = client.get_order_history(
  user: "0x7c3db723f1d4d8cb9c550095203b686cb11e5c6b"
)

# Filter by time range (Unix timestamps)
response = client.get_order_history(
  start_time: 1640995200,  # January 1, 2022
  end_time: 1672531200     # January 1, 2023
)

# Filter by token ID
response = client.get_order_history(
  token_id: "58519484510520807142687824915233722607092670035910114837910294451210534222702"
)

# Filter by condition ID
response = client.get_order_history(
  condition_id: "0x4567b275e6b667a6217f5cb4f06a797d3a1eaf1d0281fb5bc8c75e2046ae7e57"
)
```

#### Pagination

```ruby
# Get first page
response = client.get_order_history(limit: 50, offset: 0)

# Get second page
response = client.get_order_history(limit: 50, offset: 50)

# Loop through all pages
offset = 0
limit = 100

loop do
  response = client.get_order_history(limit: limit, offset: offset)
  break if response.orders.empty?
  
  # Process orders
  response.orders.each do |order|
    puts "Processing order: #{order.order_hash}"
  end
  
  break unless response.has_more?
  offset += limit
end
```

#### Working with Order Objects

Each order in the response is a `DomeAPI::Order` object with the following attributes:

```ruby
order = response.orders.first

# Basic order information
order.token_id          # Token identifier
order.side             # "BUY" or "SELL"
order.price            # Order price (Float)
order.shares           # Raw shares amount (Integer)
order.shares_normalized # Normalized shares amount (Float)
order.tx_hash          # Transaction hash
order.order_hash       # Order hash
order.timestamp        # Unix timestamp
order.user             # User wallet address

# Market information
order.market_slug      # Market identifier
order.condition_id     # Condition identifier
order.title            # Market title/question

# Helper methods
order.buy?             # Returns true if side is "BUY"
order.sell?            # Returns true if side is "SELL"

# Convert to hash or JSON
order.to_h             # Returns hash representation
order.to_json          # Returns JSON string
```

#### Working with Response Objects

The `get_order_history` method returns a `DomeAPI::OrderHistoryResponse` object:

```ruby
response = client.get_order_history

# Access orders
response.orders                    # Array of Order objects
response.orders.size              # Number of orders in current page
response.orders.empty?            # Check if no orders
response.orders[0]                # Access first order
response.orders.each { |o| ... }  # Iterate over orders

# Pagination information
response.pagination                # Hash with pagination data
response.total_orders             # Total number of orders available
response.limit                    # Current page limit
response.offset                   # Current page offset
response.has_more?                # Whether more pages are available

# Convert to hash or JSON
response.to_h                     # Returns hash representation
response.to_json                  # Returns JSON string
```

#### Error Handling

```ruby
begin
  response = client.get_order_history
rescue DomeAPI::Error => e
  puts "API Error: #{e.message}"
rescue ArgumentError => e
  puts "Parameter Error: #{e.message}"
end
```

#### Complete Example

```ruby
require 'dome-api'

# Initialize client
client = DomeAPI::Client.new(api_key: ENV['DOME_API_KEY'])

# Get orders for a specific market in the last 30 days
end_time = Time.now.to_i
start_time = end_time - (30 * 24 * 60 * 60)

begin
  response = client.get_order_history(
    market_slug: "bitcoin-up-or-down-july-25-8pm-et",
    start_time: start_time,
    end_time: end_time,
    limit: 100
  )
  
  puts "Found #{response.size} orders out of #{response.total_orders} total"
  
  # Analyze buy vs sell orders
  buy_orders = response.orders.select(&:buy?)
  sell_orders = response.orders.select(&:sell?)
  
  puts "Buy orders: #{buy_orders.size}"
  puts "Sell orders: #{sell_orders.size}"
  
  # Calculate average prices
  if buy_orders.any?
    avg_buy_price = buy_orders.map(&:price).sum / buy_orders.size
    puts "Average buy price: $#{avg_buy_price.round(4)}"
  end
  
  if sell_orders.any?
    avg_sell_price = sell_orders.map(&:price).sum / sell_orders.size
    puts "Average sell price: $#{avg_sell_price.round(4)}"
  end
  
rescue DomeAPI::Error => e
  puts "Error fetching orders: #{e.message}"
end
```

### Candlestick Data

The gem provides access to the Dome API's Candlestick endpoint, allowing you to fetch historical candlestick data for technical analysis and charting.

#### Basic Usage

```ruby
# Get 1-minute candlesticks for the last hour
end_time = Time.now.to_i
start_time = end_time - 3600 # 1 hour ago

response = client.get_candlesticks(
  "0x4567b275e6b667a6217f5cb4f06a797d3a1eaf1d0281fb5bc8c75e2046ae7e57",
  start_time: start_time,
  end_time: end_time,
  interval: 1
)

puts "Found #{response.size} candlesticks"
puts "Total volume: #{response.total_volume}"
```

#### Different Time Intervals

```ruby
# 1-minute intervals (default)
response = client.get_candlesticks(condition_id, start_time: start_time, end_time: end_time, interval: 1)

# 1-hour intervals
response = client.get_candlesticks(condition_id, start_time: start_time, end_time: end_time, interval: 60)

# 1-day intervals
response = client.get_candlesticks(condition_id, start_time: start_time, end_time: end_time, interval: 1440)
```

#### Working with Candlestick Data

Each candlestick in the response is a `DomeAPI::CandlestickData` object:

```ruby
candlestick = response.first

# Basic candlestick data
candlestick.end_period_ts        # Unix timestamp
candlestick.volume               # Trading volume
candlestick.open_interest        # Open interest

# Price data (OHLC)
candlestick.price.open           # Opening price
candlestick.price.high           # Highest price
candlestick.price.low            # Lowest price
candlestick.price.close          # Closing price
candlestick.price.mean           # Mean price
candlestick.price.previous       # Previous period price

# Dollar values (as strings)
candlestick.price.open_dollars   # Opening price in dollars
candlestick.price.high_dollars   # Highest price in dollars
candlestick.price.low_dollars    # Lowest price in dollars
candlestick.price.close_dollars  # Closing price in dollars

# Bid/Ask data
candlestick.yes_ask.open         # Ask opening price
candlestick.yes_ask.close        # Ask closing price
candlestick.yes_ask.high         # Ask highest price
candlestick.yes_ask.low          # Ask lowest price

candlestick.yes_bid.open         # Bid opening price
candlestick.yes_bid.close        # Bid closing price
candlestick.yes_bid.high         # Bid highest price
candlestick.yes_bid.low          # Bid lowest price

# Helper methods
candlestick.end_time             # Time object
candlestick.formatted_end_time(:readable)  # "2024-01-15 14:30:00 UTC"
candlestick.price_range          # High - Low
candlestick.price_change         # Close - Open
candlestick.price_change_percent # Price change percentage
```

#### Working with CandlestickResponse

The `get_candlesticks` method returns a `DomeAPI::CandlestickResponse` object:

```ruby
response = client.get_candlesticks(condition_id, start_time: start_time, end_time: end_time)

# Access candlesticks
response.candlesticks                    # Array of CandlestickData objects
response.candlesticks.size              # Number of candlesticks
response.candlesticks.empty?            # Check if no data
response.candlesticks[0]                # Access first candlestick
response.candlesticks.each { |c| ... }  # Iterate over candlesticks

# Analysis methods
response.price_data                     # Array of price data objects
response.volume_data                    # Array of volume values
response.open_interest_data             # Array of open interest values
response.total_volume                   # Sum of all volumes
response.average_volume                 # Average volume
response.price_range                    # Overall price range (max high - min low)
response.price_trend                    # :up, :down, or :flat
response.time_series                    # Array of [time, close_price] pairs
```

#### Technical Analysis Example

```ruby
require 'dome-api'

client = DomeAPI::Client.new(api_key: ENV['DOME_API_KEY'])
condition_id = "your_condition_id_here"

# Get hourly data for the last 24 hours
end_time = Time.now.to_i
start_time = end_time - 86400

response = client.get_candlesticks(
  condition_id,
  start_time: start_time,
  end_time: end_time,
  interval: 60
)

# Calculate simple moving average
close_prices = response.candlesticks.map { |c| c.price&.close }.compact
sma = close_prices.sum / close_prices.size

puts "24-hour SMA: #{sma.round(4)}"
puts "Current price: #{response.last.price&.close}"
puts "Price trend: #{response.price_trend}"
puts "Total volume: #{response.total_volume}"
```

#### Charting Example

```ruby
require 'dome-api'

client = DomeAPI::Client.new(api_key: ENV['DOME_API_KEY'])
condition_id = "your_condition_id_here"

# Get daily data for the last week
end_time = Time.now.to_i
start_time = end_time - (7 * 86400)

response = client.get_candlesticks(
  condition_id,
  start_time: start_time,
  end_time: end_time,
  interval: 1440
)

# Prepare data for charting
chart_data = response.candlesticks.map do |candlestick|
  {
    time: candlestick.end_time,
    open: candlestick.price&.open,
    high: candlestick.price&.high,
    low: candlestick.price&.low,
    close: candlestick.price&.close,
    volume: candlestick.volume
  }
end

# Use with your preferred charting library
# chart_data.each { |data| puts "#{data[:time]}: O:#{data[:open]} H:#{data[:high]} L:#{data[:low]} C:#{data[:close]} V:#{data[:volume]}" }
```

### Wallet Profit and Loss

The gem provides access to the Dome API's Wallet PnL endpoint, allowing you to fetch profit and loss data for any wallet address over time.

#### Basic Usage

```ruby
# Get daily PnL for a wallet
response = client.get_wallet_pnl(
  "0x7c3db723f1d4d8cb9c550095203b686cb11e5c6b",
  granularity: "day"
)

puts "Current PnL: $#{response.current_pnl_dollars.round(2)}"
puts "Total PnL: $#{response.total_pnl_dollars.round(2)}"
```

#### Different Granularities

```ruby
# Daily granularity
response = client.get_wallet_pnl(wallet_address, granularity: "day")

# Weekly granularity
response = client.get_wallet_pnl(wallet_address, granularity: "week")

# Monthly granularity
response = client.get_wallet_pnl(wallet_address, granularity: "month")

# Yearly granularity
response = client.get_wallet_pnl(wallet_address, granularity: "year")

# All time data
response = client.get_wallet_pnl(wallet_address, granularity: "all")
```

#### Time Range Filtering

```ruby
# Get PnL for specific time range
end_time = Time.now.to_i
start_time = end_time - (30 * 86400) # 30 days ago

response = client.get_wallet_pnl(
  wallet_address,
  granularity: "day",
  start_time: start_time,
  end_time: end_time
)
```

#### Working with PnL Data

Each PnL data point is a `DomeAPI::PnLData` object:

```ruby
pnl = response.first

# Basic PnL data
pnl.timestamp          # Unix timestamp
pnl.pnl_to_date        # PnL value in cents
pnl.pnl_dollars        # PnL value in dollars

# Time formatting
pnl.time               # Time object
pnl.formatted_time(:readable)  # "2024-01-15 14:30:00 UTC"
pnl.formatted_time(:date_only) # "2024-01-15"

# PnL classification
pnl.profit?            # Returns true if PnL > 0
pnl.loss?              # Returns true if PnL < 0
pnl.break_even?        # Returns true if PnL == 0
```

#### Working with WalletPnLResponse

The `get_wallet_pnl` method returns a `DomeAPI::WalletPnLResponse` object:

```ruby
response = client.get_wallet_pnl(wallet_address, granularity: "day")

# Basic information
response.wallet_address        # Wallet address
response.granularity          # Time granularity
response.start_time           # Start timestamp
response.end_time             # End timestamp
response.start_date           # Start date (Time object)
response.end_date             # End date (Time object)

# PnL data
response.pnl_over_time        # Array of PnLData objects
response.size                 # Number of data points
response.empty?               # Check if no data
response[0]                   # Access first PnL data
response.first                # First PnL data
response.last                 # Last PnL data

# Current PnL
response.current_pnl          # Current PnL in cents
response.current_pnl_dollars  # Current PnL in dollars
response.total_pnl            # Total PnL in cents
response.total_pnl_dollars    # Total PnL in dollars

# Performance metrics
response.peak_pnl             # Peak PnL in cents
response.peak_pnl_dollars     # Peak PnL in dollars
response.trough_pnl           # Trough PnL in cents
response.trough_pnl_dollars   # Trough PnL in dollars
response.max_drawdown         # Max drawdown in cents
response.max_drawdown_dollars # Max drawdown in dollars
response.max_drawdown_percent # Max drawdown percentage

# Statistics
response.profit_days          # Number of profitable days
response.loss_days            # Number of loss days
response.break_even_days      # Number of break-even days
response.win_rate             # Win rate percentage

# Analysis
response.pnl_series           # Array of [time, pnl] pairs
response.daily_changes        # Array of daily PnL changes
response.best_day             # Best performing day
response.worst_day            # Worst performing day
response.average_daily_pnl    # Average daily PnL in cents
response.average_daily_pnl_dollars # Average daily PnL in dollars
```

#### Performance Analysis Example

```ruby
require 'dome-api'

client = DomeAPI::Client.new(api_key: ENV['DOME_API_KEY'])
wallet_address = "0x7c3db723f1d4d8cb9c550095203b686cb11e5c6b"

# Get daily PnL for the last 30 days
end_time = Time.now.to_i
start_time = end_time - (30 * 86400)

response = client.get_wallet_pnl(
  wallet_address,
  granularity: "day",
  start_time: start_time,
  end_time: end_time
)

puts "Performance Analysis:"
puts "Current PnL: $#{response.current_pnl_dollars.round(2)}"
puts "Peak PnL: $#{response.peak_pnl_dollars.round(2)}"
puts "Max Drawdown: $#{response.max_drawdown_dollars.round(2)} (#{response.max_drawdown_percent.round(1)}%)"
puts "Win Rate: #{response.win_rate.round(1)}%"
puts "Average Daily PnL: $#{response.average_daily_pnl_dollars.round(2)}"

# Best and worst days
if response.daily_changes.any?
  best = response.best_day
  worst = response.worst_day
  
  puts "Best day: #{best[:date].strftime('%Y-%m-%d')} (+$#{best[:change_dollars].round(2)})"
  puts "Worst day: #{worst[:date].strftime('%Y-%m-%d')} ($#{worst[:change_dollars].round(2)})"
end
```

#### PnL Tracking Example

```ruby
require 'dome-api'

client = DomeAPI::Client.new(api_key: ENV['DOME_API_KEY'])
wallet_address = "0x7c3db723f1d4d8cb9c550095203b686cb11e5c6b"

# Track PnL over different time periods
time_periods = [
  { name: "Last 7 days", days: 7, granularity: "day" },
  { name: "Last 30 days", days: 30, granularity: "day" },
  { name: "Last 3 months", days: 90, granularity: "week" },
  { name: "Last year", days: 365, granularity: "month" }
]

time_periods.each do |period|
  end_time = Time.now.to_i
  start_time = end_time - (period[:days] * 86400)
  
  response = client.get_wallet_pnl(
    wallet_address,
    granularity: period[:granularity],
    start_time: start_time,
    end_time: end_time
  )
  
  puts "#{period[:name]}:"
  puts "  Data points: #{response.size}"
  puts "  Current PnL: $#{response.current_pnl_dollars.round(2)}"
  puts "  Win rate: #{response.win_rate.round(1)}%"
  puts "  Max drawdown: #{response.max_drawdown_percent.round(1)}%"
  puts
end
```

### Market Price

The gem provides access to the Dome API's Market Price endpoint, allowing you to fetch current and historical market prices for any token.

#### Basic Usage

```ruby
# Get current market price
price = client.get_market_price("58519484510520807142687824915233722607092670035910114837910294451210534222702")

puts "Current price: $#{price.price}"
puts "Price time: #{price.formatted_time(:readable)}"
```

#### Historical Prices

```ruby
# Get historical market price
historical_time = Time.now.to_i - 3600 # 1 hour ago
historical_price = client.get_market_price(
  "58519484510520807142687824915233722607092670035910114837910294451210534222702",
  at_time: historical_time
)

puts "Historical price: $#{historical_price.price}"
puts "Price was at: #{historical_price.formatted_time(:readable)}"
```

#### Working with MarketPrice Objects

Each market price response is a `DomeAPI::MarketPrice` object with the following attributes and methods:

```ruby
price = client.get_market_price(token_id)

# Basic attributes
price.price          # Price value (Float)
price.at_time        # Unix timestamp (Integer)

# Helper methods
price.current?       # Returns true if price is recent (within 5 minutes)
price.historical?    # Returns true if price is historical
price.timestamp      # Returns Time object
price.formatted_time(:iso)      # ISO 8601 format
price.formatted_time(:readable) # Human readable format
price.formatted_time            # Default format

# Conversion methods
price.to_h           # Returns hash representation
price.to_json        # Returns JSON string
price.to_s           # Returns formatted string
```

#### Price Monitoring Example

```ruby
require 'dome-api'

client = DomeAPI::Client.new(api_key: ENV['DOME_API_KEY'])
token_id = "your_token_id_here"

# Monitor price changes
last_price = nil

loop do
  current_price = client.get_market_price(token_id)
  
  if last_price
    change = current_price.price - last_price.price
    change_percent = (change / last_price.price) * 100
    
    puts "#{Time.now.strftime('%H:%M:%S')} - Price: $#{current_price.price} " \
         "(#{change > 0 ? '+' : ''}#{change.round(4)}, #{change_percent.round(2)}%)"
  else
    puts "Initial price: $#{current_price.price}"
  end
  
  last_price = current_price
  sleep(30) # Check every 30 seconds
end
```

#### Price Comparison Example

```ruby
require 'dome-api'

client = DomeAPI::Client.new(api_key: ENV['DOME_API_KEY'])
token_id = "your_token_id_here"

# Compare current price with historical prices
current_price = client.get_market_price(token_id)

time_periods = [
  { name: "1 hour ago", time: Time.now.to_i - 3600 },
  { name: "6 hours ago", time: Time.now.to_i - 21600 },
  { name: "1 day ago", time: Time.now.to_i - 86400 }
]

puts "Current price: $#{current_price.price}"

time_periods.each do |period|
  historical_price = client.get_market_price(token_id, at_time: period[:time])
  price_change = current_price.price - historical_price.price
  change_percent = (price_change / historical_price.price) * 100
  
  puts "#{period[:name]}: $#{historical_price.price} " \
       "(#{price_change > 0 ? '+' : ''}#{price_change.round(4)}, #{change_percent.round(2)}%)"
end
```

### API Reference

#### Client Methods

- `get_order_history(options = {})` - Fetches historical order data
- `get_market_price(token_id, at_time: nil)` - Fetches current or historical market price
- `get_candlesticks(condition_id, start_time:, end_time:, interval: 1)` - Fetches historical candlestick data
- `get_wallet_pnl(wallet_address, granularity:, start_time: nil, end_time: nil)` - Fetches wallet profit and loss data

#### Order History Query Parameters

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `market_slug` | String | Filter by market slug | `"bitcoin-up-or-down-july-25-8pm-et"` |
| `condition_id` | String | Filter by condition ID | `"0x4567b275e6b667a6217f5cb4f06a797d3a1eaf1d0281fb5bc8c75e2046ae7e57"` |
| `token_id` | String | Filter by token ID | `"58519484510520807142687824915233722607092670035910114837910294451210534222702"` |
| `start_time` | Integer | Filter from Unix timestamp (inclusive) | `1640995200` |
| `end_time` | Integer | Filter until Unix timestamp (inclusive) | `1672531200` |
| `limit` | Integer | Number of orders to return (1-1000, default: 100) | `50` |
| `offset` | Integer | Number of orders to skip (default: 0) | `0` |
| `user` | String | Filter by user wallet address | `"0x7c3db723f1d4d8cb9c550095203b686cb11e5c6b"` |

#### Market Price Parameters

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `token_id` | String | The token ID of the market (required) | `"58519484510520807142687824915233722607092670035910114837910294451210534222702"` |
| `at_time` | Integer | Unix timestamp for historical price (optional) | `1740000000` |

#### Candlestick Parameters

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `condition_id` | String | The condition ID of the market (required) | `"0x4567b275e6b667a6217f5cb4f06a797d3a1eaf1d0281fb5bc8c75e2046ae7e57"` |
| `start_time` | Integer | Unix timestamp for start of time range (required) | `1640995200` |
| `end_time` | Integer | Unix timestamp for end of time range (required) | `1672531200` |
| `interval` | Integer | Interval length: 1=1m, 60=1h, 1440=1d (default: 1) | `60` |

#### Wallet PnL Parameters

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `wallet_address` | String | The wallet address to get PnL for (required) | `"0x7c3db723f1d4d8cb9c550095203b686cb11e5c6b"` |
| `granularity` | String | Time granularity: "day", "week", "month", "year", "all" (required) | `"day"` |
| `start_time` | Integer | Unix timestamp for start of time range (optional) | `1726857600` |
| `end_time` | Integer | Unix timestamp for end of time range (optional) | `1758316829` |

