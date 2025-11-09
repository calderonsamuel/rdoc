# Changelog

## rdoc (development version)

### New Features

#### Three-Level Mode System

rdoc now offers three distinct type checking modes to match different
development stages:

- **`mode = "lenient"` (default)**: Check typed code only, ignore
  untyped functions. Perfect for gradual adoption and exploratory
  analysis.

- **`mode = "exported"` (recommended for packages)**: Require type
  annotations on `@export` functions only, internal functions remain
  optional. Inspired by Rust’s `#[warn(missing_docs)]` for public items.
  This is the sweet spot for R package development.

- **`mode = "strict"` (maximum safety)**: Require type annotations on
  all functions and warn when using untyped function results. Similar to
  Python’s mypy `--disallow-untyped-defs`.

**Migration**: The old `strict` parameter has been replaced with `mode`.
Update your `.lintr` configuration:

``` r
# Old (no longer supported)
linters: with_defaults(
  type_consistency = rdoc::type_consistency_linter(strict = TRUE)
)

# New
linters: with_defaults(
  type_consistency = rdoc::type_consistency_linter(mode = "strict")
)
```

**Example - Exported Mode**:

``` r
# .lintr configuration
linters: with_defaults(
  type_consistency = rdoc::type_consistency_linter(mode = "exported")
)

# ✅ No lint - internal helper, no annotation required
.helper <- function(x) x * 2

# ❌ Lint - exported function missing annotations
#' Public API function
#' @export
add <- function(a, b) a + b
# Error: Parameter 'a' missing type annotation (exported mode)
# Error: Parameter 'b' missing type annotation (exported mode)
# Error: Function 'add' missing return type annotation (exported mode)
```

### Internal Improvements

- Simplified codebase by extracting
  [`create_lint()`](https://calderonsamuel.github.io/rdoc/reference/create_lint.md)
  helper function, reducing duplication by 72 lines across 3 files
- Consolidated S7 type map into single source of truth (`.s7_class_map`)
- Improved constructor inference with loop-based pattern matching
- Enhanced unknown type handling for strict mode warnings

### Bug Fixes

- Fixed issue where function calls not in type registry would
  incorrectly infer types from their arguments instead of returning
  “unknown”
- Fixed lint combination logic to allow both annotation lints and usage
  lints in the same run

------------------------------------------------------------------------

## rdoc 0.0.0.9000

- Initial development version
- Custom roxygen2 tags: `@typedParam` and `@typedReturn`
- Static type checking via lintr integration
- Variable type inference
- Function return type inference
- Return value validation
- S7-first type system with all 25 S7 base types
- NULL safety with union types (`NULL | Type`)
- Box module support
- Comprehensive test suite (887 tests)
