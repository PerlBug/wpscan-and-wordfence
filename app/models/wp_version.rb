# frozen_string_literal: true

module WPScan
  module Model
    # WP Version
    class WpVersion < WPScan::Model::Version
      include Vulnerable

      def initialize(number, opts = {})
        raise Error::InvalidWordPressVersion unless WpVersion.valid?(number.to_s)

        super
      end

      # @param [ String ] number
      #
      # @return [ Boolean ] true if the number is a valid WP version, false otherwise
      def self.valid?(number)
        all.include?(number)
      end

      # @return [ Array<String> ] All the version numbers
      def self.all
        return @all_numbers if @all_numbers

        @all_numbers = []

        DB::Version.metadata.each_key do |ver|
          @all_numbers << ver
        end

        DB::Fingerprints.wp_fingerprints.each_value do |fp|
          @all_numbers << fp.values
        end

        # @all_numbers.flatten.uniq.sort! {} doesn't produce the same result here.
        @all_numbers.flatten!
        @all_numbers.uniq!
        @all_numbers.sort! { |a, b| Gem::Version.new(b) <=> Gem::Version.new(a) }
      end

      # Retrieve the metadata from the local detection database.
      # @return [ Hash ]
      def metadata
        @metadata ||= DB::Version.metadata_at(number)
      end

      # @return [ Array<Vulnerability> ]
      def vulnerabilities
        @vulnerabilities ||= DB::Wordfence.vulnerabilities(type: 'core', slug: 'wordpress', version: number)
      end

      # @return [ String ]
      def release_date
        @release_date ||= metadata['release_date'] || 'Unknown'
      end

      # @return [ String ]
      def status
        @status ||= metadata['status'] || 'Unknown'
      end
    end
  end
end
