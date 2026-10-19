/* The datadog-ruby_core_source gem emptied this header: dd-trace-rb does not need
 * anything from it, and keeping it would mean also shipping the much larger prism/
 * headers. The file itself is kept because iseq.h includes it. */

/* iseq.h on Ruby 3.3 uses these prism types, but only as pointers,
 * so declaring them as opaque types is enough. */
typedef struct pm_string pm_string_t;
typedef struct pm_options pm_options_t;
