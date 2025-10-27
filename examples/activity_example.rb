#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/dome-api'

# Example usage of the Dome API Activity endpoint
def activity_example
  # Initialize the client with your API key
  client = DomeAPI::Client.new(api_key: ENV['DOME_API_KEY'])
  
  puts "=== Dome API Activity Example ===\n\n"
  
  # Example 1: Get activity for a specific user with default parameters
  puts "1. Fetching activity for a specific user..."
  begin
    user_address = "0x7c3db723f1d4d8cb9c550095203b686cb11e5c6b"
    response = client.get_activity(user_address)
    
    puts "   Found #{response.size} activities out of #{response.total_activities} total"
    puts "   Has more pages: #{response.has_more?}"
    
    if response.activities.any?
      activity = response.activities.first
      puts "   First activity: #{activity.side} #{activity.shares_normalized} shares"
      puts "   Market: #{activity.title}"
      puts "   Timestamp: #{Time.at(activity.timestamp)}"
    end
  rescue DomeAPI::Error => e
    puts "   Error: #{e.message}"
  end
  
  puts "\n" + "="*50 + "\n"
  
  # Example 2: Get activity with specific filters
  puts "2. Fetching activity with filters..."
  begin
    user_address = "0x7c3db723f1d4d8cb9c550095203b686cb11e5c6b"
    options = {
      market_slug: "will-the-doj-charge-boeing",
      limit: 10,
      offset: 0
    }
    
    response = client.get_activity(user_address, options)
    puts "   Found #{response.size} activities for specific market"
    
    response.activities.each_with_index do |activity, index|
      puts "   Activity #{index + 1}: #{activity.side} #{activity.shares_normalized} shares"
      puts "   TX: #{activity.tx_hash}"
    end
  rescue DomeAPI::Error => e
    puts "   Error: #{e.message}"
  end
  
  puts "\n" + "="*50 + "\n"
  
  # Example 3: Get activity within a time range
  puts "3. Fetching activity within time range..."
  begin
    user_address = "0x7c3db723f1d4d8cb9c550095203b686cb11e5c6b"
    
    # Get activity from the last 30 days
    end_time = Time.now.to_i
    start_time = end_time - (30 * 24 * 60 * 60) # 30 days ago
    
    options = {
      start_time: start_time,
      end_time: end_time,
      limit: 5
    }
    
    response = client.get_activity(user_address, options)
    puts "   Found #{response.size} activities in the last 30 days"
    
    response.activities.each do |activity|
      activity_time = Time.at(activity.timestamp)
      puts "   #{activity.side} on #{activity_time.strftime('%Y-%m-%d %H:%M:%S')} - #{activity.title}"
    end
  rescue DomeAPI::Error => e
    puts "   Error: #{e.message}"
  end
  
  puts "\n" + "="*50 + "\n"
  
  # Example 4: Filter by condition ID
  puts "4. Fetching activity for a specific condition..."
  begin
    user_address = "0x7c3db723f1d4d8cb9c550095203b686cb11e5c6b"
    options = {
      condition_id: "0x92e4b1b8e0621fab0537486e7d527322569d7a8fd394b3098ff4bb1d6e1c0bbd",
      limit: 10
    }
    
    response = client.get_activity(user_address, options)
    puts "   Found #{response.size} activities for specific condition"
    
    if response.activities.any?
      activity = response.activities.first
      puts "   First activity: #{activity.side} - #{activity.title}"
    end
  rescue DomeAPI::Error => e
    puts "   Error: #{e.message}"
  end
  
  puts "\n" + "="*50 + "\n"
  
  # Example 5: Pagination example
  puts "5. Pagination example..."
  begin
    user_address = "0x7c3db723f1d4d8cb9c550095203b686cb11e5c6b"
    offset = 0
    limit = 3
    total_processed = 0
    
    loop do
      response = client.get_activity(user_address, limit: limit, offset: offset)
      break if response.activities.empty?
      
      puts "   Page #{offset / limit + 1}: Processing #{response.activities.size} activities"
      total_processed += response.activities.size
      
      break unless response.has_more?
      offset += limit
    end
    
    puts "   Total activities processed: #{total_processed}"
  rescue DomeAPI::Error => e
    puts "   Error: #{e.message}"
  end
end

# Run the example if this file is executed directly
if __FILE__ == $0
  activity_example
end
