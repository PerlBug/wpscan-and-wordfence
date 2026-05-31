# frozen_string_literal: true

module WPScan
  module DB
    # WP Plugins
    class Plugins < WpItems
      # @return [ JSON ]
      def self.metadata
        Plugin.metadata
      end

      # @return [ Array<String> ] Slugs of all plugins with a known vulnerability,
      #   sourced from the local Wordfence database.
      def self.vulnerable_slugs
        Wordfence.slugs_for('plugin')
      end
    end
  end
end
