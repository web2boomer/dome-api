# frozen_string_literal: true

module DomeAPI
  class Outcome
    attr_reader :outcome, :token_id

    def initialize(attributes = {})
      @outcome = attributes[:outcome]
      @token_id = attributes[:token_id]
    end

    def yes?
      outcome == "Yes"
    end

    def no?
      outcome == "No"
    end

    def to_h
      {
        outcome: @outcome,
        token_id: @token_id
      }
    end

    def to_json(*args)
      to_h.to_json(*args)
    end
  end
end
