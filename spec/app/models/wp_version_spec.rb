# frozen_string_literal: true

describe WPScan::Model::WpVersion do
  describe '#new' do
    context 'when invalid number' do
      it 'raises an error' do
        expect { described_class.new('aa') }.to raise_error WPScan::Error::InvalidWordPressVersion
      end
    end

    context 'when valid number' do
      it 'create the instance' do
        version = described_class.new(4.0)

        expect(version).to be_a described_class
        expect(version.number).to eql '4.0'
      end
    end
  end

  describe '.all' do
    it 'returns the correct values' do
      expect(described_class.all).to eql %w[4.4 4.0 3.9.1 3.8.2 3.8.1 3.8]
    end
  end

  describe '.valid?' do
    after { expect(described_class.valid?(@number)).to eq @expected }

    it 'returns false' do
      @number   = 'aaa'
      @expected = false
    end

    it 'returns true' do
      @number   = '4.0'
      @expected = true
    end
  end

  # Core vulnerability matching now lives in WPScan::DB::Wordfence
  # (see spec/lib/db/wordfence_spec.rb); WpVersion simply delegates to it.
  describe '#vulnerabilities' do
    subject(:version) { described_class.new(number) }

    let(:number) { '3.8.1' }
    let(:vulns)  { [WPScan::Vulnerability.new('Core Vuln', uuid: 'x')] }

    it 'queries the Wordfence DB for core with the version number' do
      expect(WPScan::DB::Wordfence).to receive(:vulnerabilities)
        .with(type: 'core', slug: 'wordpress', version: number).and_return(vulns)

      expect(version.vulnerabilities).to eq vulns
      expect(version).to be_vulnerable
    end

    context 'when there are no vulnerabilities' do
      it 'is not vulnerable' do
        expect(WPScan::DB::Wordfence).to receive(:vulnerabilities)
          .with(type: 'core', slug: 'wordpress', version: number).and_return([])

        expect(version.vulnerabilities).to eq []
        expect(version).to_not be_vulnerable
      end
    end
  end

  describe '#metadata, #release_date, #status' do
    subject(:version) { described_class.new('3.8.1') }

    its(:release_date) { should eql '2014-01-23' }
    its(:status) { should eql 'outdated' }

    context 'when the version is not in the metadata' do
      subject(:version) { described_class.new('3.8.2') }

      its(:release_date) { should eql 'Unknown' }
      its(:status) { should eql 'Unknown' }
    end
  end
end
