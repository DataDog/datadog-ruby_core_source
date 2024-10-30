require 'mkmf'
require 'fileutils'

$LOAD_PATH.push(__dir__ + '/../../lib')

require 'datadog/ruby_core_source'

dir = Datadog::RubyCoreSource.deduce_packaged_source_dir("ruby-#{RUBY_VERSION}-p#{RUBY_PATCHLEVEL}")

unused = Dir.glob(File.dirname(dir) + '/*') - [dir]

unused.each do |path|
  FileUtils.rm_rf path
end

create_makefile 'shave'
