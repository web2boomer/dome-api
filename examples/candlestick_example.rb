#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/dome-api'

# Example usage of the Dome API Candlestick endpoint
def candlestick_example
  # Initialize the client with your API key
  client = DomeAPI::Client.new(api_key: ENV['DOME_API_KEY'])
  
  puts "=== Dome API Candlestick Example ===\n\n"
  
  # Example condition ID (replace with actual condition ID)
  condition_id = "0x4567b275e6b667a6217f5cb4f06a797d3a1eaf1d0281fb5bc8c75e2046ae7e57"
  
  # Example 1: Get 1-minute candlesticks for the last hour
  puts "1. Fetching 1-minute candlesticks for the last hour..."
  begin
    end_time = Time.now.to_i
    start_time = end_time - 3600 # 1 hour ago
    
    response = client.get_candlesticks(
      condition_id,
      start_time: start_time,
      end_time: end_time,
      interval: 1
    )
    
    puts "   Found #{response.size} candlesticks"
    puts "   Token ID: #{response.token_id}"
    puts "   Total volume: #{response.total_volume}"
    puts "   Average volume: #{response.average_volume.round(2)}"
    puts "   Price trend: #{response.price_trend}"
    
    if response.candlesticks.any?
      first = response.first
      last = response.last
      puts "   First candlestick: #{first.formatted_end_time(:readable)} - #{first.to_s}"
      puts "   Last candlestick: #{last.formatted_end_time(:readable)} - #{last.to_s}"
    end
  rescue DomeAPI::Error => e
    puts "   Error: #{e.message}"
  end
  
  puts "\n" + "="*50 + "\n"
  
  # Example 2: Get hourly candlesticks for the last 24 hours
  puts "2. Fetching hourly candlesticks for the last 24 hours..."
  begin
    end_time = Time.now.to_i
    start_time = end_time - 86400 # 24 hours ago
    
    response = client.get_candlesticks(
      condition_id,
      start_time: start_time,
      end_time: end_time,
      interval: 60 # 1 hour
    )
    
    puts "   Found #{response.size} hourly candlesticks"
    puts "   Price range: #{response.price_range.round(4)}"
    
    # Analyze price movement
    if response.candlesticks.size >= 2
      first_price = response.first.price&.close
      last_price = response.last.price&.close
      
      if first_price && last_price
        change = last_price - first_price
        change_percent = (change / first_price) * 100
        puts "   Price change: #{change > 0 ? '+' : ''}#{change.round(4)} (#{change_percent.round(2)}%)"
      end
    end
  rescue DomeAPI::Error => e
    puts "   Error: #{e.message}"
  end
  
  puts "\n" + "="*50 + "\n"
  
  # Example 3: Get daily candlesticks for the last week
  puts "3. Fetching daily candlesticks for the last week..."
  begin
    end_time = Time.now.to_i
    start_time = end_time - (7 * 86400) # 7 days ago
    
    response = client.get_candlesticks(
      condition_id,
      start_time: start_time,
      end_time: end_time,
      interval: 1440 # 1 day
    )
    
    puts "   Found #{response.size} daily candlesticks"
    
    # Show daily summary
    response.candlesticks.each_with_index do |candlestick, index|
      day = candlestick.formatted_end_time(:readable)
      price = candlestick.price
      volume = candlestick.volume
      
      if price
        change = price.close - price.open
        change_percent = price.open.zero? ? 0 : (change / price.open) * 100
        
        puts "   Day #{index + 1} (#{day}):"
        puts "     Price: $#{price.open} → $#{price.close} (#{change > 0 ? '+' : ''}#{change_percent.round(2)}%)"
        puts "     Range: $#{price.low} - $#{price.high}"
        puts "     Volume: #{volume}"
      end
    end
  rescue DomeAPI::Error => e
    puts "   Error: #{e.message}"
  end
  
  puts "\n" + "="*50 + "\n"
  
  # Example 4: Technical analysis
  puts "4. Technical analysis example..."
  begin
    end_time = Time.now.to_i
    start_time = end_time - 3600 # 1 hour ago
    
    response = client.get_candlesticks(
      condition_id,
      start_time: start_time,
      end_time: end_time,
      interval: 1
    )
    
    if response.candlesticks.size >= 5
      puts "   Analyzing last 5 candlesticks:"
      
      # Calculate simple moving average (SMA)
      close_prices = response.candlesticks.last(5).map { |c| c.price&.close }.compact
      if close_prices.size == 5
        sma = close_prices.sum / close_prices.size
        puts "   5-period SMA: #{sma.round(4)}"
        
        # Current price vs SMA
        current_price = close_prices.last
        if current_price > sma
          puts "   Current price (#{current_price.round(4)}) is above SMA - bullish signal"
        elsif current_price < sma
          puts "   Current price (#{current_price.round(4)}) is below SMA - bearish signal"
        else
          puts "   Current price (#{current_price.round(4)}) equals SMA - neutral"
        end
      end
      
      # Volume analysis
      volumes = response.candlesticks.last(5).map(&:volume)
      avg_volume = volumes.sum / volumes.size.to_f
      current_volume = volumes.last
      
      puts "   Average volume (last 5): #{avg_volume.round(0)}"
      puts "   Current volume: #{current_volume}"
      
      if current_volume > avg_volume * 1.5
        puts "   High volume detected - significant activity"
      elsif current_volume < avg_volume * 0.5
        puts "   Low volume detected - limited activity"
      else
        puts "   Normal volume levels"
      end
    else
      puts "   Not enough data for technical analysis"
    end
  rescue DomeAPI::Error => e
    puts "   Error: #{e.message}"
  end
  
  puts "\n" + "="*50 + "\n"
  
  # Example 5: Working with individual candlestick data
  puts "5. Working with candlestick data..."
  begin
    end_time = Time.now.to_i
    start_time = end_time - 300 # 5 minutes ago
    
    response = client.get_candlesticks(
      condition_id,
      start_time: start_time,
      end_time: end_time,
      interval: 1
    )
    
    if response.candlesticks.any?
      candlestick = response.first
      
      puts "   Individual candlestick analysis:"
      puts "   - End time: #{candlestick.formatted_end_time(:readable)}"
      puts "   - Price range: #{candlestick.price_range.round(4)}"
      puts "   - Price change: #{candlestick.price_change.round(4)}"
      puts "   - Price change %: #{candlestick.price_change_percent.round(2)}%"
      puts "   - Volume: #{candlestick.volume}"
      puts "   - Open interest: #{candlestick.open_interest}"
      
      # Bid/Ask analysis
      if candlestick.yes_ask && candlestick.yes_bid
        ask_spread = candlestick.yes_ask.spread
        bid_spread = candlestick.yes_bid.spread
        
        puts "   - Ask spread: #{ask_spread.round(6)}"
        puts "   - Bid spread: #{bid_spread.round(6)}"
        
        # Calculate mid price
        if candlestick.yes_ask.close && candlestick.yes_bid.close
          mid_price = (candlestick.yes_ask.close + candlestick.yes_bid.close) / 2
          puts "   - Mid price: #{mid_price.round(6)}"
        end
      end
    else
      puts "   No candlestick data available"
    end
  rescue DomeAPI::Error => e
    puts "   Error: #{e.message}"
  end
end

# Run the example if this file is executed directly
if __FILE__ == $0
  candlestick_example
end
