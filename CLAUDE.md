# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## General guidelines

- Never use emojis
- Don't ever be psycophantic. Don't tell me I'm right. Challenge my decisions and comments.
- Ask questions. Constantly.

## Project Overview

**rdoc** enables static type checking for R functions using JSDoc-style annotations, similar to TypeScript. Type annotations use S7 as the foundation - S7 class objects are the source of truth, not type strings.

This project is still in development, not even reaching public beta. There is no stable internal implementation yet. No refactoring needs to consider backward compatibility.

### How It Works

**Two-part system:**
1. **Custom roxygen2 tags** - `@typedParam` and `@typedReturn` with JSDoc-like `{type}` syntax
2. **Custom lintr linter** - Integrates with `{languageserver}` to validate function calls

**For R Packages:** Custom roclet generates `inst/types.rds` during `devtools::document()`.

### Type Notation

```
class_numeric, class_character, class_logical, class_integer   # S7 base types
class_list<class_integer>                                      # element type constraint
NULL | class_character                                         # optional (NULL must be first)
class_integer | class_character                                # union types
roxygen2::roclet                                               # external package types
... {class_any}                                                # ellipsis (only class_any allowed)
```

### Example
```r
#' @typedParam x {class_numeric} vector of values
#' @typedReturn {class_numeric} the mean value
calculate_mean <- function(x) mean(x)
```

## Development Commands

```r
devtools::test()              # Run tests
devtools::check()             # R CMD check
devtools::load_all()          # Load package
devtools::document()          # Update documentation
```

## Package Structure

### Core Files
- `R/tags.R` - roxygen2 tag parsers
- `R/roclet-types.R` - roclet that generates `inst/types.rds`
- `R/type-lexer.R` - tokenize type syntax
- `R/type-parser.R` - build AST from tokens
- `R/s7-types.R` - S7 type resolution and compatibility
- `R/linter.R` - main linter orchestration
- `R/linter-extract.R` - type extraction from roxygen/XML
- `R/linter-inference.R` - type inference
- `R/linter-check.R` - function call validation
- `R/linter-validate.R` - return value validation

## Architecture

### Type Resolution (S7-First)

S7 class objects are the source of truth:
```
{integer} → type_string_to_s7_class() → S7::class_integer → s7_class_compatible()
```

Fallback to string-based checking only for non-S7 types (data.frame, matrix, etc).

### Linter Multi-Pass Strategy

1. **Accumulate** comments and variable assignments in cache
2. **Extract** types from accumulated comments when function definition found
3. **Validate** function calls using cached types and variables

### Public API

**Exported functions (2):**
- `type_consistency_linter(mode)` - linter integration (modes: lenient/exported/strict)
- `roclet_types()` - roclet for type metadata generation

## LOGBOOK.md

Update after completing any implementation phase:

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
