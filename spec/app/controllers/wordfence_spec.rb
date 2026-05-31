# frozen_string_literal: true

describe WPScan::Controller::Wordfence do
  subject(:controller) { described_class.new }
  let(:target_url)     { 'http://ex.lo/' }
  let(:cli_args)       { "--url #{target_url}" }

  around do |example|
    original = ENV.fetch(described_class::ENV_KEY, nil)

    ENV.delete(described_class::ENV_KEY)
    example.run
  ensure
    original ? ENV[described_class::ENV_KEY] = original : ENV.delete(described_class::ENV_KEY)
  end

  before { WPScan::ParsedCli.options = rspec_parsed_options(cli_args) }

  describe '#cli_options' do
    its(:cli_options) { should_not be_empty }
    its(:cli_options) { should be_a Array }

    it 'contains the correct options' do
      expect(controller.cli_options.map(&:to_sym)).to eq %i[wordfence_db proxy_target_only]
    end
  end

  describe '#before_scan' do
    context 'when neither --wordfence-db nor the env var is set' do
      it 'raises a MissingWordfenceDatabase error' do
        expect { controller.before_scan }.to raise_error(WPScan::Error::MissingWordfenceDatabase)
      end
    end

    context 'when the path points to a missing file' do
      let(:cli_args) { "#{super()} --wordfence-db /does/not/exist.json" }

      it 'raises a MissingWordfenceDatabase error' do
        expect { controller.before_scan }.to raise_error(WPScan::Error::MissingWordfenceDatabase)
      end
    end

    context 'when --wordfence-db points to a readable file' do
      let(:cli_args) { "#{super()} --wordfence-db #{WORDFENCE_FIXTURE}" }

      it 'sets the path and does not raise' do
        expect { controller.before_scan }.to_not raise_error
        expect(WPScan::DB::Wordfence.path).to eql WORDFENCE_FIXTURE.to_s
      end
    end

    context 'when the path comes from the environment variable' do
      before { ENV[described_class::ENV_KEY] = WORDFENCE_FIXTURE.to_s }

      it 'sets the path from the env var and does not raise' do
        expect { controller.before_scan }.to_not raise_error
        expect(WPScan::DB::Wordfence.path).to eql WORDFENCE_FIXTURE.to_s
      end
    end

    context 'when both --wordfence-db and the env var are set' do
      let(:cli_args) { "#{super()} --wordfence-db #{WORDFENCE_FIXTURE}" }

      before { ENV[described_class::ENV_KEY] = '/some/other/path.json' }

      it 'gives precedence to the CLI option' do
        controller.before_scan

        expect(WPScan::DB::Wordfence.path).to eql WORDFENCE_FIXTURE.to_s
      end
    end
  end
end
