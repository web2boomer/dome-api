#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/dome-api'

# Example usage of the Dome API Markets endpoint
def markets_example
  # Initialize the client with your API key
  client = DomeAPI::Client.new(api_key: ENV['DOME_API_KEY'])
  
  puts "=== Dome API Markets Example ===\n\n"
  
  # Example 1: Get all markets with default parameters
  puts "1. Fetching markets with default parameters..."
  begin
    response = client.get_markets
    puts "   Found #{response.size} markets out of #{response.total_markets} total"
    puts "   Has more pages: #{response.has_more?}"
    
    if response.markets.any?
      market = response.markets.first
      puts "   First market: #{market.title}"
      puts "   Status: #{market.status}"
      puts "   Volume: $#{market.volume}"
      puts "   Tags: #{market.tags.join(', ')}"
    end
  rescue DomeAPI::Error => e
    puts "   Error: #{e.message}"
  end
  
  puts "\n" + "="*50 + "\n"
  
  # Example 2: Get markets with specific filters
  puts "2. Fetching markets with filters..."
  begin
    options = {
      tags: ["crypto", "bitcoin"],
      limit: 10,
      offset: 0
    }
    
    response = client.get_markets(options)
    puts "   Found #{response.size} crypto/bitcoin markets"
    
    response.markets.each_with_index do |market, index|
      puts "   Market #{index + 1}: #{market.title}"
      puts "   Volume: $#{market.volume}, Liquidity: $#{market.liquidity}"
    end
  rescue DomeAPI::Error => e
    puts "   Error: #{e.message}"
  end
  
  puts "\n" + "="*50 + "\n"
  
  # Example 3: Get markets by market slug
  puts "3. Fetching markets by market slug..."
  begin
    options = {
      market_slug: ["bitcoin-up-or-down-july-25-8pm-et"],
      limit: 5
    }
    
    response = client.get_markets(options)
    puts "   Found #{response.size} markets for specific slug"
    
    if response.markets.any?
      market = response.markets.first
      puts "   Market: #{market.title}"
      puts "   Description: #{market.description}"
      puts "   Yes token: #{market.yes_token_id}"
      puts "   No token: #{market.no_token_id}"
    end
  rescue DomeAPI::Error => e
    puts "   Error: #{e.message}"
  end
  
  puts "\n" + "="*50 + "\n"
  
  # Example 4: Get markets by condition ID
  puts "4. Fetching markets by condition ID..."
  begin
    options = {
      condition_id: ["0x4567b275e6b667a6217f5cb4f06a797d3a1eaf1d0281fb5bc8c75e2046ae7e57"],
      limit: 5
    }
    
    response = client.get_markets(options)
    puts "   Found #{response.size} markets for specific condition"
    
    if response.markets.any?
      market = response.markets.first
      puts "   Market: #{market.title}"
      puts "   Start time: #{market.formatted_start_date}"
      puts "   End time: #{market.formatted_end_date}"
    end
  rescue DomeAPI::Error => e
    puts "   Error: #{e.message}"
  end
  
  puts "\n" + "="*50 + "\n"
  
  # Example 5: Filter by multiple tags
  puts "5. Fetching markets by multiple tags..."
  begin
    options = {
      tags: ["politics", "election"],
      limit: 10
    }
    
    response = client.get_markets(options)
    puts "   Found #{response.size} politics/election markets"
    
    response.markets.each do |market|
      puts "   #{market.title}"
      puts "   Tags: #{market.tags.join(', ')}"
      puts "   Status: #{market.status}"
    end
  rescue DomeAPI::Error => e
    puts "   Error: #{e.message}"
  end
  
  puts "\n" + "="*50 + "\n"
  
  # Example 6: Pagination example
  puts "6. Pagination example..."
  begin
    offset = 0
    limit = 5
    total_processed = 0
    
    loop do
      response = client.get_markets(limit: limit, offset: offset)
      break if response.markets.empty?
      
      puts "   Page #{offset / limit + 1}: Processing #{response.markets.size} markets"
      total_processed += response.markets.size
      
      break unless response.has_more?
      offset += limit
    end
    
    puts "   Total markets processed: #{total_processed}"
  rescue DomeAPI::Error => e
    puts "   Error: #{e.message}"
  end
  
  puts "\n" + "="*50 + "\n"
  
  # Example 7: Market analysis
  puts "7. Market analysis example..."
  begin
    response = client.get_markets(limit: 20)
    
    if response.markets.any?
      # Analyze by status
      active_markets = response.markets.select(&:active?)
      closed_markets = response.markets.select(&:closed?)
      resolved_markets = response.markets.select(&:resolved?)
      
      puts "   Market Status Analysis:"
      puts "   Active: #{active_markets.size}"
      puts "   Closed: #{closed_markets.size}"
      puts "   Resolved: #{resolved_markets.size}"
      
      # Analyze by category
      crypto_markets = response.markets.select(&:crypto_market?)
      politics_markets = response.markets.select(&:politics_market?)
      
      puts "   Category Analysis:"
      puts "   Crypto markets: #{crypto_markets.size}"
      puts "   Politics markets: #{politics_markets.size}"
      
      # Volume analysis
      total_volume = response.markets.sum(&:volume)
      avg_volume = total_volume / response.markets.size
      
      puts "   Volume Analysis:"
      puts "   Total volume: $#{total_volume.round(2)}"
      puts "   Average volume: $#{avg_volume.round(2)}"
      
      # Top volume markets
      top_markets = response.markets.sort_by(&:volume).reverse.first(3)
      puts "   Top 3 markets by volume:"
      top_markets.each_with_index do |market, index|
        puts "   #{index + 1}. #{market.title} - $#{market.volume}"
      end
    end
  rescue DomeAPI::Error => e
    puts "   Error: #{e.message}"
  end
end

# Run the example if this file is executed directly
if __FILE__ == $0
  markets_example
end
