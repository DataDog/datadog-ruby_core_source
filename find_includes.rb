#!/usr/bin/env ruby

# @ivoanjo: I've used ChatGPT to generate this quick-and-dirty tool. It can be used to identify recursively which
# ruby headers include which headers, and which are not used. E.g. by using
# `find_includes.rb vm_core.h iseq.h ractor_core.h` we get a rough list of headers that are not needed by the
# datadog gem. Always remember to validate the result -- this tool isn't perfect (for instance it doesn't detect that
# thread_pthread.h is in use).

require 'set'
require 'pry'

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
