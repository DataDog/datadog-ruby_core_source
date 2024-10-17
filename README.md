## Description
Fork of [debase-ruby\_core\_source](https://github.com/ruby-debug/debase-ruby_core_source/)
that uses included Ruby headers (\*.h and \*.inc) instead of downloading
them. Used by [dd-trace-rb](https://github.com/DataDog/dd-trace-rb).
Only Ruby 2.5, 3.3, and 3.4 versions are supported - [see here for more information](https://github.com/DataDog/dd-trace-rb/blob/master/ext/datadog_profiling_native_extension/NativeExtensionDesign.md#usage-of-private-vm-headers).

## Usage

Example use in extconf.rb:

```ruby
require 'datadog/ruby_core_source'
hdrs = proc { have_header("vm_core.h") and have_header("iseq.h") }
dir_config("ruby") # allow user to pass in non-standard core include directory
if !Datadog::RubyCoreSource::create_makefile_with_core(hdrs, "foo")
  # error
  exit(1)
end
```

To add another ruby version's source to this gem's directory:

    $ rake add_source VERSION=2.1.3 PATCHLEVEL=242

_Adding released versions_. `add_source` can use a pre-downloaded .tgz file. Use TGZ_FILE_NAME to pass it. Note that the PATCHLEVEL variable is optional because `add_source` can extract the patch level from version.h of the downloaded sources.

_Adding pre-release versions_. For pre-releases, do not provide the PATCHLEVEL, as it is not present in distribution. To find sources of pre-release versions, this gem will look in the `Datadog::RubyCoreSource::REVISION_MAP` hash. Please add the respective entry into this hash when adding pre-release version sources. 

## Credits

* 

## LICENSE
Ruby library code is MIT license - see LICENSE.txt.  Included ruby headers,
lib/datadog/ruby\_core\_source/, are mostly Ruby license - see RUBY\_LICENSE. Some headers have their own licenses - see LEGAL.
