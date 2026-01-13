require 'spec_helper'
require 'datadog/ruby_core_source'

RSpec.describe Datadog::RubyCoreSource do
  describe '.deduce_packaged_source_dir' do
    before do
      stub_const('RUBY_VERSION', ruby_version)
    end

    context 'when a stable exact match exists' do
      let(:ruby_version) { '3.4.0' }
      let(:ruby_dir) { 'ruby-3.4.0-p0' }

      it 'returns the exact match directory' do
        result = described_class.deduce_packaged_source_dir(ruby_dir)
        expect(result).to end_with("/#{ruby_dir}")
        expect(File.directory?(result)).to be true
      end
    end

    context 'when a preview exact match exists' do
      let(:ruby_version) { '4.0.0' } # Important: "preview" label doesn't show up on RUBY_VERSION
      let(:ruby_dir) { 'ruby-4.0.0-preview2' }

      it 'returns the exact match directory' do
        result = described_class.deduce_packaged_source_dir(ruby_dir)
        expect(result).to end_with('/ruby-4.0.0-preview2')
        expect(File.directory?(result)).to be true
      end
    end

    context 'when exact match does not exist' do
      context 'with a patch version upgrade and there are no preview headers' do
        let(:ruby_version) { '3.4.1' }
        let(:ruby_dir) { 'ruby-3.4.1-p0' }

        it 'falls back to the closest older version' do
          expect(described_class).to receive(:fallback_source_warning).with(ruby_dir, 'ruby-3.4.0-p0')

          result = described_class.deduce_packaged_source_dir(ruby_dir)
          expect(result).to end_with('/ruby-3.4.0-p0')
          expect(File.directory?(result)).to be true
        end
      end

      context 'with a patch version upgrade and there are preview headers' do
        let(:ruby_version) { '4.0.1' }
        let(:ruby_dir) { 'ruby-4.0.1-p0' }

        it 'falls back to the closest older version' do
          expect(described_class).to receive(:fallback_source_warning).with(ruby_dir, 'ruby-4.0.0-p0')

          result = described_class.deduce_packaged_source_dir(ruby_dir)
          expect(result).to end_with('/ruby-4.0.0-p0')
          expect(File.directory?(result)).to be true
        end
      end

      context 'with a preview version' do
        let(:ruby_version) { '4.0.0' } # Important: "preview" label doesn't show up on RUBY_VERSION
        let(:ruby_dir) { 'ruby-4.0.0-preview3' }

        it 'falls back to the stable version' do
          expect(described_class).to receive(:fallback_source_warning).with(ruby_dir, 'ruby-4.0.0-p0')

          result = described_class.deduce_packaged_source_dir(ruby_dir)
          expect(result).to end_with('/ruby-4.0.0-p0')
          expect(File.directory?(result)).to be true
        end
      end
    end
  end

  describe '.ruby_source_dir_version' do
     it 'parses stable versions correctly' do
       expect(described_class.ruby_source_dir_version('ruby-2.7.0-p0')).to eq(Gem::Version.new('2.7.0'))
       expect(described_class.ruby_source_dir_version('ruby-3.4.1-p0')).to eq(Gem::Version.new('3.4.1'))
     end

     it 'parses preview/rc versions correctly' do
       expect(described_class.ruby_source_dir_version('ruby-3.4.0-preview1')).to eq(Gem::Version.new('3.4.0.preview1'))
       expect(described_class.ruby_source_dir_version('ruby-4.0.0-rc2')).to eq(Gem::Version.new('4.0.0.rc2'))
     end
  end
end
