# frozen_string_literal: true

module WPScan
  module Error
    # Error raised when the Wordfence vulnerability database has not been provided.
    class MissingWordfenceDatabase < Standard
      # @param [ String, nil ] path The configured path (if any)
      def initialize(path = nil)
        @path = path
        super()
      end

      def to_s
        location = @path.nil? || @path.to_s.empty? ? 'was not provided' : "could not be read at '#{@path}'"

        "The Wordfence vulnerability database #{location}. " \
          'Provide it via --wordfence-db PATH or the WORDFENCE_CACHE_PATH environment variable.'
      end
    end

    # Error raised when the Wordfence vulnerability database cannot be parsed as JSON.
    class InvalidWordfenceDatabase < Standard
      attr_reader :original_error

      # @param [ String ] path
      # @param [ StandardError ] original_error
      def initialize(path, original_error)
        @path           = path
        @original_error = original_error
        super()
      end

      def to_s
        "The Wordfence vulnerability database at '#{@path}' is not valid JSON: #{@original_error}"
      end
    end
  end
end
