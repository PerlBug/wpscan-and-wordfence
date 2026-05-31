# frozen_string_literal: true

module WPScan
  module Controller
    # Controller to set up the local Wordfence vulnerability database.
    class Wordfence < WPScan::Controller::Base
      ENV_KEY = 'WORDFENCE_CACHE_PATH'

      def cli_options
        [
          OptString.new(
            ['--wordfence-db PATH',
             'Path to the Wordfence Intelligence vulnerability JSON file used for vulnerability ' \
             "matching. Overrides the #{ENV_KEY} environment variable."]
          ),
          OptBoolean.new(
            ['--proxy-target-only',
             'When used with --proxy, the proxy is only applied to requests made to the target, ' \
             'not to requests made to the WPScan database repository (data.wpscan.org). ' \
             'Has no effect unless --proxy is also set.']
          )
        ]
      end

      def before_scan
        DB::Wordfence.path = ParsedCli.wordfence_db || ENV.fetch(ENV_KEY, nil)

        path = DB::Wordfence.path

        raise Error::MissingWordfenceDatabase, path if path.nil? || path.to_s.empty?
        raise Error::MissingWordfenceDatabase, path unless File.file?(path) && File.readable?(path)
      end
    end
  end
end
