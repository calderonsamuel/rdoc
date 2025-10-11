# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## General guidelines

- Never use emojis
- Don't ever be psycophantic. Don't tell me I'm right. Challenge my decisions and comments.
- Ask questions. Constantly.

## Project Overview

**rdoc** enables static type checking for R functions using JSDoc-style annotations, similar to TypeScript. Type annotations use S7 as the foundation - S7 class objects are the source of truth, not type strings.

### Goal
Provide type annotations for R functions that IDEs (especially VSCode) can use to lint code and catch type errors before runtime.

### How It Works

**Two-part system:**
1. **Custom roxygen2 tags** - `@typedParam` and `@typedReturn` with JSDoc-like `{type}` syntax (replaces `@param`/`@return`)
2. **Custom lintr linter** - Integrates with `{languageserver}` to validate function calls

**For R Scripts:**
- Linter reads type annotations directly from roxygen comments
- Validates function calls against type signatures
- Infers types from literals, constructors, and function calls
- Reports mismatches to VSCode via `{languageserver}` + `{lintr}`

**For R Packages:**
- Custom roclet generates `inst/types.rds` during `devtools::document()`
- Type metadata gets installed with the package
- Users get type checking automatically with `.lintr` config

### Type Notation

**Basic types:**
- `numeric`, `character`, `logical`, `integer` - S7 base types
- `numeric[1]` - scalar (length 1)
- `numeric[5]` - exactly 5 elements
- `list<integer>` - list with integer elements
- `list<integer>[3]` - list of exactly 3 integers
- `NULL | character` - optional types (NULL must be first)
- `integer | character` - union types

**External types (Phase 24.1 ✅):**
- `roxygen2::roclet` - type from external package
- `NULL | roxygen2::roclet` - optional external type
- `list<roxygen2::roclet>` - list of external types
- `roxygen2::roclet | lintr::Linter` - union of external types

**Ellipsis (variadic arguments):**
- `... {class_any} description` - must explicitly specify `{class_any}`
- Ellipsis annotations are optional (not required even in strict mode)
- Only `class_any` is supported; other types produce lint errors
- Used for forwarding arguments or collecting variadic inputs

**Constraint syntax:**
- `[]` for length constraints
- `<>` for element type constraints (generics)
- `|` for union types (NULL must be first if present)
- `::` for external package types

### Example
```r
#' Calculate mean of numeric vector
#' @typedParam x {numeric} vector of values
#' @typedParam trim {numeric[1]} proportion to trim (0-0.5)
#' @typedParam na.rm {logical[1]} remove NA values?
#' @typedReturn {numeric[1]} the mean value
calculate_mean <- function(x, trim = 0, na.rm = FALSE) {
  mean(x, trim = trim, na.rm = na.rm)
}

# Variable type inference catches errors
my_data <- list(1, 2, 3)  # Inferred as type "list"
calculate_mean(my_data)    # ✅ Lint: expects 'numeric' but got 'list'

# Ellipsis example (variadic arguments)
#' Wrapper that forwards arguments
#' @typedParam x {numeric} data vector
#' @typedParam ... {class_any} additional arguments passed to mean()
#' @typedReturn {numeric[1]} mean value
mean_wrapper <- function(x, ...) {
  mean(x, ...)
}

mean_wrapper(1:10, na.rm = TRUE)  # Forward na.rm to mean()
```

## Development Commands

```r
# Standard package development workflow
devtools::install_dev_deps()  # Install dependencies
devtools::check()             # R CMD check
devtools::build_readme()      # Build README from README.Rmd
devtools::test()              # Run tests
devtools::load_all()          # Load package
devtools::document()          # Update documentation
```

**Testing**: 989 passing tests, 2 skipped, 0 failures

**CI/CD**: R-CMD-check on macOS, Windows, Ubuntu (multiple R versions), Codecov coverage

## Package Structure

### Core Files
- `R/tags.R` - roxygen2 tag parsers for `@typedParam`/`@typedReturn`
- `R/roclet-types.R` - roclet that generates `inst/types.rds`
- `R/type-lexer.R` - tokenize type syntax
- `R/type-parser.R` - build AST from tokens
- `R/type-syntax-validator.R` - validate syntax
- `R/s7-types.R` - S7 type resolution and compatibility
- `R/linter.R` - main linter orchestration (multi-pass caching)
- `R/linter-extract.R` - type extraction from roxygen/XML
- `R/linter-inference.R` - type inference (literals, variables, constructors)
- `R/linter-check.R` - function call validation, package types
- `R/linter-validate.R` - return value validation

### Generated Files
- `inst/types.rds` - type metadata (installed with package)

## Architecture

### Type Resolution (S7-First)

**Core principle**: S7 class objects are the source of truth.

```
{integer} → type_string_to_s7_class() → S7::class_integer → s7_class_compatible()
```

Fallback to string-based checking only for non-S7 types (data.frame, matrix, etc).

**Key functions:**
1. `type_string_to_s7_class()` - Maps type strings to S7 class objects
2. `s7_class_compatible()` - Uses S7 metadata for compatibility checking (handles inheritance, unions)
3. `types_compatible()` - S7-first, falls back to string matching for non-S7 types

**External types**: Use `resolve_external_type()` to create S7 wrappers for `package::class` syntax. Uses exact string matching in Phase 24.1.

### Linter Multi-Pass Strategy

Lintr processes code in multiple passes:
1. **Accumulate** comments and variable assignments in cache
2. **Extract** types from accumulated comments when function definition found
3. **Validate** function calls using cached types and variables

**Variable type inference:**
- Literals: `a <- "text"` → character
- Constructors: `a <- list()` → list, `a <- data.frame()` → data.frame
- Function calls: `a <- get_number()` → looks up `@typedReturn` from registry
- Returns "unknown" for untyped functions (enables strict mode warnings)

**Return value validation:**
- Validates `@typedReturn` matches implementation
- Handles simple cases (explicit returns, implicit returns, literals, constructors)
- Skips complex control flow (multiple returns, if/else, loops)

**Critical implementation detail**: In `infer_argument_type()`, function call checks (c(), list(), data.frame(), matrix()) MUST come BEFORE literal checks. Otherwise `list(1, 2)` would incorrectly infer as "numeric" from its arguments.

### Three-Level Mode System

```r
# .lintr configuration
linters: with_defaults(
  # Lenient (default) - check typed code only
  type_consistency = rdoc::type_consistency_linter()

  # Exported (recommended for packages) - require types on @export functions
  type_consistency = rdoc::type_consistency_linter(mode = "exported")

  # Strict (maximum safety) - require types on all functions + warn on unknown
  type_consistency = rdoc::type_consistency_linter(mode = "strict")
)
```

**Exported mode detection**: Uses `grepl("@export\\b", comments)` to detect exported functions. Works with roxygen2 and {box} modules.

### Public API

**Exported functions (2):**
- `type_consistency_linter(mode)` - linter integration
- `roclet_types()` - roclet for type metadata generation

**S3 methods (5):** Required by roxygen2/lintr infrastructure
- `roxy_tag_parse.roxy_tag_typedParam`
- `roxy_tag_parse.roxy_tag_typedReturn`
- `roclet_process.roclet_types`
- `roclet_output.roclet_types`
- `roclet_tags.roclet_types`

Internal utilities accessible via `:::` but not part of public API.

## Test Coverage

**989 passing tests, 2 skipped, 0 failures**

### Test Files
- `test-tags.R` - Tag parsing (25 tests)
- `test-parse-types.R` - Type utilities (46 tests)
- `test-roclet.R` - Roclet output (22 tests)
- `test-type-parser.R` - Parser (170 tests)
- `test-s7-types.R`, `test-s7-base-types.R` - S7 system (179 tests)
- `test-null-safety.R` - NULL unions (18 tests)
- `test-type-constraints.R` - Bracket syntax (42 tests)
- `test-bracket-edge-cases.R` - Edge cases (39 tests)
- `test-linter-modes.R` - Mode system (60 tests)
- `test-linter-*.R` - Linter functionality (110 tests)
- `test-box-*.R` - Box module support (160 tests)
- `test-external-types.R` - External types (79 tests)
- `tests/manual/` - VSCode integration (manual verification)

## User Workflows

### Package Authors
```r
# 1. Add type annotations
#' @typedParam x {numeric} input values
#' @typedReturn {numeric} output

# 2. Generate type metadata
devtools::document()  # Creates inst/types.rds

# 3. Configure linter (recommended: exported mode)
# .lintr:
linters: with_defaults(
  type_consistency = rdoc::type_consistency_linter(mode = "exported")
)

# 4. Install/publish package (types.rds included)
```

### Package Users
```r
# 1. Configure .lintr (choose mode based on needs)
linters: with_defaults(
  type_consistency = rdoc::type_consistency_linter()  # or "exported", "strict"
)

# 2. VSCode automatically lints using type info from installed packages
library(yourpkg)
my_df <- data.frame(x = 1:3)
foo(my_df)  # Shows lint error if foo expects different type
```

## Current Status

**Production Ready**: Core functionality complete with comprehensive test coverage (989 passing tests)

**Complete features:**
- ✅ JSDoc-style type annotations (`@typedParam`, `@typedReturn`)
- ✅ Roxygen2 integration (generates `.Rd` documentation)
- ✅ Static type checking via lintr
- ✅ Three-level mode system (lenient/exported/strict)
- ✅ S7-first type system (all 25 S7 base types)
- ✅ NULL safety (optional types with `NULL | Type`)
- ✅ Type inference (literals, constructors, function calls)
- ✅ Return value validation
- ✅ Named and positional argument matching
- ✅ Package type metadata export/import
- ✅ Box module integration
- ✅ External type support (`package::class` syntax)
- ✅ Dogfooding (rdoc processes its own types)

**Known limitations:**
- File-level scope only (no cross-file analysis)
- Return validation skips complex control flow
- No type narrowing from conditionals
- Constructor inference limited to common types (c, list, data.frame, matrix)

## Code Style

Follow the [tidyverse style guide](https://style.tidyverse.org):
- Use styler package for formatting
- Only restyle code relevant to your changes
- Documentation uses roxygen2 with Markdown
- User-facing changes go in `NEWS.md`

## Contributing Workflow

1. Fork and create branch: `usethis::pr_init("brief-description")`
2. Ensure `devtools::check()` passes cleanly
3. Add bullet to `NEWS.md` for user-facing changes
4. Push PR: `usethis::pr_push()`

## Documentation Files

### Core Documentation
- **README.Rmd** - Source file for README.md (always edit .Rmd, not .md)
- **CLAUDE.md** - This file - AI assistant instructions and architecture overview
- **IMPLEMENTATION_PLAN.md** - Detailed technical specifications and phase planning
- **LOGBOOK.md** - Key learnings and design decisions from each phase (living document)

### LOGBOOK.md - Living Document

**Purpose**: Technical reference documenting key learnings, design decisions, and insights from each implementation phase.

**When to update**: After completing ANY new implementation phase, add an entry to LOGBOOK.md.

**Entry template**:
```markdown
## Phase X: [Feature Name]

**Date**: Timestamp in UTC
**Status**: ✅ Complete ([N] tests passing)

### Design Decision: [Key Decision Made]

**Problem**: [What problem were we solving?]

**Solution**: [What approach did we take?]

**Rationale**:
- [Why this approach?]
- [What alternatives were considered?]
- [What tradeoffs were made?]

**Key Insight**: [Main lesson learned - 1-2 sentences]

**What This Enabled**: [What can users now do that they couldn't before?]
```

**Current coverage**: 16 phases documented (Phases 1, 4, 5, 6.5, 7, 7.2, 10, 11, 12.1, 12.5, 13.4, 14, 15.5, 21, 22, 23, 24.1)

**Audience**: Blog posts, case studies, future contributors, technical retrospectives

## Notes

- Package uses pkgdown for documentation site
- Leverages existing `{lintr}` + `{languageserver}` ecosystem (no custom LSP)
- Tag names use camelCase (`@typedParam`) - roxygen2 doesn't allow hyphens
- S7 is the type system - type strings resolve to S7 class objects
