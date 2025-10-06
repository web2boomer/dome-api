#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/dome-api'

# Example usage of the Dome API Wallet PnL endpoint
def wallet_pnl_example
  # Initialize the client with your API key
  client = DomeAPI::Client.new(api_key: ENV['DOME_API_KEY'])
  
  puts "=== Dome API Wallet PnL Example ===\n\n"
  
  # Example wallet address (replace with actual wallet address)
  wallet_address = "0x7c3db723f1d4d8cb9c550095203b686cb11e5c6b"
  
  # Example 1: Get daily PnL for the last 30 days
  puts "1. Fetching daily PnL for the last 30 days..."
  begin
    end_time = Time.now.to_i
    start_time = end_time - (30 * 86400) # 30 days ago
    
    response = client.get_wallet_pnl(
      wallet_address,
      granularity: "day",
      start_time: start_time,
      end_time: end_time
    )
    
    puts "   Wallet: #{response.wallet_address}"
    puts "   Period: #{response.formatted_start_date} to #{response.formatted_end_date}"
    puts "   Granularity: #{response.granularity}"
    puts "   Data points: #{response.size}"
    
    if response.pnl_over_time.any?
      puts "   Current PnL: $#{response.current_pnl_dollars.round(2)}"
      puts "   Peak PnL: $#{response.peak_pnl_dollars.round(2)}"
      puts "   Trough PnL: $#{response.trough_pnl_dollars.round(2)}"
      puts "   Max Drawdown: $#{response.max_drawdown_dollars.round(2)} (#{response.max_drawdown_percent.round(1)}%)"
    end
  rescue DomeAPI::Error => e
    puts "   Error: #{e.message}"
  end
  
  puts "\n" + "="*50 + "\n"
  
  # Example 2: Get weekly PnL for the last 3 months
  puts "2. Fetching weekly PnL for the last 3 months..."
  begin
    end_time = Time.now.to_i
    start_time = end_time - (90 * 86400) # 90 days ago
    
    response = client.get_wallet_pnl(
      wallet_address,
      granularity: "week",
      start_time: start_time,
      end_time: end_time
    )
    
    puts "   Found #{response.size} weekly data points"
    puts "   Current PnL: $#{response.current_pnl_dollars.round(2)}"
    puts "   Win rate: #{response.win_rate.round(1)}%"
    puts "   Profit days: #{response.profit_days}"
    puts "   Loss days: #{response.loss_days}"
    puts "   Break-even days: #{response.break_even_days}"
  rescue DomeAPI::Error => e
    puts "   Error: #{e.message}"
  end
  
  puts "\n" + "="*50 + "\n"
  
  # Example 3: Get monthly PnL for the last year
  puts "3. Fetching monthly PnL for the last year..."
  begin
    end_time = Time.now.to_i
    start_time = end_time - (365 * 86400) # 1 year ago
    
    response = client.get_wallet_pnl(
      wallet_address,
      granularity: "month",
      start_time: start_time,
      end_time: end_time
    )
    
    puts "   Found #{response.size} monthly data points"
    puts "   Total PnL: $#{response.total_pnl_dollars.round(2)}"
    puts "   Average daily PnL: $#{response.average_daily_pnl_dollars.round(2)}"
    
    # Show monthly breakdown
    if response.pnl_over_time.any?
      puts "\n   Monthly breakdown:"
      response.pnl_over_time.each_with_index do |pnl, index|
        month = pnl.formatted_time(:date_only)
        pnl_dollars = pnl.pnl_dollars
        status = pnl.profit? ? "📈" : pnl.loss? ? "📉" : "➖"
        
        puts "   #{month}: #{status} $#{pnl_dollars.round(2)}"
      end
    end
  rescue DomeAPI::Error => e
    puts "   Error: #{e.message}"
  end
  
  puts "\n" + "="*50 + "\n"
  
  # Example 4: Performance analysis
  puts "4. Performance analysis..."
  begin
    end_time = Time.now.to_i
    start_time = end_time - (30 * 86400) # 30 days ago
    
    response = client.get_wallet_pnl(
      wallet_address,
      granularity: "day",
      start_time: start_time,
      end_time: end_time
    )
    
    if response.pnl_over_time.size >= 2
      puts "   Performance metrics:"
      puts "   - Current PnL: $#{response.current_pnl_dollars.round(2)}"
      puts "   - Peak PnL: $#{response.peak_pnl_dollars.round(2)}"
      puts "   - Max Drawdown: $#{response.max_drawdown_dollars.round(2)} (#{response.max_drawdown_percent.round(1)}%)"
      puts "   - Win Rate: #{response.win_rate.round(1)}%"
      puts "   - Average Daily PnL: $#{response.average_daily_pnl_dollars.round(2)}"
      
      # Best and worst days
      if response.daily_changes.any?
        best = response.best_day
        worst = response.worst_day
        
        puts "\n   Best day: #{best[:date].strftime('%Y-%m-%d')} (+$#{best[:change_dollars].round(2)})"
        puts "   Worst day: #{worst[:date].strftime('%Y-%m-%d')} ($#{worst[:change_dollars].round(2)})"
      end
      
      # PnL trend
      first_pnl = response.first.pnl_dollars
      last_pnl = response.last.pnl_dollars
      total_change = last_pnl - first_pnl
      change_percent = first_pnl.zero? ? 0 : (total_change / first_pnl.abs) * 100
      
      puts "\n   Period performance:"
      puts "   - Start PnL: $#{first_pnl.round(2)}"
      puts "   - End PnL: $#{last_pnl.round(2)}"
      puts "   - Total change: #{total_change > 0 ? '+' : ''}$#{total_change.round(2)} (#{change_percent.round(1)}%)"
    else
      puts "   Not enough data for performance analysis"
    end
  rescue DomeAPI::Error => e
    puts "   Error: #{e.message}"
  end
  
  puts "\n" + "="*50 + "\n"
  
  # Example 5: Working with individual PnL data points
  puts "5. Working with PnL data points..."
  begin
    end_time = Time.now.to_i
    start_time = end_time - (7 * 86400) # 7 days ago
    
    response = client.get_wallet_pnl(
      wallet_address,
      granularity: "day",
      start_time: start_time,
      end_time: end_time
    )
    
    if response.pnl_over_time.any?
      puts "   Recent PnL data:"
      
      response.pnl_over_time.each do |pnl|
        date = pnl.formatted_time(:date_only)
        pnl_dollars = pnl.pnl_dollars
        status = pnl.profit? ? "Profit" : pnl.loss? ? "Loss" : "Break-even"
        
        puts "   #{date}: $#{pnl_dollars.round(2)} (#{status})"
      end
      
      # PnL series for charting
      puts "\n   PnL series data (for charting):"
      series = response.pnl_series
      series.each do |time, pnl_value|
        puts "   [#{time.strftime('%Y-%m-%d')}, #{pnl_value}]"
      end
    else
      puts "   No PnL data available"
    end
  rescue DomeAPI::Error => e
    puts "   Error: #{e.message}"
  end
  
  puts "\n" + "="*50 + "\n"
  
  # Example 6: Different granularities
  puts "6. Comparing different granularities..."
  begin
    end_time = Time.now.to_i
    start_time = end_time - (30 * 86400) # 30 days ago
    
    granularities = %w[day week month]
    
    granularities.each do |granularity|
      begin
        response = client.get_wallet_pnl(
          wallet_address,
          granularity: granularity,
          start_time: start_time,
          end_time: end_time
        )
        
        puts "   #{granularity.capitalize} granularity:"
        puts "     Data points: #{response.size}"
        puts "     Current PnL: $#{response.current_pnl_dollars.round(2)}"
        puts "     Win rate: #{response.win_rate.round(1)}%"
      rescue DomeAPI::Error => e
        puts "   #{granularity.capitalize} granularity: Error - #{e.message}"
      end
    end
  rescue DomeAPI::Error => e
    puts "   Error: #{e.message}"
  end
end

# Run the example if this file is executed directly
if __FILE__ == $0
  wallet_pnl_example
end
