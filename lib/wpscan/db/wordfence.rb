# frozen_string_literal: true

module WPScan
  module DB
    # Wordfence Intelligence vulnerability database (local JSON export).
    #
    # Replaces the former WPScan VulnDB API as the source of vulnerability data.
    # The path to the JSON file is provided via the --wordfence-db CLI option or
    # the WORDFENCE_CACHE_PATH environment variable (see Controller::Wordfence).
    #
    # The file is parsed once and trimmed into a compact in-memory index keyed by
    # software type and slug; the large raw parse result is then discarded so only
    # the trimmed index stays resident.
    class Wordfence
      # Wordfence software types handled by WPScan (plugins, themes and core).
      SOFTWARE_TYPES = %w[plugin theme core].freeze

      class << self
        # @return [ String, nil ] Path to the Wordfence JSON file
        attr_accessor :path
      end

      # @return [ Hash ] The lazily-built index:
      #   { 'plugin' => { slug => [entry, ...] },
      #     'theme'  => { slug => [entry, ...] },
      #     'core'   => [entry, ...] }
      #   where each entry is { 'record' => trimmed_record,
      #                         'affected_versions' => [range, ...],
      #                         'patched_versions'  => [String, ...] }
      def self.index
        @index ||= build_index
      end

      # Discards the cached index (mainly used by the test suite).
      def self.reset!
        @index = nil
      end

      # @return [ Hash ]
      def self.build_index
        raise Error::MissingWordfenceDatabase, path if path.nil? || path.to_s.empty?
        raise Error::MissingWordfenceDatabase, path unless File.file?(path) && File.readable?(path)

        records = JSON.parse(File.read(path))

        index = { 'plugin' => {}, 'theme' => {}, 'core' => [] }

        records.each_value { |record| index_record(index, record) }

        index
      rescue JSON::ParserError => e
        raise Error::InvalidWordfenceDatabase.new(path, e)
      end

      # Adds a single Wordfence record to the index (one entry per software item).
      #
      # @param [ Hash ] index
      # @param [ Hash ] record
      def self.index_record(index, record)
        trimmed_record = trim_record(record)

        Array(record['software']).each do |software|
          type = software['type']
          next unless SOFTWARE_TYPES.include?(type)

          entry = {
            'record' => trimmed_record,
            'affected_versions' => Array(software['affected_versions']&.values),
            'patched_versions' => Array(software['patched_versions'])
          }

          if type == 'core'
            index['core'] << entry
          else
            (index[type][software['slug']] ||= []) << entry
          end
        end
      end

      # Keeps only the record fields needed to build a Vulnerability, dropping the
      # bulky description/copyright/cwe data to limit resident memory.
      #
      # @param [ Hash ] record
      # @return [ Hash ]
      def self.trim_record(record)
        {
          'id' => record['id'],
          'title' => record['title'],
          'references' => record['references'],
          'cve' => record['cve'],
          'cvss' => record['cvss']
        }
      end

      # Vulnerabilities affecting the given item at the given version.
      #
      # When +version+ is nil (unknown), every vulnerability known for the slug is
      # returned (matching the legacy behaviour of the WPScan API path).
      #
      # @param [ String ] type 'plugin', 'theme' or 'core'
      # @param [ String ] slug The item slug ('wordpress' for core)
      # @param [ String, nil ] version The detected version
      #
      # @return [ Array<WPScan::Vulnerability> ]
      def self.vulnerabilities(type:, slug:, version: nil)
        entries = type == 'core' ? index['core'] : index.dig(type, slug)
        return [] if entries.nil? || entries.empty?

        gem_version = parse_version(version)
        seen        = {}
        vulns       = []

        entries.each do |entry|
          ranges  = entry['affected_versions']
          matched = gem_version.nil? ? ranges.first : ranges.find { |r| version_in_range?(gem_version, r) }

          next if !gem_version.nil? && matched.nil?

          uuid = entry['record']['id']
          next if seen[uuid]

          seen[uuid] = true
          vulns << build_vulnerability(entry, matched)
        end

        vulns
      end

      # All slugs of a given type present in the database.
      #
      # @param [ String ] type 'plugin' or 'theme'
      #
      # @return [ Array<String> ]
      def self.slugs_for(type)
        (index[type] || {}).keys
      end

      # @param [ Hash ] entry An index entry
      # @param [ Hash, nil ] range The affected_versions range that matched
      #
      # @return [ WPScan::Vulnerability ]
      def self.build_vulnerability(entry, range)
        Vulnerability.load_from_wordfence(
          entry['record'],
          introduced_in: introduced_in_for(range),
          fixed_in: fixed_in_for(range, entry['patched_versions'])
        )
      end

      # @param [ Hash, nil ] range
      #
      # @return [ String, nil ]
      def self.introduced_in_for(range)
        return nil unless range

        from = range['from_version']
        from && from != '*' ? from : nil
      end

      # Best-effort single "fixed in" version for display.
      #
      # @param [ Hash, nil ] range
      # @param [ Array<String> ] patched_versions
      #
      # @return [ String, nil ]
      def self.fixed_in_for(range, patched_versions)
        patched = Array(patched_versions)
        to      = upper_bound(range)

        # Exclusive upper bound: that version is already the first non-vulnerable one.
        return to if to && range['to_inclusive'] == false

        fix_after(to, patched) || lowest_version(patched)
      end

      # @param [ Hash, nil ] range
      #
      # @return [ String, nil ] The range's upper bound, or nil when unbounded ('*')
      def self.upper_bound(range)
        to = range && range['to_version']
        to == '*' ? nil : to
      end

      # @param [ String, nil ] to The (inclusive) upper bound of the affected range
      # @param [ Array<String> ] patched The known patched versions
      #
      # @return [ String, nil ] The lowest patched version strictly greater than +to+
      def self.fix_after(to, patched)
        to_v = parse_version(to)
        return nil unless to_v

        lowest_version(patched.select { |p| (pv = parse_version(p)) && pv > to_v })
      end

      # @param [ Array<String> ] numbers
      #
      # @return [ String, nil ] The lowest parseable version string in the list
      def self.lowest_version(numbers)
        numbers.map { |n| [n, parse_version(n)] }
               .select { |(_, v)| v }
               .min_by { |(_, v)| v }
               &.first
      end

      # @param [ Gem::Version ] version The detected version
      # @param [ Hash ] range A Wordfence affected_versions range
      #
      # @return [ Boolean ]
      def self.version_in_range?(version, range)
        lower_bound_ok?(version, range) && upper_bound_ok?(version, range)
      end

      # @return [ Boolean ] true when +version+ satisfies the range's lower bound
      def self.lower_bound_ok?(version, range)
        from = range['from_version']
        return true if from.nil? || from == '*'

        from_v = parse_version(from)
        return true unless from_v

        range['from_inclusive'] ? version >= from_v : version > from_v
      end

      # @return [ Boolean ] true when +version+ satisfies the range's upper bound
      def self.upper_bound_ok?(version, range)
        to = range['to_version']
        return true if to.nil? || to == '*'

        to_v = parse_version(to)
        return true unless to_v

        range['to_inclusive'] ? version <= to_v : version < to_v
      end

      # @param [ String, nil ] number
      #
      # @return [ Gem::Version, nil ] nil when the number is blank or unparseable
      def self.parse_version(number)
        return nil if number.nil? || number.to_s.strip.empty?

        Gem::Version.new(number.to_s)
      rescue ArgumentError
        nil
      end
    end
  end
end
