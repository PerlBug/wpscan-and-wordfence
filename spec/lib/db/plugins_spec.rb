# frozen_string_literal: true

describe WPScan::DB::Plugins do
  subject(:plugins) { described_class }

  describe '#all_slugs' do
    its(:all_slugs) { should eql %w[no-vulns-popular vulnerable-not-popular] }
  end

  describe '#popular_slugs' do
    its(:popular_slugs) { should eql %w[no-vulns-popular] }
  end

  # vulnerable_slugs is now sourced from the local Wordfence database
  # (spec/fixtures/wordfence_cache.json), not the metadata.json popularity DB.
  describe '#vulnerable_slugs' do
    its(:vulnerable_slugs) { should eql %w[vulnerable-not-popular] }
  end
end
