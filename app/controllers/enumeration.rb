# frozen_string_literal: true

require_relative 'enumeration/cli_options'
require_relative 'enumeration/enum_methods'

module WPScan
  module Controller
    # Enumeration Controller
    class Enumeration < WPScan::Controller::Base
      # Plugin/theme enumeration choices skipped when --wp-auth is supplied
      # (authoritative inventory already fetched by AuthenticatedInventory).
      WP_AUTH_SUPPRESSED_CHOICES = %i[
        vulnerable_plugins all_plugins popular_plugins
        vulnerable_themes all_themes popular_themes
      ].freeze

      def run
        enum = ParsedCli.enumerate || {}

        resolve_list_enumerate_collisions(enum)
        suppress_plugin_theme_choices_when_authenticated(enum)

        enum_plugins if enum_plugins?(enum)
        enum_themes  if enum_themes?(enum)

        %i[timthumbs config_backups db_exports backup_folders medias].each do |key|
          send(:"enum_#{key}") if enum.key?(key)
        end

        enum_users if enum_users?(enum)
      end
    end
  end
end
