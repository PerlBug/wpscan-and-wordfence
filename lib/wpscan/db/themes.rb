# frozen_string_literal: true

module WPScan
  module DB
    # WP Themes
    class Themes < WpItems
      # @return [ JSON ]
      def self.metadata
        Theme.metadata
      end

      # @return [ Array<String> ] Slugs of all themes with a known vulnerability,
      #   sourced from the local Wordfence database.
      def self.vulnerable_slugs
        Wordfence.slugs_for('theme')
      end
    end
  end
end
