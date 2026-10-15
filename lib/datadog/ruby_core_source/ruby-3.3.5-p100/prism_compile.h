/* The contents of this header were removed by the datadog-ruby_core_source gem:
 * they are not needed by the headers used in dd-trace-rb, and keeping them would mean
 * also shipping all the prism/ headers, which this gem does not ship.
 * This file is kept because iseq.h includes it. */

/* These types are used by iseq.h on Ruby 3.3, they are declared as opaque types
 * since they are only used as pointers. */
typedef struct pm_string pm_string_t;
typedef struct pm_options pm_options_t;
