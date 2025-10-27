# frozen_string_literal: true

module DomeAPI
  class ActivityResponse
    attr_reader :activities, :pagination

    def initialize(activities: [], pagination: {})
      @activities = activities.map { |activity_data| Order.new(activity_data) }
      @pagination = pagination
    end

    def total_activities
      pagination[:count] || 0
    end

    def limit
      pagination[:limit] || 0
    end

    def offset
      pagination[:offset] || 0
    end

    def has_more?
      pagination[:has_more] || false
    end

    def empty?
      activities.empty?
    end

    def size
      activities.size
    end

    def each(&block)
      activities.each(&block)
    end

    def [](index)
      activities[index]
    end

    def to_a
      activities
    end

    def to_h
      {
        activities: activities.map(&:to_h),
        pagination: pagination
      }
    end

    def to_json(*args)
      to_h.to_json(*args)
    end
  end
end
