# frozen_string_literal: true

module DomeAPI
  class WalletPnLResponse
    attr_reader :granularity, :start_time, :end_time, :wallet_address, :pnl_over_time

    def initialize(attributes = {})
      @granularity = attributes[:granularity]
      @start_time = attributes[:start_time]
      @end_time = attributes[:end_time]
      @wallet_address = attributes[:wallet_address]
      @pnl_over_time = (attributes[:pnl_over_time] || []).map { |data| PnLData.new(data) }
    end

    def empty?
      pnl_over_time.empty?
    end

    def size
      pnl_over_time.size
    end

    def each(&block)
      pnl_over_time.each(&block)
    end

    def [](index)
      pnl_over_time[index]
    end

    def first
      pnl_over_time.first
    end

    def last
      pnl_over_time.last
    end

    def start_date
      return nil unless @start_time
      Time.at(@start_time)
    end

    def end_date
      return nil unless @end_time
      Time.at(@end_time)
    end

    def formatted_start_date(format = :readable)
      return nil unless start_date
      start_date.strftime("%Y-%m-%d")
    end

    def formatted_end_date(format = :readable)
      return nil unless end_date
      end_date.strftime("%Y-%m-%d")
    end

    def current_pnl
      return nil if pnl_over_time.empty?
      last.pnl_to_date
    end

    def current_pnl_dollars
      return nil unless current_pnl
      current_pnl / 100.0
    end

    def total_pnl
      return 0 if pnl_over_time.empty?
      last.pnl_to_date
    end

    def total_pnl_dollars
      total_pnl / 100.0
    end

    def peak_pnl
      return 0 if pnl_over_time.empty?
      pnl_over_time.map(&:pnl_to_date).max
    end

    def peak_pnl_dollars
      peak_pnl / 100.0
    end

    def trough_pnl
      return 0 if pnl_over_time.empty?
      pnl_over_time.map(&:pnl_to_date).min
    end

    def trough_pnl_dollars
      trough_pnl / 100.0
    end

    def max_drawdown
      return 0 if pnl_over_time.empty?
      
      peak = peak_pnl
      trough = trough_pnl
      
      return 0 if peak <= 0
      (peak - trough).abs
    end

    def max_drawdown_dollars
      max_drawdown / 100.0
    end

    def max_drawdown_percent
      return 0 if peak_pnl <= 0
      (max_drawdown.to_f / peak_pnl) * 100
    end

    def profit_days
      pnl_over_time.count(&:profit?)
    end

    def loss_days
      pnl_over_time.count(&:loss?)
    end

    def break_even_days
      pnl_over_time.count(&:break_even?)
    end

    def win_rate
      return 0 if pnl_over_time.empty?
      (profit_days.to_f / pnl_over_time.size) * 100
    end

    def pnl_series
      pnl_over_time.map { |pnl| [pnl.time, pnl.pnl_to_date] }.compact
    end

    def daily_changes
      return [] if pnl_over_time.size < 2
      
      changes = []
      (1...pnl_over_time.size).each do |i|
        current = pnl_over_time[i].pnl_to_date
        previous = pnl_over_time[i - 1].pnl_to_date
        changes << {
          date: pnl_over_time[i].time,
          change: current - previous,
          change_dollars: (current - previous) / 100.0
        }
      end
      changes
    end

    def best_day
      return nil if daily_changes.empty?
      daily_changes.max_by { |change| change[:change] }
    end

    def worst_day
      return nil if daily_changes.empty?
      daily_changes.min_by { |change| change[:change] }
    end

    def average_daily_pnl
      return 0 if daily_changes.empty?
      daily_changes.map { |change| change[:change] }.sum / daily_changes.size.to_f
    end

    def average_daily_pnl_dollars
      average_daily_pnl / 100.0
    end

    def to_a
      pnl_over_time
    end

    def to_h
      {
        granularity: @granularity,
        start_time: @start_time,
        end_time: @end_time,
        wallet_address: @wallet_address,
        pnl_over_time: pnl_over_time.map(&:to_h)
      }
    end

    def to_json(*args)
      to_h.to_json(*args)
    end
  end
end
