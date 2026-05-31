# frozen_string_literal: true

require 'tempfile'

describe WPScan::DB::Wordfence do
  subject(:db) { described_class }

  let(:fixture_path) { WORDFENCE_FIXTURE.to_s }

  before do
    db.reset!
    db.path = fixture_path
  end

  def gem_v(number)
    Gem::Version.new(number)
  end

  describe '.index' do
    it 'parses the file and indexes by type and slug' do
      expect(db.index['theme']).to have_key('dignitas-themes')
      expect(db.index['plugin']).to have_key('vulnerable-not-popular')
      expect(db.index['core']).to be_a(Array)
    end

    context 'when the path is nil' do
      let(:fixture_path) { nil }

      it 'raises MissingWordfenceDatabase' do
        expect { db.index }.to raise_error(WPScan::Error::MissingWordfenceDatabase)
      end
    end

    context 'when the file does not exist' do
      let(:fixture_path) { '/no/such/file.json' }

      it 'raises MissingWordfenceDatabase' do
        expect { db.index }.to raise_error(WPScan::Error::MissingWordfenceDatabase)
      end
    end

    context 'when the file is not valid JSON' do
      let(:fixture_path) do
        file = Tempfile.new(['wf', '.json'])
        file.write('{ not valid json')
        file.close
        file.path
      end

      it 'raises InvalidWordfenceDatabase' do
        expect { db.index }.to raise_error(WPScan::Error::InvalidWordfenceDatabase)
      end
    end
  end

  describe '.version_in_range?' do
    it 'respects inclusive upper bounds' do
      range = { 'from_version' => '*', 'from_inclusive' => true, 'to_version' => '1.37', 'to_inclusive' => true }

      expect(db.version_in_range?(gem_v('1.37'), range)).to be true
      expect(db.version_in_range?(gem_v('1.38'), range)).to be false
    end

    it 'respects exclusive upper bounds' do
      range = { 'from_version' => '*', 'from_inclusive' => true, 'to_version' => '1.37', 'to_inclusive' => false }

      expect(db.version_in_range?(gem_v('1.37'), range)).to be false
      expect(db.version_in_range?(gem_v('1.36'), range)).to be true
    end

    it 'respects lower bounds' do
      range = { 'from_version' => '1.5', 'from_inclusive' => true, 'to_version' => '2.0', 'to_inclusive' => true }

      expect(db.version_in_range?(gem_v('1.4'), range)).to be false
      expect(db.version_in_range?(gem_v('1.5'), range)).to be true
    end

    it 'treats * bounds as unbounded' do
      range = { 'from_version' => '*', 'from_inclusive' => true, 'to_version' => '*', 'to_inclusive' => true }

      expect(db.version_in_range?(gem_v('99.0'), range)).to be true
    end
  end

  describe '.vulnerabilities' do
    context 'for a plugin' do
      it 'returns the vuln for an affected version' do
        vulns = db.vulnerabilities(type: 'plugin', slug: 'vulnerable-not-popular', version: '1.0')

        expect(vulns.size).to eq 1
        expect(vulns.first).to be_a WPScan::Vulnerability
        expect(vulns.first.uuid).to eq 'e099c1da-3750-4e63-8af9-929e773bbe59'
        expect(vulns.first.fixed_in).to eq '6.3.10'
      end

      it 'returns nothing for a patched version' do
        expect(db.vulnerabilities(type: 'plugin', slug: 'vulnerable-not-popular', version: '6.3.10')).to be_empty
      end

      it 'returns all vulns when the version is unknown' do
        expect(db.vulnerabilities(type: 'plugin', slug: 'vulnerable-not-popular', version: nil).size).to eq 1
      end

      it 'returns an empty array for an unknown slug' do
        expect(db.vulnerabilities(type: 'plugin', slug: 'not-in-db', version: '1.0')).to eq []
      end
    end

    context 'for core' do
      it 'returns vulns affecting the version' do
        expect(db.vulnerabilities(type: 'core', slug: 'wordpress', version: '3.8.1').size).to eq 2
      end

      it 'returns nothing for an unaffected version' do
        expect(db.vulnerabilities(type: 'core', slug: 'wordpress', version: '4.0')).to be_empty
      end
    end

    it 'maps references and cvss (cve stripped, url kept, no synthesized wpvulndb link)' do
      vuln = db.vulnerabilities(type: 'theme', slug: 'dignitas-themes', version: nil).first

      expect(vuln.references[:cve]).to eq %w[2021-0001]
      expect(vuln.references[:url])
        .to include 'https://www.wordfence.com/threat-intel/vulnerabilities/id/b099c1da-3750-4e63-8af9-929e773bbe62'
      expect(vuln.references).to_not have_key(:wpvulndb)
      expect(vuln.cvss).to eq(score: '7.5', vector: 'CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:N/A:N')
    end
  end

  describe '.slugs_for' do
    it 'returns the slugs present for a type' do
      expect(db.slugs_for('plugin')).to include 'vulnerable-not-popular'
      expect(db.slugs_for('theme')).to include 'dignitas-themes'
    end
  end
end
