# frozen_string_literal: true

describe WPScan::Model::Plugin do
  subject(:plugin) { described_class.new(slug, blog, opts) }
  let(:slug)       { 'spec' }
  let(:blog)       { WPScan::Target.new('http://wp.lab/') }
  let(:opts)       { {} }

  before { expect(blog).to receive(:content_dir).and_return('wp-content') }

  describe '#new' do
    its(:url) { should eql 'http://wp.lab/wp-content/plugins/spec/' }
  end

  describe '#version' do
    after do
      expect(WPScan::Finders::PluginVersion::Base).to receive(:find).with(plugin, @expected_opts)

      plugin.version(version_opts)
    end

    let(:default_opts) { {} }

    context 'when no :detection_mode' do
      context 'when no :mode opt supplied' do
        let(:version_opts) { { something: 'k' } }

        it 'calls the finder with the correct parameters' do
          @expected_opts = version_opts
        end
      end

      context 'when :mode supplied' do
        let(:version_opts) { { mode: :passive } }

        it 'calls the finder with the correct parameters' do
          @expected_opts = default_opts.merge(mode: :passive)
        end
      end
    end

    context 'when :detection_mode' do
      let(:opts) { super().merge(mode: :passive) }

      context 'when no :mode' do
        let(:version_opts) { {} }

        it 'calls the finder without mode' do
          @expected_opts = version_opts
        end
      end

      context 'when :mode' do
        let(:version_opts) { { mode: :mixed } }

        it 'calls the finder with the :mixed mode' do
          @expected_opts = default_opts.merge(mode: :mixed)
        end
      end
    end
  end

  describe '#wordpress_org_api_url' do
    its(:wordpress_org_api_url) do
      should eql 'https://api.wordpress.org/plugins/info/1.2/?action=plugin_information&request[slug]=spec'
    end
  end

  describe 'potential_readme_filenames' do
    context 'when not set in the DF file' do
      its(:potential_readme_filenames) { should eql described_class::READMES }
    end

    context 'when set in the DF file' do
      context 'as a string' do
        let(:slug) { 'photoblocks-grid-gallery' }

        its(:potential_readme_filenames) { should eql %w[README.txt] }
      end

      context 'as an array' do
        let(:slug) { 'customerlabs-actionrecorder' }

        its(:potential_readme_filenames) { should eql %w[Readme.txt Readme.md] }
      end
    end
  end

  describe '#latest_version, #last_updated, #popular' do
    before { allow(plugin).to receive(:wordpress_org_data).and_return({}) }

    context 'when no metadata' do
      let(:slug) { 'not-known' }

      its(:latest_version) { should be_nil }
      its(:last_updated) { should be_nil }
      its(:popular?) { should be false }
    end

    context 'when metadata' do
      let(:slug) { 'no-vulns-popular' }

      its(:latest_version) { should eql WPScan::Model::Version.new('2.0') }
      its(:last_updated) { should eql '2015-05-16T00:00:00.000Z' }
      its(:popular?) { should be true }
    end
  end

  describe '#outdated?' do
    context 'when last_version' do
      let(:slug) { 'no-vulns-popular' }

      context 'when no version' do
        before { expect(plugin).to receive(:version).at_least(1).and_return(nil) }

        its(:outdated?) { should eql false }
      end

      context 'when version' do
        before do
          expect(plugin)
            .to receive(:version)
            .at_least(1)
            .and_return(WPScan::Model::Version.new(version_number))
        end

        context 'when version < latest_version' do
          let(:version_number) { '1.2' }

          its(:outdated?) { should eql true }
        end

        context 'when version >= latest_version' do
          let(:version_number) { '3.0' }

          its(:outdated?) { should eql false }
        end
      end
    end

    context 'when no latest_version' do
      let(:slug) { 'vulnerable-not-popular' }

      context 'when no version' do
        before { expect(plugin).to receive(:version).at_least(1).and_return(nil) }

        its(:outdated?) { should eql false }
      end

      context 'when version' do
        before do
          expect(plugin)
            .to receive(:version)
            .at_least(1)
            .and_return(WPScan::Model::Version.new('1.0'))
        end

        its(:outdated?) { should eql false }
      end
    end
  end

  # The version-range matching logic now lives in WPScan::DB::Wordfence
  # (see spec/lib/db/wordfence_spec.rb); the model simply delegates to it.
  describe '#vulnerabilities' do
    let(:vulns) { [WPScan::Vulnerability.new('Some Plugin Vuln', uuid: 'x')] }

    before { allow(plugin).to receive(:version).and_return(version) }

    context 'when the plugin has a detected version' do
      let(:version) { WPScan::Model::Version.new('1.2') }

      it 'queries the Wordfence DB with that version and returns the result' do
        expect(WPScan::DB::Wordfence).to receive(:vulnerabilities)
          .with(type: 'plugin', slug: slug, version: '1.2').and_return(vulns)

        expect(plugin.vulnerabilities).to eq vulns
        expect(plugin).to be_vulnerable
      end
    end

    context 'when the plugin version is unknown' do
      let(:version) { false }

      it 'queries the Wordfence DB with a nil version' do
        expect(WPScan::DB::Wordfence).to receive(:vulnerabilities)
          .with(type: 'plugin', slug: slug, version: nil).and_return([])

        expect(plugin.vulnerabilities).to eq []
        expect(plugin).to_not be_vulnerable
      end
    end
  end
end
