#!/usr/bin/env ruby

# @ivoanjo: I've used ChatGPT to generate this quick-and-dirty tool.
# This was added in https://github.com/DataDog/datadog-ruby_core_source/pull/5 . The intent of this script is to do
# the following: Starting from the internal VM headers used by the profiler in dd-trace-rb, identify which other
# headers are needed by those headers, and keep those, but delete everything else.
#
# To invoke it:
#
# $ bundle exec ruby find_includes.rb vm_core.h iseq.h ractor_core.h thread_pthread.h thread_none.h
#
# And we get a list of headers that are not needed by the datadog gem.
# Always remember to validate the result (see below).
#
# This makes this gem very tailored to the needs of dd-trace-rb. In the future this may change.
# This is purely a size-based optimization; we delete any file that the profiler doesn't need right now; it's OK to
# skip using this tool and ship the full set of headers (they're just not needed).
#
# ---
#
# 1. What internal VM headers should you start from?
# Currently this script should be started from `find_includes.rb vm_core.h iseq.h ractor_core.h`. These headers are the
# ones included in
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
#   a. Import the new set of headers
#   b. Run `find_includes.rb` on the specific headers folder being imported (each one, if multiple)
#   c. Delete the resulting files
#   d. Check that the profiler still builds on those Ruby versions (using CI, or locally in docker)
#   e. If any issues arise, leave all the headers in place! We can perform this optimization as a separate step

require 'set'

KNOWN_MISSING = %w[
  ruby/internal/config.h
  wasm/setjmp.h
  prism_xallocator.h
].to_set

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

# Recursively find and list all includes
def find_includes(file_path, visited, all_includes)
  return if visited.include?(file_path)

  visited.add(file_path)
  return if KNOWN_MISSING.include?(file_path)

  puts "Processing: #{file_path}"

  includes = extract_includes(file_path)
  includes.each do |include|
    puts "  Included: #{include}"
    # Add to the global set of all included files
    all_includes.add(include)

    # includes are simply resolved from the top-level source directory
    resolved_include = include
    find_includes(resolved_include, visited, all_includes)
  end
end

# List all files in the current directory that are not being included
def list_unincluded_files(all_includes, input_files)
  all_files = Dir.glob("**/*.*")

  unincluded_files = all_files - input_files - all_includes.to_a

  puts "\nFiles not being included anywhere: #{unincluded_files.join(" ")}"
end

# Main script
if ARGV.empty?
  puts "Usage: #{__FILE__} <path_to_header1.h> <path_to_header2.h> ..."
  exit 1
end

all_includes = Set.new
visited = Set.new

input_files = ARGV

# Process each provided header file
input_files.each do |header_file|
  if File.exist?(header_file)
    find_includes(header_file, visited, all_includes)
  else
    warn "WARNING: input file #{header_file} does not exist on this version"
  end
end

# List files in the current directory that are not included, excluding input files
list_unincluded_files(all_includes, input_files)
