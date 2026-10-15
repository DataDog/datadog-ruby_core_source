require 'tmpdir'
require 'open-uri'
require 'archive/tar/minitar'
require 'zlib'
require 'fileutils'
require 'set'
require 'bundler'
Bundler::GemHelper.install_tasks

SOURCES_DIR = File.expand_path("lib/datadog/ruby_core_source", __dir__)

def get_dest_dir(ruby_dir, version, tempdir, patchlevel)
  dest_dir = "#{SOURCES_DIR}/#{ruby_dir}"
  return dest_dir if version.include?('-p')

  if !patchlevel
    puts "extracting patchlevel from version.h"
    patchlevel = File.new("#{tempdir}/#{ruby_dir}/version.h").each_line.map do |li|
      if /#define RUBY_PATCHLEVEL (-?\d+)/ =~ li
        break $1
      else
        nil
      end
    end#.find { |p| not p.nil?}

    # The Ruby 3.4.0 release has RUBY_PATCHLEVEL -1 but that's a bug, correct it
    patchlevel = '0' if version == '3.4.0'
    puts "extracted patchlevel '#{patchlevel}'"
  end
  if patchlevel
    dest_dir = dest_dir + "-p" + patchlevel unless patchlevel == '-1'
  else
    warn "Unable to extract patchlevel from verion.h assuming there is no patchlevel please use a $PATCHLEVEL to specify one"
  end
  dest_dir
end

# Finds the already-imported headers directory for a given version, e.g. "3.3.5" => ".../ruby-3.3.5-p100".
# The patchlevel does not need to be given, as it is fixed for a given version.
def find_dest_dir(version)
  dirs = Dir.glob("#{SOURCES_DIR}/ruby-#{version}{,-p*}")
  abort "Could not find the headers of ruby-#{version} under #{SOURCES_DIR}" if dirs.empty?
  abort "Multiple directories match ruby-#{version}: #{dirs.join(', ')}" if dirs.size > 1
  dirs.first
end

desc <<DESCR
Add ruby headers under lib for a given VERSION and (optional) PATCHLEVEL,
\t\t\tif patchlevel is not provided it will be extracted from version.h.
\t\t\tTGZ_FILE_NAME can be used to provide pre-downloaded tgz file
DESCR
task :add_source, [:version] do |_task, args|
  version = args[:version] || ENV['VERSION'] or abort "Need a $VERSION"
  patchlevel = ENV['PATCHLEVEL']
  ruby_dir = ENV['RUBY_DIR_OVERRIDE'] || "ruby-#{version}"

  if ENV['TGZ_FILE_NAME']
    temp = ENV['TGZ_FILE_NAME']
    puts "Using pre-downloaded bundle #{temp}"
    puts "Unpacking #{temp}..."
  else
    minor_version = version.split('.')[0..1].join('.')
    uri_path = "http://ftp.ruby-lang.org/pub/ruby/#{minor_version}/#{ruby_dir}.tar.gz"
    puts "Downloading #{uri_path}..."
    temp = URI.open(uri_path)
    puts "Unpacking #{uri_path}..."
  end
  tgz = Zlib::GzipReader.new(File.open(temp, "rb"))

  Dir.mktmpdir do |dir|
    inc_dir = dir + "/" + ruby_dir + "/*.inc"
    hdr_dir = dir + "/" + ruby_dir + "/*.h"
    more_hdr_dir = [
      dir + "/" + ruby_dir + "/ccan/**/*.h",
      dir + "/" + ruby_dir + "/internal/**/*.h",
      dir + "/" + ruby_dir + "/prism/**/*.h"
    ]
    Archive::Tar::Minitar.unpack(tgz, dir)

    dest_dir = get_dest_dir(ruby_dir, version, dir, patchlevel)
    puts dest_dir
    FileUtils.mkdir_p(dest_dir)
    Dir.glob([ inc_dir, hdr_dir, more_hdr_dir ].flatten).each do |file|
      target = file.sub(dir + '/' + ruby_dir, dest_dir)
      FileUtils.mkdir_p(File.dirname(target))
      FileUtils.cp(file, target, verbose: false)
    end
  end
end

# @ivoanjo: I've used ChatGPT to generate this quick-and-dirty tool.
# This was added in https://github.com/DataDog/datadog-ruby_core_source/pull/5 . The intent of the `trim` task below
# is to do the following: Starting from the internal VM headers used by the profiler in dd-trace-rb, identify which
# other headers are needed by those headers, and keep those, but delete everything else.
#
# To invoke it:
#
# $ bundle exec rake trim[3.4.0]
#
# And the headers that are not needed by the datadog gem get deleted (VERBOSE=true shows how they were found).
# Always remember to validate the result (see below).
#
# This makes this gem very tailored to the needs of dd-trace-rb. In the future this may change.
# This is purely a size-based optimization; we delete any file that the profiler doesn't need right now; it's OK to
# skip using this task and ship the full set of headers (they're just not needed).
#
# ---
#
# 1. What internal VM headers should you start from?
# Currently this should be started from the headers in ENTRY_HEADERS below. These headers are the ones included in
# https://github.com/DataDog/dd-trace-rb/blob/master/ext/datadog_profiling_native_extension/private_vm_api_access.c .
# By design, this is the only file in the dd-trace-rb codebase that includes internal VM headers and thus needs to be
# checked.
# Auto-detection doesn't work for `thread_pthread.h thread_none.h` so those should be included as well.
#
# 2. What's up with the warning about `thread_pthread.h` above? In modern Rubies, that header gets included via
# `#include THREAD_IMPL_H`, with this `THREAD_IMPL_H` being provided by the auto-generated "ruby/config.h" file.
# Thus, this detection fails for this file.
#
# 3. How to validate that there are no missing headers? To validate a set of headers is enough, build dd-trace-rb
# with those headers on linux/docker (`bundle exec rake clean compile`). If it passes, it's enough!
# (If you delete `thread_pthread.h` you'll get a compilation error)
#
# 4. How to apply this optimization to new sets of headers in the future:
#   a. Import the new set of headers (`rake add_source`)
#   b. Run `rake trim` on the specific version being imported (each one, if multiple)
#   c. Check that the profiler still builds on those Ruby versions (using CI, or locally in docker)
#   d. If any issues arise, leave all the headers in place! We can perform this optimization as a separate step
module FindIncludes
  # The internal VM headers used by dd-trace-rb, see point 1. above
  ENTRY_HEADERS = %w[vm_core.h iseq.h internal/class.h ractor_core.h thread_pthread.h thread_none.h zjit.h]

  KNOWN_MISSING = %w[
    ruby/internal/config.h
    wasm/setjmp.h
    prism_xallocator.h
    missing/stdbool.h
  ].to_set

  module_function

  # Function to extract included headers from a file
  def extract_includes(file_path)
    includes = []

    File.foreach(file_path) do |line|
      # Regex to match `#include "header.h"`.
      # `#include <ruby/header.h>` or `#include <stddef.h>` are public headers, so we don't match them.
      if line =~ /^ \s* \# \s* include \s+ "([^"]+)"/x
        include = $1
        unless include.start_with?("ruby/") or include == "ruby.h" # skip public headers
          includes << include
        end
      end
    end
    includes
  rescue Errno::ENOENT
    # Ignore if the file is missing
    abort "Warning: Could not open file #{file_path}.\nAdd it to KNOWN_MISSING after checking it does indeed not exist (e.g. generated)"
    []
  end

  # Recursively find all includes
  def find_includes(file_path, visited, all_includes, verbose)
    return if visited.include?(file_path)

    visited.add(file_path)
    return if KNOWN_MISSING.include?(file_path)

    puts "Processing: #{file_path}" if verbose

    includes = extract_includes(file_path)
    includes.each do |include|
      puts "  Included: #{include}" if verbose
      # Add to the global set of all included files
      all_includes.add(include)

      # includes are simply resolved from the top-level source directory
      resolved_include = include
      find_includes(resolved_include, visited, all_includes, verbose)
    end
  end

  # Returns the files in the current directory which are not included by any of the input files.
  # Includes are resolved from the current directory, so this must be called from the headers directory.
  def unincluded_files(input_files, verbose: false)
    all_includes = Set.new
    visited = Set.new

    # Process each provided header file
    input_files.each do |header_file|
      if File.exist?(header_file)
        find_includes(header_file, visited, all_includes, verbose)
      else
        warn "WARNING: input file #{header_file} does not exist on this version"
      end
    end

    Dir.glob("**/*.*") - input_files - all_includes.to_a
  end
end

desc <<DESCR
Remove the headers which dd-trace-rb does not need for a given VERSION,
\t\t\tsee the comments above the FindIncludes module in the Rakefile.
\t\t\tVERBOSE=true shows how the needed headers are found.
DESCR
task :trim, [:version] do |_task, args|
  version = args[:version] || ENV['VERSION'] or abort "Need a $VERSION"
  dest_dir = find_dest_dir(version)

  # iseq.h includes prism_compile.h, but the headers we keep only use the prism types as pointers,
  # and prism_compile.h is the only reason the prism/ headers (about half of the shipped bytes) are
  # kept. So empty it to make the gem smaller, which matters for SSI.
  # The file itself is kept, so that `#include "prism_compile.h"` in iseq.h still resolves, and it
  # declares the prism types used by iseq.h as opaque types.
  # The prism/ headers are then no longer included by anything and are removed below.
  prism_compile_h = "#{dest_dir}/prism_compile.h"
  if File.exist?(prism_compile_h)
    puts "Emptying prism_compile.h so that the prism/ headers are not needed"
    contents = +<<~HEADER
      /* The contents of this header were removed by the datadog-ruby_core_source gem:
       * they are not needed by the headers used in dd-trace-rb, and keeping them would mean
       * also shipping all the prism/ headers, which this gem does not ship.
       * This file is kept because iseq.h includes it. */
    HEADER
    # Only Ruby 3.3's iseq.h still uses prism types, for
    #   rb_iseq_t * rb_iseq_new_main_prism(pm_string_t *input, pm_options_t *options, VALUE path);
    if version.start_with?('3.3.')
      contents << <<~HEADER

        /* These types are used by iseq.h on Ruby 3.3, they are declared as opaque types
         * since they are only used as pointers. */
        typedef struct pm_string pm_string_t;
        typedef struct pm_options pm_options_t;
      HEADER
    end
    File.write(prism_compile_h, contents)
  end

  unincluded_files = Dir.chdir(dest_dir) do
    FindIncludes.unincluded_files(FindIncludes::ENTRY_HEADERS, verbose: ENV['VERBOSE'] == 'true')
  end
  puts "Removing #{unincluded_files.size} headers which are not needed: #{unincluded_files.join(" ")}"

  unincluded_files.each { |file| File.delete("#{dest_dir}/#{file}") }
  # Remove the directories which became empty, e.g. prism/
  Dir.glob("#{dest_dir}/**/*").select { |path| File.directory?(path) }.sort.reverse_each do |path|
    Dir.rmdir(path) if Dir.empty?(path)
  end
end

desc <<DESCR
Re-download and trim the headers of every ruby version already present under lib,
\t\t\tthat is run add_source + trim for each of them.
DESCR
task :redownload_all_sources do
  dirs = Dir.glob("#{SOURCES_DIR}/ruby-*").select { |dir| File.directory?(dir) }.sort
  abort "No ruby versions found under #{SOURCES_DIR}" if dirs.empty?

  dirs.each do |dir|
    # The patchlevel is not part of the version, e.g. "ruby-3.3.5-p100" => "3.3.5",
    # but "ruby-4.1.0-preview1" => "4.1.0-preview1"
    dir_name = File.basename(dir)
    version = dir_name.delete_prefix('ruby-').sub(/-p\d+\z/, '')

    puts "\n=== Re-downloading #{dir_name} ==="
    [ :add_source, :trim ].each do |task_name|
      task = Rake::Task[task_name]
      task.reenable
      task.invoke(version)
    end
  end
end
