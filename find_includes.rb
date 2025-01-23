#!/usr/bin/env ruby

# @ivoanjo: I've used ChatGPT to generate this quick-and-dirty tool.
# This was added in https://github.com/DataDog/datadog-ruby_core_source/pull/5 . The intent of this script is to do
# the following: Starting from the internal VM headers used by the profiler in dd-trace-rb, identify which other
# headers are needed by those headers, and keep those, but delete everything else.
#
# To invoke it:
# `find_includes.rb vm_core.h iseq.h ractor_core.h` we get a rough list of headers that are not needed by the
# datadog gem. Always remember to validate the result -- this tool isn't perfect (for instance it doesn't detect that
# thread_pthread.h is in use).
#
# This makes this gem very tailored to the needs of dd-trace-rb. In the future this may change.
# This is purely a size-based optimization; we delete any file that the profiler doesn't need right now; it's OK to
# skip using this tool and ship the full set of headers (they're just not needed).
#
# ---
#
# 1. What internal VM headers should you start from?
# Currently this script should be used as `find_includes.rb vm_core.h iseq.h ractor_core.h`. These headers are the
# ones included in
# https://github.com/DataDog/dd-trace-rb/blob/master/ext/datadog_profiling_native_extension/private_vm_api_access.c .
# By design, this is the only file in the dd-trace-rb codebase that includes internal VM headers and thus needs to be
# checked.
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
#   a. Import the new set of headers
#   b. Run `find_includes.rb` on the specific headers folder being imported (each one, if multiple)
#   c. Delete the resulting files (but leave `thread_pthread.h`)
#   d. Check that the profiler still builds on those Ruby versions (using CI, or locally in docker)
#   e. If any issues arise, leave all the headers in place! We can perform this optimization as a separate step

require 'set'

# Function to extract included headers from a file
def extract_includes(file_path)
  includes = []

  File.foreach(file_path) do |line|
    # Regex to match #include "header.h" or #include <header.h>
    if line =~ /^\s*#\s*include\s+["<](.*?)[">]/
      includes << $1
    end
  end
  includes
rescue Errno::ENOENT
  # Ignore if the file is missing
  puts "Warning: Could not open file #{file_path}"
  []
end

# Recursively find and list all includes
def find_includes(file_path, visited = Set.new, all_includes = Set.new)
  return if visited.include?(file_path)

  visited.add(file_path)
  puts "Processing: #{file_path}"

  includes = extract_includes(file_path)
  includes.each do |include|
    puts "  Included: #{include}"
    # Add to the global set of all included files
    all_includes.add(include)

    # Assuming local includes (starting with `"`), recurse into them
    next_file = File.join(File.dirname(file_path), include)
    find_includes(next_file, visited, all_includes)
  end
end

# List all files in the current directory that are not being included
def list_unincluded_files(all_includes, input_files, current_dir)
  all_files = Dir.glob("#{current_dir}/*.h").map { |f| File.basename(f) }

  # Exclude input files from being listed as "not used"
  unincluded_files = all_files.reject { |file| all_includes.include?(file) || input_files.include?(File.basename(file)) }

  puts "\nFiles not being included anywhere: #{unincluded_files.join(" ")}"
end

# Main script
if ARGV.empty?
  puts "Usage: #{__FILE__} <path_to_header1.h> <path_to_header2.h> ..."
  exit 1
end

all_includes = Set.new
visited = Set.new

input_files = ARGV.map { |file| File.basename(file) }

# Process each provided header file
ARGV.each do |header_file|
  find_includes(header_file, visited, all_includes)
end

# List files in the current directory that are not included, excluding input files
current_dir = Dir.pwd
list_unincluded_files(all_includes, input_files, current_dir)
