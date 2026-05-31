# frozen_string_literal: true

describe WPScan::DB::Themes do
  subject(:themes) { described_class }

  describe '#all_slugs' do
    its(:all_slugs) { should eql %w[no-vulns-popular vulnerable-not-popular dignitas-themes yaaburnee-themes] }
  end

  describe '#popular_slugs' do
    its(:popular_slugs) { should eql %w[no-vulns-popular dignitas-themes] }
  end

  # vulnerable_slugs is now sourced from the local Wordfence database
  # (spec/fixtures/wordfence_cache.json), not the metadata.json popularity DB.
  describe '#vulnerable_slugs' do
    its(:vulnerable_slugs) { should eql %w[dignitas-themes] }
  end
end
