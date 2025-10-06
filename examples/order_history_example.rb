#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/dome-api'

# Example usage of the Dome API Order History endpoint
def order_history_example
  # Initialize the client with your API key
  client = DomeAPI::Client.new(api_key: ENV['DOME_API_KEY'])
  
  puts "=== Dome API Order History Example ===\n\n"
  
  # Example 1: Get all orders with default parameters
  puts "1. Fetching order history with default parameters..."
  begin
    response = client.get_order_history
    puts "   Found #{response.size} orders out of #{response.total_orders} total"
    puts "   Has more pages: #{response.has_more?}"
    
    if response.orders.any?
      order = response.orders.first
      puts "   First order: #{order.side} #{order.shares_normalized} shares at $#{order.price}"
      puts "   Market: #{order.title}"
    end
  rescue DomeAPI::Error => e
    puts "   Error: #{e.message}"
  end
  
  puts "\n" + "="*50 + "\n"
  
  # Example 2: Get orders with specific filters
  puts "2. Fetching orders with filters..."
  begin
    options = {
      market_slug: "bitcoin-up-or-down-july-25-8pm-et",
      limit: 10,
      offset: 0,
      user: "0x7c3db723f1d4d8cb9c550095203b686cb11e5c6b"
    }
    
    response = client.get_order_history(options)
    puts "   Found #{response.size} orders for specific user and market"
    
    response.orders.each_with_index do |order, index|
      puts "   Order #{index + 1}: #{order.side} #{order.shares_normalized} shares at $#{order.price}"
    end
  rescue DomeAPI::Error => e
    puts "   Error: #{e.message}"
  end
  
  puts "\n" + "="*50 + "\n"
  
  # Example 3: Get orders within a time range
  puts "3. Fetching orders within time range..."
  begin
    # Get orders from the last 30 days
    end_time = Time.now.to_i
    start_time = end_time - (30 * 24 * 60 * 60) # 30 days ago
    
    options = {
      start_time: start_time,
      end_time: end_time,
      limit: 5
    }
    
    response = client.get_order_history(options)
    puts "   Found #{response.size} orders in the last 30 days"
    
    response.orders.each do |order|
      order_time = Time.at(order.timestamp)
      puts "   #{order.side} order on #{order_time.strftime('%Y-%m-%d %H:%M:%S')} - #{order.title}"
    end
  rescue DomeAPI::Error => e
    puts "   Error: #{e.message}"
  end
  
  puts "\n" + "="*50 + "\n"
  
  # Example 4: Pagination example
  puts "4. Pagination example..."
  begin
    offset = 0
    limit = 3
    total_processed = 0
    
    loop do
      response = client.get_order_history(limit: limit, offset: offset)
      break if response.orders.empty?
      
      puts "   Page #{offset / limit + 1}: Processing #{response.orders.size} orders"
      total_processed += response.orders.size
      
      break unless response.has_more?
      offset += limit
    end
    
    puts "   Total orders processed: #{total_processed}"
  rescue DomeAPI::Error => e
    puts "   Error: #{e.message}"
  end
end

# Run the example if this file is executed directly
if __FILE__ == $0
  order_history_example
end
