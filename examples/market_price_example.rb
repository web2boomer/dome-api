#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/dome-api'

# Example usage of the Dome API Market Price endpoint
def market_price_example
  # Initialize the client with your API key
  client = DomeAPI::Client.new(api_key: ENV['DOME_API_KEY'])
  
  puts "=== Dome API Market Price Example ===\n\n"
  
  # Example token ID (replace with actual token ID)
  token_id = "58519484510520807142687824915233722607092670035910114837910294451210534222702"
  
  # Example 1: Get current market price
  puts "1. Fetching current market price..."
  begin
    price = client.get_market_price(token_id)
    puts "   Current price: $#{price.price}"
    puts "   Price time: #{price.formatted_time(:readable)}"
    puts "   Is current: #{price.current?}"
    puts "   Is historical: #{price.historical?}"
  rescue DomeAPI::Error => e
    puts "   Error: #{e.message}"
  end
  
  puts "\n" + "="*50 + "\n"
  
  # Example 2: Get historical market price
  puts "2. Fetching historical market price..."
  begin
    # Get price from 1 hour ago
    one_hour_ago = Time.now.to_i - 3600
    historical_price = client.get_market_price(token_id, at_time: one_hour_ago)
    
    puts "   Historical price: $#{historical_price.price}"
    puts "   Price time: #{historical_price.formatted_time(:readable)}"
    puts "   Is current: #{historical_price.current?}"
    puts "   Is historical: #{historical_price.historical?}"
  rescue DomeAPI::Error => e
    puts "   Error: #{e.message}"
  end
  
  puts "\n" + "="*50 + "\n"
  
  # Example 3: Price comparison over time
  puts "3. Price comparison over time..."
  begin
    current_price = client.get_market_price(token_id)
    
    # Get prices from different time periods
    time_periods = [
      { name: "1 hour ago", time: Time.now.to_i - 3600 },
      { name: "6 hours ago", time: Time.now.to_i - 21600 },
      { name: "1 day ago", time: Time.now.to_i - 86400 }
    ]
    
    puts "   Current price: $#{current_price.price} (#{current_price.formatted_time(:readable)})"
    
    time_periods.each do |period|
      begin
        historical_price = client.get_market_price(token_id, at_time: period[:time])
        price_change = current_price.price - historical_price.price
        change_percent = (price_change / historical_price.price) * 100
        
        puts "   #{period[:name]}: $#{historical_price.price} (#{historical_price.formatted_time(:readable)})"
        puts "     Change: #{price_change > 0 ? '+' : ''}#{price_change.round(4)} (#{change_percent.round(2)}%)"
      rescue DomeAPI::Error => e
        puts "   #{period[:name]}: Error - #{e.message}"
      end
    end
  rescue DomeAPI::Error => e
    puts "   Error: #{e.message}"
  end
  
  puts "\n" + "="*50 + "\n"
  
  # Example 4: Price monitoring
  puts "4. Price monitoring example..."
  begin
    puts "   Monitoring price changes (press Ctrl+C to stop)..."
    
    last_price = nil
    start_time = Time.now
    
    # Monitor for 30 seconds (in real usage, you'd want longer intervals)
    6.times do |i|
      current_price = client.get_market_price(token_id)
      
      if last_price
        change = current_price.price - last_price.price
        change_percent = (change / last_price.price) * 100
        
        puts "   #{Time.now.strftime('%H:%M:%S')} - Price: $#{current_price.price} " \
             "(#{change > 0 ? '+' : ''}#{change.round(4)}, #{change_percent.round(2)}%)"
      else
        puts "   #{Time.now.strftime('%H:%M:%S')} - Initial price: $#{current_price.price}"
      end
      
      last_price = current_price
      sleep(5) # Wait 5 seconds between checks
    end
  rescue Interrupt
    puts "\n   Monitoring stopped by user"
  rescue DomeAPI::Error => e
    puts "   Error: #{e.message}"
  end
  
  puts "\n" + "="*50 + "\n"
  
  # Example 5: Working with MarketPrice objects
  puts "5. Working with MarketPrice objects..."
  begin
    price = client.get_market_price(token_id)
    
    puts "   Price object methods:"
    puts "   - price: #{price.price}"
    puts "   - at_time: #{price.at_time}"
    puts "   - timestamp: #{price.timestamp}"
    puts "   - current?: #{price.current?}"
    puts "   - historical?: #{price.historical?}"
    puts "   - formatted_time(:iso): #{price.formatted_time(:iso)}"
    puts "   - formatted_time(:readable): #{price.formatted_time(:readable)}"
    puts "   - to_s: #{price.to_s}"
    
    puts "\n   Hash representation:"
    puts "   #{price.to_h}"
    
    puts "\n   JSON representation:"
    puts "   #{price.to_json}"
  rescue DomeAPI::Error => e
    puts "   Error: #{e.message}"
  end
end

# Run the example if this file is executed directly
if __FILE__ == $0
  market_price_example
end
