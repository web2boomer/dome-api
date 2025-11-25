# frozen_string_literal: true

module DomeAPI
  class Market
    attr_reader :market_slug, :condition_id, :title, :description, :outcomes, 
                :start_time, :end_time, :volume, :liquidity, :tags, :status

    def initialize(attributes = {})
      @market_slug = attributes[:market_slug]
      @condition_id = attributes[:condition_id]
      @title = attributes[:title]
      @description = attributes[:description]
      @outcomes = (attributes[:outcomes] || []).map { |outcome_data| Outcome.new(outcome_data) }
      @start_time = attributes[:start_time]
      @end_time = attributes[:end_time]
      @volume = attributes[:volume]
      @liquidity = attributes[:liquidity]
      @tags = attributes[:tags] || []
      @status = attributes[:status]
    end

    def active?
      status == "ACTIVE"
    end

    def closed?
      status == "CLOSED"
    end

    def resolved?
      status == "RESOLVED"
    end

    def yes_outcome
      outcomes.find(&:yes?)
    end

    def no_outcome
      outcomes.find(&:no?)
    end

    def yes_token_id
      yes_outcome&.token_id
    end

    def no_token_id
      no_outcome&.token_id
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
      start_date.strftime("%Y-%m-%d %H:%M:%S UTC")
    end

    def formatted_end_date(format = :readable)
      return nil unless end_date
      end_date.strftime("%Y-%m-%d %H:%M:%S UTC")
    end

    def has_tag?(tag)
      tags.include?(tag)
    end

    def crypto_market?
      has_tag?("crypto") || has_tag?("bitcoin")
    end

    def politics_market?
      has_tag?("politics") || has_tag?("election")
    end

    def to_h
      {
        market_slug: @market_slug,
        condition_id: @condition_id,
        title: @title,
        description: @description,
        outcomes: outcomes.map(&:to_h),
        start_time: @start_time,
        end_time: @end_time,
        volume: @volume,
        liquidity: @liquidity,
        tags: @tags,
        status: @status
      }
    end

    def to_json(*args)
      to_h.to_json(*args)
    end
  end
end
