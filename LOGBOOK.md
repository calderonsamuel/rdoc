# rdoc Development Logbook

**Purpose**: This living document records key learnings, design decisions, and technical insights from each implementation phase. It serves as a reference for understanding how rdoc evolved and why certain architectural choices were made.

**Audience**: Blog post readers, case study researchers, future contributors

**Last Updated**: 2025-11-09 20:25:56 UTC (Phase 35 - Length Constraint Removal)

---

## Phase 1: Custom Roxygen2 Tags

**Date**: Early 2024
**Effort**: 2-3 days
**Status**: ✅ Complete (25 tests passing)

### Design Decision: JSDoc-Style Syntax with CamelCase Tags

**Problem**: Need a way to add type annotations to R functions that integrates with existing documentation system (roxygen2).

**Solution**: Custom roxygen2 tags `@typedParam` and `@typedReturn` with JSDoc-like `{type}` syntax.

**Rationale**:
- **CamelCase naming** (`@typedParam` not `@typed-param`): roxygen2 doesn't allow hyphens in tag names
- **JSDoc syntax**: Familiar to developers from TypeScript/JavaScript ecosystem
- **Single source of truth**: These tags REPLACE `@param`/`@return`, not supplement them (DRY principle)
- **Type in braces**: `{type}` clearly separates type from description

**Syntax**:
```r
#' @typedParam x {numeric} vector of values
#' @typedReturn {numeric[1]} the mean value
```

**Key Insight**: Don't fight the framework. roxygen2's conventions (CamelCase tags, tag inheritance) guide the design. Integration > invention.

**What This Enabled**:
- Type annotations live in documentation (developers already write roxygen comments)
- Generated `.Rd` files include parameter descriptions
- Type information available for static checking

---

## Phase 4: Lintr Integration & Multi-Pass Execution

**Date**: Early 2024
**Effort**: 3-5 days
**Status**: ✅ Complete (97 tests passing)

### Design Decision: Cache-Based Multi-Pass Strategy

**Problem**: Lintr processes files in multiple passes - comments may arrive in different pass than function calls. Can't assume all information available in single pass.

**Solution**: Accumulate comments and variable assignments in persistent cache across passes.

**Rationale**:
- **Lintr architecture**: Processes expressions independently, can't control pass order
- **Comment accumulation**: Store comments by file until function definition found
- **Variable context**: Build map of `filename -> variable -> [(line, type)]` across passes
- **Cache key design**: Use filename as key to scope data correctly

**Cache Structure**:
```r
cache <- list(
  comments = list("file.R" = c("# comment1", "# comment2")),
  variables = list("file.R" = list("x" = list(list(line = 5, type = "numeric")))),
  types = list("file.R" = list("foo" = list(params = ..., return = ...)))
)
```

**Key Insight**: When integrating with external frameworks, understand their execution model. Lintr's multi-pass approach requires stateful caching, not pure functional processing.

**Critical Implementation Detail**: Cache must be scoped by filename to avoid leaking data between files in same linting session.

---

## Phase 5: Variable Type Inference

**Date**: Mid 2024
**Effort**: 3-4 days
**Status**: ✅ Complete (77 linter tests)

### Design Decision: Constructor Detection Before Literal Checking

**Problem**: Need to infer types from variable assignments so `x <- list(1, 2); foo(x)` knows `x` is a list.

**Solution**: Infer types from literals, constructors (c(), list(), data.frame(), matrix()), and track assignments.

**Rationale**:
- **Constructor detection**: Recognize common R patterns for creating objects
- **Line number tracking**: Use most recent assignment before variable usage
- **Unknown fallback**: Return "unknown" for unrecognized patterns (enables strict mode warnings later)

**Critical Bug Fix**: Function call checks (c(), list(), data.frame(), matrix()) MUST come BEFORE literal checks.

**Why?**
```r
# WRONG ORDER:
infer_type(list(1, 2))
  → checks literals first
  → sees STR_CONST "1"
  → returns "numeric" ❌

# CORRECT ORDER:
infer_type(list(1, 2))
  → checks function calls first
  → sees SYMBOL_FUNCTION_CALL "list"
  → returns "list" ✅
```

**Key Insight**: Order of checks matters in AST traversal. More specific patterns (function calls) must come before general patterns (literals), otherwise generic rules swallow specific cases.

**What This Enabled**:
- Variable assignments tracked across file
- Type errors caught when passing variables to functions
- Constructor calls recognized (c, list, data.frame, matrix)

---

## Phase 6.5: Code Refactoring

**Date**: Mid 2024
**Effort**: 1 day
**Status**: ✅ Complete (maintained 171 tests)

### Design Decision: Split Monolithic Linter Into 4 Modules

**Problem**: `R/linter.R` grew to 931 lines mixing concerns (extraction, inference, validation, orchestration).

**Solution**: Split into focused modules:
- `R/linter.R` (109 lines) - orchestration
- `R/linter-extract.R` (350 lines) - type extraction from comments/XML
- `R/linter-inference.R` (228 lines) - type inference from AST
- `R/linter-check.R` (241 lines) - function call validation

**Rationale**:
- **Separation of concerns**: Each file has single responsibility
- **Easier navigation**: Related functions grouped together
- **Onboarding**: New contributors can understand one module at a time
- **R package conventions**: Multiple smaller files more idiomatic than one giant file

**Key Insight**: Refactor when file exceeds ~300 lines or mixes concerns. Don't wait until it's painful. All tests still passing proves refactoring was clean.

**What This Enabled**:
- Easier code reviews (changes localized to relevant module)
- Faster development (find functions quickly)
- Better test organization (parallel test file structure)

---

## Phase 7: Function Return Type Inference

**Date**: Mid 2024
**Effort**: 2-3 days
**Status**: ✅ Complete (88 linter tests)

### Design Decision: Trust-Based Return Type Inference

**Problem**: `@typedReturn` annotations exist but aren't useful - can't infer types from function calls like `result <- get_data()`.

**Solution**: Look up `@typedReturn` from type registry (local functions + package functions) and trust it.

**Rationale**:
- **Trust annotations**: rdoc's philosophy is "trust, then verify" not "infer everything"
- **O(1) lookup**: Fast hash table lookup by function name
- **Cross-package**: Works for any package with type metadata (`inst/types.rds`)
- **Consistent**: Simpler than dataflow analysis, matches user expectations

**Critical Bug**: Initial XPath query used `.//SYMBOL_FUNCTION_CALL` (any descendant) which skipped nested calls. Fixed to `./SYMBOL_FUNCTION_CALL` (direct child).

**Key Insight**: For type systems, trust annotations is simpler and faster than inference. Dataflow analysis is complex - only add it if trust-based approach proves insufficient.

**What This Enabled**:
- Call chains type-check: `show_results(process_data(load_data()))`
- Type information propagates through codebase
- Package functions with `@typedReturn` usable in type checking

---

## Phase 7.2: Return Value Validation

**Date**: Mid 2024
**Effort**: 3-4 days
**Status**: ✅ Complete (110 linter tests)

### Design Decision: Validate Simple Cases, Skip Complex Control Flow

**Problem**: Functions declare `@typedReturn {numeric}` but implementation returns `"text"` - need to validate implementation matches declaration.

**Solution**: Check simple cases (explicit returns, implicit returns, literals) and skip complex cases (multiple returns, if/else, loops).

**Rationale**:
- **No false positives**: Better to skip edge cases than report incorrect errors
- **Simple cases common**: Most R functions are simple - single return path
- **Trust user intent**: If function has complex control flow, trust the `@typedReturn` annotation

**Handles**:
- ✅ Explicit `return(42)` with `@typedReturn {character}` → warns
- ✅ Implicit return: `function() "text"` with `@typedReturn {numeric}` → warns
- ✅ Comparison operators: `function() x > 5` with `@typedReturn {logical}` → passes
- ✅ Both braced and unbraced function bodies

**Skips**:
- ⏭️ Multiple return statements (if/else branches)
- ⏭️ Loops with returns inside
- ⏭️ Complex control flow

**Key Insight**: For linters, precision > recall. False positives destroy trust. Better to miss some bugs than report non-bugs. Skip complex cases gracefully rather than guess incorrectly.

**What This Enabled**:
- Catches incorrect `@typedReturn` declarations
- Validates comparison/logical operators return logical
- Makes return type inference more reliable (fewer incorrect annotations)

---

## Phase 10: Full Roxygen2 Integration

**Date**: Mid 2024
**Effort**: 2-3 days
**Status**: ✅ Complete

### Design Decision: Replace @param/@return, Not Supplement

**Problem**: Initial design had users write both `@param` and `@typedParam` - violates DRY principle.

**Solution**: Make `@typedParam`/`@typedReturn` inherit from roxygen2's `roxy_tag_param`/`roxy_tag_return` base classes.

**Rationale**:
- **DRY principle**: Single source of truth for parameter documentation
- **S3 inheritance**: roxygen2 uses S3 dispatch - inherit base tag classes to get `.Rd` generation for free
- **User experience**: Less typing, no duplicate documentation

**Implementation**:
```r
# Tags inherit from base classes
roxy_tag_parse.roxy_tag_typedParam <- function(...) {
  tag <- # ... parse type syntax ...
  structure(tag, class = c("roxy_tag_typedParam", "roxy_tag_param"))
}

# roxygen2 automatically generates .Rd from roxy_tag_param methods
```

**Key Insight**: When extending a system (roxygen2), leverage its abstraction mechanisms (S3 inheritance). Don't fight the framework - inherit base classes to get behavior for free.

**What This Enabled**:
- Users write `@typedParam` only, not both `@param` and `@typedParam`
- Generated `.Rd` files look identical to `@param`-based docs
- Type information hidden from user docs, only visible to linter

---

## Phase 11: Dogfooding

**Date**: Late 2024
**Effort**: 2-3 days
**Status**: ✅ Complete (204 tests passing)

### Design Decision: Use rdoc to Lint Itself

**Problem**: How to validate rdoc works on real-world codebases? Best test: use it on itself.

**Solution**: Add type annotations to rdoc's own functions and lint rdoc with rdoc.

**Rationale**:
- **Real-world validation**: rdoc codebase has same patterns users will have
- **Circular dependency solution**: Use `@exportS3Method` instead of `@export` for S3 methods
- **CRAN compliant**: `.lintr` in `.Rbuildignore` (dev-only)
- **Confidence builder**: If rdoc can lint itself, it can lint anything

**Critical Fix**: S3 method registration
```r
# BEFORE (circular dependency):
#' @export
roxy_tag_parse.roxy_tag_typedParam <- function(...) { }

# AFTER (works):
#' @exportS3Method roxygen2::roxy_tag_parse
roxy_tag_parse.roxy_tag_typedParam <- function(...) { }
```

**Why This Works**: `@exportS3Method` creates `S3method()` declaration in NAMESPACE, ensuring roxygen2 can find tag parsers during `devtools::document()`.

**Key Insight**: Dogfooding exposes real-world issues before users hit them. The circular dependency problem (rdoc needs roxygen2 tag parsers to process its own tags) only surfaced when we tried to use rdoc on itself.

**What This Enabled**:
- rdoc lints cleanly with 0 false positives in exported mode
- Generated `inst/types.rds` with metadata for rdoc's own functions
- Confidence that rdoc works for package development

---

## Phase 12.1: S7-First Type System Architecture

**Date**: December 2024
**Effort**: 2-3 days
**Status**: ✅ Complete (308 tests passing)

### Design Decision: S7 Objects as Source of Truth

**Problem**: Original implementation used string-based type checking (`"integer" == "integer"`), which couldn't handle inheritance or union types properly.

**Solution**: Type strings resolve to S7 class objects, and validation uses S7's metadata.

**Rationale**:
- S7 already implements type compatibility checking with inheritance
- S7 unions (`class_numeric = class_integer | class_double`) work automatically
- Custom S7 classes with parent chains work without additional code
- Future-proof: when R ecosystem adopts S7, rdoc benefits automatically

**Key Insight**: Don't reimplement what already exists in a well-designed type system. Let S7 be the expert on S7 types.

**Flow**:
```
{integer} → type_string_to_s7_class() → S7::class_integer → s7_class_compatible()
```

**What This Enabled**:
- Inheritance checking for free (walk `@parent` chain)
- Union type support without custom logic
- Both `{integer}` and `{class_integer}` syntax work

---

## Phase 12.5: Modern Bracket Notation

**Date**: December 2024
**Effort**: 2-3 days
**Status**: ✅ Complete (537 tests passing)

### Design Decision: `[]` for Length, `<>` for Element Type

**Problem**: Original syntax `list[3]` was ambiguous - does it mean "list of length 3" or "list with element type 3"?

**Solution**:
- `[n]` = length constraints (e.g., `numeric[5]` = exactly 5 numbers)
- `<T>` = element type constraints (e.g., `list<integer>` = list of integers)
- Composable: `list<numeric>[3]` = list of exactly 3 numbers

**Rationale**:
- Zero ambiguity between constraints
- Familiar to developers: `<T>` is standard generics syntax (C++, Rust, TypeScript)
- Aligns with S7's future direction for generic types
- Composable and extensible

**Alternative Considered**: Scala-style `Array[Int]` for element types
- Rejected because it doesn't distinguish length from element type
- `Array[5]` could mean "array of length 5" or "array of type 5"

**Key Insight**: Good syntax should make impossible states unrepresentable. Two different bracket types = two different semantics.

---

## Phase 13.4: Recursive Descent Parser

**Date**: December 2024
**Effort**: 4-6 days
**Status**: ✅ Complete (665 tests passing)

### Design Decision: Hand-Written Parser vs Regex Validation

**Problem**: Started with regex-based validation. By Phase 13.1, had accumulated 12+ regexes with brittle edge cases:
- `character[100]` vs `character5` required complex lookaheads
- Generic error messages (couldn't point to exact column)
- Each new feature multiplied regex complexity
- Validation separate from parsing (duplicate logic)

**Solution**: Implemented recursive descent parser with separate lexer.

**Rationale**:
- **Better error UX**: Precise column numbers ("Error at column 12: expected ']', found '}'")
- **Maintainability**: 250 lines of clear parser > 12+ scattered regexes
- **Extensibility**: Adding nullable `?` or readonly `!` is trivial
- **No dependencies**: Keeps rdoc lightweight (critical for CRAN)
- **Industry proven**: TypeScript, Python, Rust all use hand-written parsers

**Alternatives Considered**:
- **pegr (PEG parser)**: External dependency, less common in R
- **rly (Lex + Yacc)**: More boilerplate, CRAN package but still a dependency
- **Continue with regexes**: Already brittle, would only get worse

**Architecture**:
```
Input → Lexer (tokenize) → Parser (build AST) → Validator (semantic checks)
```

**Key Insight**: A 250-line recursive descent parser beats 12+ regexes. The upfront effort pays off immediately in maintainability and error quality. When validation logic gets complex, bite the bullet and write a proper parser.

**What This Enabled**:
- Precise error messages with exact positions
- Nested generics: `list<list<integer>>`
- Union types in generics: `list<integer | character>`
- Foundation for future syntax extensions

---

## Phase 14: NULL Safety with S7 Unions

**Date**: December 2024
**Effort**: 3 days (as estimated)
**Status**: ✅ Complete (618 tests passing)

### Design Decision: Reuse S7's Union Infrastructure

**Problem**: NULL is the #1 source of runtime errors in R. Need to distinguish required vs optional parameters.

**Solution**: Leverage S7's existing union type system instead of reimplementing.

**Rationale**:
- S7 already validates union types: `NULL | class_integer` is an S7 union
- Zero reimplementation - reuse S7's tested code
- Consistent semantics: rdoc unions = S7 unions
- Clear error messages from S7 ("must be <NULL> or <integer>, not <character>")
- Future-proof: S7 improvements automatically benefit rdoc

**Opinionated Rule**: NULL must come first in unions (`NULL | Type`)

**Why NULL-first?**
- Matches S7 convention where union order determines default value
- `NULL | Type` defaults to NULL (correct for optional parameters)
- Explicit and unambiguous: `NULL | character` clearly means "optional character"
- Parser enforces this, preventing confusion

**Key Insight**: Don't reimplement union validation. If you're building on a type system (S7), leverage its infrastructure. ~200 lines of integration code vs ~500 lines for custom implementation.

**Implementation**:
```r
# rdoc parses: {NULL | integer}
ast <- parse_type_syntax("NULL | integer")

# Converts to S7 union:
s7_union <- rdoc_union_to_s7(ast)  # <S7_union>: <NULL> or <integer>

# S7 validates automatically:
s7_class_compatible(class_integer, s7_union)  # TRUE (int → union)
```

---

## Phase 15.5: Complete S7 Type Support

**Date**: December 2024
**Effort**: 2-3 days
**Status**: ✅ Complete (694 tests passing)

### Design Decision: Support All 25 S7 Base Types

**Problem**: Initially only supported 9/25 S7 types (atomic vectors + list + numeric union). Missing important types like `function`, `environment`, `data.frame`, `POSIXt`.

**Solution**: Added remaining 16 types in categorized groups.

**Rationale**:
- **Completeness**: Users expect all S7 types to work
- **S3 wrappers**: S7 provides wrappers for common S3 classes (`data.frame`, `Date`, `factor`)
- **Union types**: S7 defines useful unions (`atomic`, `language`, `vector`)
- **Special handling**: `any` (accepts everything), `missing` (forbidden with helpful error)

**Categories Added**:
1. Base classes (4): `call`, `environment`, `function`, `name`
2. Unions (3): `atomic`, `language`, `vector`
3. S3 wrappers (7): `data.frame`, `Date`, `factor`, `formula`, `POSIXct`, `POSIXlt`, `POSIXt`
4. Special (2): `any` (universal type), `missing` (forbidden)

**Why Forbid `missing`?**
- `missing` is a function (`missing(arg)`), not a type
- Users want `{NULL | Type}` for optional parameters (already supported via Phase 14)
- Rejecting with helpful error prevents confusion

**Key Insight**: When integrating with an existing system (S7), aim for 100% coverage of its feature set. Partial support creates confusion and forces users to learn which subset works.

---

## Phase 21: Box Module Support

**Date**: December 2024
**Effort**: 9 days (2 weeks)
**Status**: ✅ Complete (854 tests passing)

### Design Decision: Direct AST Parsing for box::use()

**Problem**: {box} package provides module system for R, but rdoc only supported standard packages with `library()`. Users couldn't type-check modular code.

**Solution**: Parse `box::use()` calls from XML AST, resolve module paths, extract types from `.r` files.

**Rationale**:
- **No box dependency**: rdoc works even if box isn't installed (graceful degradation)
- **AST-based detection**: XPath finds `box::use()` calls reliably
- **File-based caching**: Cache types with `mtime` invalidation (re-parse only when module changes)
- **Respect @export**: Only expose functions with `#' @export` directive

**Challenges Solved**:

1. **Module path resolution**:
   - Relative paths (`./local/mod`) resolved from current file
   - Absolute paths searched via `box.path` configuration
   - Read from `.Rprofile` if available, fallback to `getwd()`

2. **Multiple import patterns**:
   - Full module: `box::use(mod/math)` → `math$add()`
   - Aliased: `box::use(m = mod/math)` → `m$add()`
   - Selective: `box::use(mod/math[add])` → `add()`
   - Attach all: `box::use(mod/math[...])` → all exported functions

3. **Scope tracking**:
   - Direct imports create file-scoped bindings
   - Function calls resolved using import scope map
   - Module calls (`math$add()`) resolved using module name prefix

**Key Insight**: AST parsing is powerful for extracting structured information from R code. XPath queries make it straightforward to find specific patterns (like `box::use()` calls) without regex hackery.

**What This Enabled**:
- Type checking for {box} modules
- Modular R projects can use rdoc
- Cache invalidation prevents stale type data
- Works seamlessly alongside package types

---

## Phase 22: Three-Level Mode System

**Date**: December 2024
**Effort**: 8 hours (1 day)
**Status**: ✅ Complete (887 tests passing)

### Design Decision: Lenient / Exported / Strict Modes

**Problem**: Binary strict mode (on/off) didn't match real-world workflows. Package developers want to enforce types on public API but keep internal code flexible.

**Solution**: Three-level mode system inspired by Rust's `#[warn(missing_docs)]`.

**Rationale**:
- **Lenient (default)**: Check typed code only → gradual adoption, exploratory work
- **Exported (recommended for packages)**: Require types on `@export` functions → quality public API, flexible internals
- **Strict (maximum safety)**: Require types everywhere → new projects, mission-critical code

**Research**: Surveyed TypeScript, Python mypy, Sorbet (Ruby), Flow (JS), Rust
- Common pattern: gradual adoption → public API focus → complete coverage
- Rust's `#[warn(missing_docs)]` for public items maps to rdoc's "exported" mode

**Implementation Details**:
- `@export` detection: `grepl("@export\\b", comments)` finds exported functions
- Mode-based checking: lenient (skip) → exported (check if @export) → strict (always check)
- Unknown type handling: strict warns everywhere, exported warns on public API only

**API Design**:
```r
# New API (recommended)
type_consistency_linter(mode = "lenient")   # Default
type_consistency_linter(mode = "exported")  # Package development
type_consistency_linter(mode = "strict")    # Maximum safety
```

**Key Insight**: Binary flags don't match complex workflows. Three levels provide clear upgrade path: start lenient → enforce exported → go strict as codebase matures. Inspired by successful patterns in other languages.

**Aggressive Simplification**: No backward compatibility (`strict` parameter) because package not yet published. Clean API from day one.

---

## Phase 23: Scope-Aware Function Detection

**Date**: January 2025
**Effort**: 3 hours
**Status**: ✅ Complete (908 tests passing)

### Design Decision: Nesting Depth Filter + Internal Tag

**Problem**: Linter flagged ALL function definitions, including anonymous functions inside closures. When linting rdoc itself:
```r
#' @export
type_consistency_linter <- function(mode) {
  lintr::Linter(function(source_expression) {  # ❌ FALSE POSITIVE
    # Anonymous function flagged in exported mode
  })
}
```

**Solution**: Combined approach
1. **Nesting depth check**: Only check top-level functions (depth 0)
2. **Internal tag support**: Respect `@keywords internal` and `@internal` tags

**Rationale**:
- **XPath fix**: Changed `.//SYMBOL_FORMALS` (any descendant) to `./SYMBOL_FORMALS` (direct child)
- **Walk AST tree**: If we encounter another `FUNCTION` node while walking up to root, we're nested
- **Escape hatch**: `@keywords internal` for edge cases that slip through

**Alternatives Considered**:
- **Comment-to-function association** (8 hours): Too complex, overkill for the problem
- **Only nesting depth**: Misses functions in lists/environments
- **Only internal tag**: Requires users to document nested functions (annoying)

**Combined Approach Best**: Nesting depth handles 90% of cases, internal tag handles rest.

**Key Insight**: False positives destroy user trust in linters. Better to under-report (miss some cases) than over-report (flag correct code). Combine heuristics (nesting depth) with escape hatches (explicit tags) for robust solution.

**Critical for Dogfooding**: rdoc lints itself with 0 false positives in exported mode. This validates the implementation works for real-world codebases.

---

## Phase 24.1: External Type Support

**Date**: January 2025
**Effort**: 3 hours
**Status**: ✅ Complete (989 tests passing)

### Design Decision: `package::class` Syntax with S7 Auto-Discovery

**Problem**: Cannot reference types from external packages. Forces workarounds:
- Use `{class_list}` - loses specificity (roclet is a list, but not all lists are roclets)
- Use `{class_any}` - disables type checking
- Use `@return` instead of `@typedReturn` - skips validation

**Solution**: `package::class` syntax with progressive enhancement - auto-discovers S7 classes when available, falls back to exact matching for S3.

**Rationale**:
- **80/20 rule**: Exact matching solves 80% of use cases immediately
- **Progressive enhancement**: Automatically gets better as ecosystem adopts S7
- **Zero maintenance**: Packages own their type information (S7 metadata)
- **Forward compatible**: Same code, better runtime behavior as packages migrate to S7
- **Type propagation**: Functions can document external return types, enabling downstream validation

**Four Options Considered**:

#### Option A: Manual Curation (DefinitelyTyped/Typeshed Style) ❌
Create a curated database:
```r
.s3_inheritance_db <- list(
  roxygen2 = list(roclet = c("roclet", "list")),
  dplyr = list(grouped_df = c("grouped_df", "tbl_df", "tbl", "data.frame"))
)
```

**Problems**:
- ❌ Requires manual curation for 20,000+ CRAN packages
- ❌ Error-prone (humans make mistakes)
- ❌ Becomes outdated (packages change inheritance)
- ❌ Doesn't scale (rdoc maintainers become bottleneck)
- ❌ Duplicates information if packages adopt S7

#### Option B: Runtime Instantiation ❌
Try to create instances and check `class()`:
```r
obj <- roxygen2::roclet()  # Instantiate at type checking time
class(obj)  # c("roclet_test", "roclet")
```

**Problems**:
- ❌ Constructors may require specific arguments
- ❌ Side effects (network calls, file I/O, database connections)
- ❌ Abstract classes can't be instantiated
- ❌ Type generation should be pure/deterministic

#### Option C: Parse Package Source Code ❌
Analyze source code to find `class()` assignments.

**Problems**:
- ❌ Misses computed classes: `class <- c(base, "Dog")`
- ❌ Misses conditional classes: `if (x) "Dog" else "Cat"`
- ❌ Doesn't work for installed packages without source
- ❌ Fragile and unreliable

#### Option D: S7 Auto-Discovery (Chosen) ✅
Try to get real S7 class, fallback to exact matching:
```r
resolve_external_type("roxygen2::roclet")
  → getExportedValue("roxygen2", "roclet")
  → If S7 class: use @parent metadata
  → Else: exact match only
```

**Advantages**:
- ✅ No manual curation needed
- ✅ No side effects
- ✅ No brittle parsing
- ✅ Works automatically when packages export S7 classes
- ✅ Graceful degradation (exact match for S3)
- ✅ Zero maintenance burden
- ✅ Scales to entire ecosystem

**Implementation**:

1. **Lexer**: Added `DOUBLE_COLON` token, rejects single `:` and `:::`
2. **Parser**: Extended grammar with `package` field in AST nodes
3. **Type resolution**: `resolve_external_type()` tries exported S7 class, falls back to `S7::new_S3_class()` wrapper
4. **Compatibility**: S7 inheritance checking when available, exact string matching otherwise

**Progressive Enhancement in Action**:

**Today** (package uses S3):
```
"roxygen2::roclet" → Not exported as S7 class
                   → S7::new_S3_class("roclet")  # No parent info
                   → Exact match only
```

**Future** (when package adopts S7):
```
"roxygen2::roclet" → Exported as S7 class
                   → <S7_class>: roclet with @parent = class_list
                   → Inheritance works! ✅
```

**Same `inst/types.rds` file, different runtime behavior.** rdoc gets smarter as packages adopt S7.

**Examples Enabled**:
```r
#' @typedReturn {roxygen2::roclet}
my_roclet <- function() roxygen2::roclet("custom")

#' @typedParam x {NULL | roxygen2::roclet}
process <- function(x) { }

#' @typedParam items {list<roxygen2::roclet>}
batch <- function(items) { }

#' @typedParam x {roxygen2::roclet | lintr::Linter}
handle_either <- function(x) { }
```

**Key Insight**: Don't try to "type the world" centrally - let packages type themselves using S7 metadata. Progressive enhancement means rdoc automatically improves as the ecosystem matures, with zero maintenance burden.

**Historical Validation**:

Research into TypeScript (2012-2014) and Python (2012-2015) shows both used manual curation initially:
- **TypeScript**: Boris Yankov started DefinitelyTyped in 2012 (one person, grew to 8000+ packages)
- **Python**: Typeshed started in 2015 with PEP 484 (community-driven, 300+ packages)

Both later evolved to **distributed types** (package-bundled):
- **TypeScript**: `package.json` `types` field
- **Python**: PEP 561 (June 2018)

**rdoc starts where TypeScript/Python ended up**: Distributed types from day 1, skipping manual curation because S7 makes it unnecessary.

**Why TypeScript/Python needed manual curation**:
- JavaScript/Python had explicit class definitions from the start
- `.d.ts`/`.pyi` files could mirror source structure
- No runtime metadata to discover

**Why rdoc doesn't**:
- S7 classes are exportable objects with @parent metadata
- Runtime discovery extracts inheritance automatically
- Packages own their type information

**Quote from DefinitelyTyped history**:
> "The TypeScript team didn't really have the resources at that point to support typing the world, and there was a problem clearly waiting to be solved."

**rdoc's answer**: Don't try to "type the world" - let packages type themselves.

---

## Phase 25.1: S7 Union Expansion in Error Messages

**Date**: January 2025
**Effort**: 4 hours
**Status**: ✅ Complete (1008 tests passing)

### Design Decision: Expand ALL S7 Unions in Expected Types

**Problem**: Error messages showed compact union names (`class_numeric`) which are less clear than their constituent types. User requested S7-style expansion for maximum clarity.

**Solution**: Expand all S7 union types in error messages:
- `class_numeric` → `class_integer | class_double`
- `class_atomic` → `class_logical | class_integer | class_double | class_complex | class_character | class_raw`
- `class_vector` → `class_logical | class_integer | class_double | class_complex | class_character | class_raw | class_expression | class_list`
- `class_language` → `class_name | class_call`

**Rationale**:
- **Clarity over brevity**: Users see exactly what types are accepted
- **S7 philosophy**: Show constituent types explicitly, not compact names
- **Package developers control verbosity**: Choose whether to use compact unions or explicit types in annotations
- **Consistent expansion**: Works recursively in nested types (e.g., `list<class_numeric>` → `list<class_integer | class_double>`)

**Implementation**:
1. **Parser-based expansion**: Parse type string to AST, expand unions, convert back to string
2. **Recursive expansion**: Handles nested types and preserves constraints
3. **`expand_s7_unions_in_ast()`**: Replaces S7 union nodes with expanded constituent types
4. **Preserves structure**: Length constraints `[n]` and element types `<T>` maintained during expansion

**Key Insight**: Type expansion should be a presentation concern, not a semantic one. The type system works with compact unions internally (`class_numeric`), but error messages show expanded forms for user clarity.

**What This Enabled**:
- Error messages show explicit constituent types
- Users understand exactly what types are compatible
- Package developers choose verbosity level (use `class_vector` or write out all 8 types)

---

## Phase 25.2: Actual Types Are Never Unions

**Date**: January 2025
**Effort**: 2 hours
**Status**: ✅ Complete (1014 tests passing)

### Design Decision: Bare Numeric Literals Infer as `class_double`

**Problem**: Literal `123` inferred as `class_numeric` (a union), showing error messages like:
```
Argument 'name' expects type 'NULL | class_character[1]'
but got 'class_integer | class_double'  ❌ WRONG - actual is a union!
```

**Root Cause**: Line 121 in `R/linter-inference.R` returned `"class_numeric"` for bare numeric literals. This is semantically incorrect - `class_numeric` is a union type, but actual/inferred types must always be concrete.

**Solution**: Changed inference to return `"class_double"` because in R, bare numeric literals without `L` suffix are **always doubles**, never integers.

**Rationale**:
```r
typeof(123)   # "double" ✅
typeof(123L)  # "integer" ✅
typeof(3.14)  # "double" ✅
```

R creates doubles by default. The inference should match R's actual behavior.

**Critical Principle**: **Actual types must always be specific concrete types, never unions.**

**Examples**:
- ✅ `123` → `class_double` (not `class_numeric`)
- ✅ `123L` → `class_integer` (not `class_numeric`)
- ✅ `TRUE` → `class_logical` (not a union)
- ✅ `"text"` → `class_character` (not a union)
- ✅ `c(1, 2)` → `class_double` (infers from first element, which is double)

**Why This Matters**:
- **Declared types** can be unions: `{class_numeric}` means "accepts integer OR double"
- **Actual types** are always concrete: `123` IS a double (not "could be integer or double")
- **Error messages** should show what was actually passed, not what category it belongs to

**Test Updates**: Updated 6 tests that incorrectly expected `class_numeric` for bare literals.

**Key Insight**: Type systems have two categories of types:
1. **Declared/Expected types**: Can be unions (describe what's acceptable)
2. **Actual/Inferred types**: Must be concrete (describe what exists)

Conflating these categories produces confusing error messages. Literals create concrete values, so they must infer to concrete types.

**What This Enabled**:
- Clear error messages: "got 'class_double'" not "got 'class_integer | class_double'"
- Correct semantics: inference matches R's actual runtime behavior
- No false union types: actual types are always what they claim to be

---

## Phase 26: Context-Aware Union Error Messages

**Date**: January 2025
**Effort**: 4 hours
**Status**: ✅ Complete (1021 tests passing, +3 new tests)

### Design Decision: Two-Scenario Error Messages

**Problem**: Union type errors needed better explanations, but initial TypeScript-style approach was inconsistent:
- `class_numeric → class_double` (partial match): "Union contains compatible types but needs narrowing"
- `class_numeric → class_character` (total mismatch): Same message, but doesn't make sense (NO members compatible)

**Research**: Compared TypeScript and Python/mypy:
- **TypeScript**: Always shows first incompatible member (consistent but potentially misleading)
- **Python/mypy**: No explanation (concise but not educational)

**Solution**: Context-aware messages that detect two distinct scenarios:

1. **Scenario 1: Partial Compatibility** (union → specific member)
   - Example: `class_numeric[1]` (integer | double) → `class_double`
   - Some members ARE compatible, some are NOT
   - Message: "Cannot narrow union to 'class_double' without type guard"
   - Educational: Explains why it fails and what's needed

2. **Scenario 2: Total Incompatibility** (union → unrelated type)
   - Example: `class_numeric[1]` (integer | double) → `class_character`
   - NO members are compatible
   - Message: Just the basic error, no explanation
   - Rationale: The mismatch is obvious, explanation adds noise

**Implementation**:
```r
analyze_union_incompatibility <- function(actual_type, expected_type) {
  # Parse union and check each member
  has_compatible <- FALSE
  has_incompatible <- FALSE

  for (member_ast in actual_ast$types) {
    if (types_compatible(member_string, expected_type)) {
      has_compatible <- TRUE
    } else {
      has_incompatible <- TRUE
    }
  }

  if (has_compatible && has_incompatible) {
    return(list(scenario = "partial", ...))  # Needs type narrowing
  } else if (has_incompatible && !has_compatible) {
    return(list(scenario = "total", ...))    # Completely wrong type
  }
}
```

**Before (Phase 25)**:
```
Argument 'x' expects type 'class_character' but got 'class_integer[1] | class_double[1]'.
  Not all union members are compatible: 'class_integer[1]' cannot be assigned to 'class_character'
```
❌ Misleading: Implies some ARE compatible (they're not)

**After (Phase 26)**:

*Scenario 1:*
```
Argument 'x' expects type 'class_double' but got 'class_integer[1] | class_double[1]'.
  Cannot narrow union to 'class_double' without type guard
```
✅ Educational: Explains the narrowing problem

*Scenario 2:*
```
Argument 'x' expects type 'class_character' but got 'class_integer[1] | class_double[1]'
```
✅ Concise: No noise when mismatch is obvious

**Validation with Large Unions**: Tested with `class_atomic` (6 members) - messages remain clear and concise regardless of union size.

**Key Insight**: Error messages should be **context-aware**. The same incompatibility pattern (union vs expected) has different root causes:
- **Partial match**: Type system limitation (needs narrowing)
- **Total mismatch**: Wrong type passed (user error)

Treating them the same produces confusing messages. Detection is simple: check if ANY union member is compatible.

**What This Enabled**:
- Clear communication: Users understand WHY their code fails
- No noise: Obvious mismatches don't get unnecessary explanations
- Educational value: Teaches about type narrowing when relevant
- Scales well: Works with unions of any size (2-8+ members)

---

## Phase 27: Arithmetic Operator Type Inference

**Date**: 2025-10-09
**Effort**: 2 hours
**Status**: ✅ Complete (1085 tests passing, +64 from Phase 26)

### Design Decision: Infer Return Types for Arithmetic Operators

**Problem**: rdoc could infer types from comparison operators (`>`, `==`) and logical operators (`&`, `|`), but not from arithmetic operators. This meant return validation couldn't catch errors in mathematical expressions:

```r
#' @typedReturn {class_character}
foo <- function(x) {
  x + 1  # ❌ Should detect: returns class_numeric, not class_character
}
```

**Solution**: Added arithmetic operator inference to `infer_argument_type()` for 7 operators: `+`, `-`, `*`, `/`, `^`, `%/%`, `%%`.

**Rationale**:
- **Consistent with existing pattern**: Already had comparison/logical operator inference
- **Return validation**: Enable `@typedReturn` validation for arithmetic expressions
- **Type propagation**: Track numeric computations through call chains
- **Division precision**: Special handling for `/` operator (always returns `class_double`)

**Critical Edge Case - Division Always Returns Double**:
```r
4L / 2L  # Returns 2.0 (double), not 2L (integer)
```

In R, division always promotes to floating-point, even when dividing integers. Inference must reflect this:
```r
# WRONG:
4L / 2L  → infers class_numeric ❌

# CORRECT:
4L / 2L  → infers class_double ✅
```

**Implementation**:
```r
infer_argument_type <- function(expr_xml, ...) {
  # Check for arithmetic operators
  if (expr_type == "OP-SLASH") {
    return("class_double")  # Division always returns double
  }

  if (expr_type == "OP-PLUS" || expr_type == "OP-MINUS" || ...) {
    left_type <- infer_argument_type(left_child, ...)
    right_type <- infer_argument_type(right_child, ...)

    if (types_compatible(left_type, "class_numeric") &&
        types_compatible(right_type, "class_numeric")) {
      return("class_numeric")
    }
  }
}
```

**Test Coverage**:
- Multiple operations: `a + b + c + d` ✅
- Mixed operators: `(a + b) * (c - d)` ✅
- Division edge case: Always returns `class_double` ✅
- Non-numeric operands: Falls back to unknown type ✅

**Key Insight**: Type inference should match R's actual runtime behavior precisely. Don't guess or approximate - `typeof(4L / 2L)` returns `"double"`, so inference must return `"class_double"`.

**What This Enabled**:
- Return validation works with arithmetic expressions
- Type errors caught in mathematical computations
- Division precision correctly tracked
- Complex nested operations supported

---

## Phase 28: Strict Ellipsis - Explicit Type Required

**Date**: 2025-10-09 17:30:26 UTC
**Effort**: 1 hour
**Status**: ✅ Complete (1085 tests passing)

### Design Decision: No Implicit `class_any` for Ellipsis

**Problem**: After implementing ellipsis support, there was an inconsistency - ellipsis parameters could be annotated three ways:

```r
#' @typedParam ... {class_any} description  ✅ Explicit type
#' @typedParam ... description               ✅ Implicit class_any (lenient)
#' @typedParam ...                           ✅ Implicit class_any (lenient)
```

This violated rdoc's **strict-by-default philosophy**. All other parameters require explicit types when using `@typedParam`, but ellipsis had a special lenient mode.

**Solution**: Removed implicit `class_any` fallback - ellipsis now requires explicit `{class_any}` annotation.

**Rationale**:
- **Consistent strictness**: All parameters require explicit types
- **Clear intent signaling**: `{class_any}` signals "I know this accepts anything"
- **No type pollution**: No implicit escape hatches
- **Better than TypeScript/Python**: rdoc can start strict from day one (no legacy baggage)

**Research: Why Implicit `any` is Problematic**

Researched TypeScript and Python's implicit `any`/`Any` philosophy:

| Issue | TypeScript | Python | rdoc Solution |
|-------|-----------|--------|---------------|
| **Type pollution** | Spreads through codebase | Spreads through codebase | No implicit `any` ✅ |
| **False security** | Code looks typed but isn't | Code looks typed but isn't | Explicit only ✅ |
| **Intent signal** | Can't distinguish placeholder from intentional | Can't distinguish | Explicit = intentional ✅ |
| **Best practice** | Strict mode (noImplicitAny) recommended | Strict mode (--strict) recommended | Strict by default ✅ |

**Key findings**:
- TypeScript's implicit `any` is widely considered problematic (2024-2025)
- Major projects (Sentry) regret starting lenient
- Modern best practice: strict by default
- TypeScript/Python keep implicit `any` only for backwards compatibility
- rdoc has no legacy constraints → can start strict from day one

**Implementation**:

```r
parse_typed_param_text <- function(text) {
  pattern <- "^(\\S+)\\s+\\{([^}]+)\\}\\s*(.*)$"
  matches <- regmatches(text, regexec(pattern, text))[[1]]

  if (length(matches) != 4) {
    stop("Invalid format: expected 'param {type} description'")
  }

  # Validate ellipsis only accepts class_any
  if (param_name == "...") {
    if (type_spec != "class_any") {
      stop(
        sprintf("Ellipsis parameter '...' only supports {class_any} type annotation. Got {%s}.\n",
                type_spec),
        "Use: @typedParam ... {class_any} description"
      )
    }
  }
}
```

**Before (Lenient)**:
```r
#' @typedParam ... description  ✅ Defaults to class_any
```

**After (Strict)**:
```r
#' @typedParam ... description  ❌ Error: Invalid format
#' @typedParam ... {class_any} description  ✅ Explicit required
```

**Error Messages**:
```r
# Missing type
#' @typedParam ... additional arguments
# Error: Invalid format: expected 'param {type} description'

# Wrong type
#' @typedParam ... {class_numeric} numbers
# Error: Ellipsis parameter '...' only supports {class_any} type annotation.
#        Got {class_numeric}.
#        Use: @typedParam ... {class_any} description
```

**Key Insight**: When designing a new type system (no legacy constraints), choose strict-by-default. TypeScript and Python regret their lenient defaults but can't change due to backwards compatibility. rdoc can learn from their mistakes and start strict.

**rdoc's Advantage**: No legacy code means we can adopt modern best practices from day one without breaking existing users.

**What This Enabled**:
- Maximum strictness - all parameters require explicit types
- Clear philosophy - no implicit escape hatches
- Better UX - users know exactly what to expect
- No surprises - consistent behavior across all parameter types

---

## Phase 29: Call Arguments S7 Formalization

**Date**: 2025-10-28 03:00:00 UTC
**Effort**: 90 minutes
**Status**: ✅ Complete (1084 tests passing)

### Design Decision: S7 Objects for All Structured Data

**Problem**: Function call arguments stored as plain lists `list(node = ..., type = ..., position = ..., name = ...)` throughout the linter pipeline. No validation, easy to make mistakes (typos in field names, wrong types).

**Solution**: Created `call_argument` S7 class with validated properties and updated all construction/access sites.

**Rationale**:
- **Type safety**: S7 validates at construction time (position must be positive integer)
- **Self-documenting**: Class definition documents expected structure
- **Better errors**: `arg@tpye` → "Did you mean `arg@type`?" vs silent NULL with `$`
- **Consistency**: Matches pattern from existing `param_type`/`function_signature` classes
- **Dogfooding**: rdoc practices what it preaches (S7 everywhere)

**Implementation**:
```r
call_argument <- S7::new_class(
  "call_argument",
  properties = list(
    node = xml_node,                  # Reusable S7 wrapper for xml2::xml_node
    type = S7::class_character,
    position = S7::class_integer,
    name = S7::class_character | NULL
  ),
  validator = function(self) {
    if (self@position < 1) return("@position must be positive")
    # ... additional validation
  }
)
```

**Changes**:
- Created `xml_node` S7 wrapper for reuse across package
- Updated `extract_arguments()` to construct S7 objects (2 sites)
- Updated `check_arguments()` to use `@` accessor (6 sites)
- Updated tests to use `@` accessor (8 assertions)

**Key Insight**: Reusable type wrappers (`xml_node`) pay dividends. Created once, used in multiple S7 classes (`call_argument`, later `variable_assignment`). Stronger typing than `class_any` but still flexible.

**What This Enabled**:
- 14 validation points that catch bugs at construction time
- Clear error messages guide developers to correct usage
- Foundation for formalizing other structured data (tokens, assignments, etc.)

---

## Phase 30: Lexer Tokens S7 Formalization

**Date**: 2025-10-28 03:30:00 UTC
**Effort**: 90 minutes
**Status**: ✅ Complete (1084 tests passing)

### Design Decision: Enum-Validated Token Types

**Problem**: Lexer produced plain lists `list(type = "IDENTIFIER", value = "class_integer", position = 15)`. Parser consumed these tokens across 53+ access sites. No validation of token type strings, easy to introduce bugs via typos.

**Solution**: Created `token` S7 class with enum validation for token type, updated lexer (9 construction sites), parser (53 access sites), and tests (58 assertions).

**Rationale**:
- **Enum validation**: Only 9 valid token types (IDENTIFIER, LANGLE, RANGLE, LBRACKET, RBRACKET, PIPE, DOUBLE_COLON, NUMBER, EOF)
- **Position validation**: Must be >= 1 (catches off-by-one errors)
- **Foundational**: Tokens are input to parser - getting them right prevents cascading bugs
- **Educational errors**: Clear validation messages when invalid token constructed

**Implementation**:
```r
token <- S7::new_class(
  "token",
  properties = list(
    type = S7::class_character,       # Validated enum
    value = S7::class_character,
    position = S7::class_integer
  ),
  validator = function(self) {
    valid_types <- c("IDENTIFIER", "LANGLE", "RANGLE", "LBRACKET",
                     "RBRACKET", "PIPE", "DOUBLE_COLON", "NUMBER", "EOF")
    if (!self@type %in% valid_types) {
      return(sprintf("Invalid token type '%s'", self@type))
    }
    if (self@position < 1) return("@position must be positive")
  }
)
```

**Changes**:
- Lexer: 9 token construction sites + 1 type check
- Parser: 53 property accesses (`$` → `@`)
- Tests: 58 assertions updated via `sed` mass replacement

**Critical Decision**: Full enum validation vs. simplified version. Chose full validation because:
1. Only 9 token types - easy to maintain
2. Catches typos immediately (`"IDENTIFER"` → error at construction)
3. Self-documents valid tokens for future contributors

**Key Insight**: For critical path code (parser runs on every type annotation), S7 validation is worth the migration effort. 100+ changes sounds scary but mostly mechanical (`$` → `@`). Test incrementally (lexer first, then parser sections) to reduce risk.

**What This Enabled**:
- Impossible to construct malformed tokens
- Parser can trust token structure without defensive checks
- Clear error messages when something goes wrong
- Complete S7 formalization of lexer → parser pipeline

---

## Phase 31: Variable Assignments S7 Formalization

**Date**: 2025-10-28 03:45:00 UTC
**Effort**: 60 minutes
**Status**: ✅ Complete (1084 tests passing)

### Design Decision: Dual-Purpose S7 Class

**Problem**: Variable assignments tracked in two phases:
1. **Extraction**: `list(line = 5, value_node = <xml>)` - node needed for later analysis
2. **Caching**: `list(line = 5, type = "class_integer")` - type inferred, node no longer needed

Different structures for same concept caused confusion. Plain lists had no validation.

**Solution**: Single S7 class with optional `value_node` field that documents both phases.

**Rationale**:
- **Unified concept**: One class represents both extraction and cached states
- **Optional node**: `value_node = xml_node | NULL` explicitly shows it's transient
- **Clear lifecycle**: Documentation explains when node is present vs NULL
- **Memory efficient**: Cache doesn't store unnecessary XML nodes
- **Validation**: Line number must be positive, type must be scalar

**Implementation**:
```r
variable_assignment <- S7::new_class(
  "variable_assignment",
  properties = list(
    line = S7::class_integer,
    type = S7::class_character,
    value_node = xml_node | NULL      # Present during extraction, NULL in cache
  ),
  validator = function(self) {
    if (self@line < 1) return("@line must be positive")
    if (length(self@type) != 1) return("@type must be scalar")
  }
)
```

**Data Flow**:
```
1. EXTRACTION: variable_assignment(line = 5L, type = "unknown", value_node = <node>)
   ↓ (infer type from node)
2. CACHING:    variable_assignment(line = 5L, type = "class_integer", value_node = NULL)
   ↓ (lookup by line)
3. LOOKUP:     Filter assignments where line < current_line, return type
```

**Changes**:
- Created S7 class with dual-purpose documentation
- Updated `extract_variable_assignments()` to construct S7 objects
- Updated linter.R caching to store S7 objects with NULL node
- Updated `infer_argument_type()` variable lookup (2 `@` accesses)
- Updated tests to construct S7 objects (14 replacements via `sed`)

**Key Insight**: Optional fields in S7 classes can document temporal state changes. The `value_node | NULL` type signature + documentation makes it clear this is a two-phase object: "node present during extraction, NULL after inference." This is clearer than having two separate structures or comments explaining when fields are present.

**What This Enabled**:
- Type-safe variable tracking across linting pipeline
- Self-documenting lifecycle (extraction → inference → caching → lookup)
- Validated line numbers prevent off-by-one bugs
- Foundation for more sophisticated flow analysis in future

---

## Phase 32: Hybrid R6+S7 Architecture for State Machines

**Date**: 2025-10-28 05:30:00 UTC
**Effort**: 4 hours of design exploration
**Status**: ✅ Design Complete (implementation pending)

### Design Decision: R6 for State Machines, S7 for Data Structures

**Problem**: After formalizing call arguments, tokens, and variable assignments with S7 (Phases 29-31), the question arose: should we formalize parser state with S7 to complete the type system formalization?

Parser state is fundamentally different from the data structures we'd formalized:
- **Data structures** (token, call_argument): Created once, immutable, passed around
- **Parser state**: Created once, mutates constantly (advance() called 15-20 times per parse)

Forcing S7 (value semantics) onto inherently mutable state created awkward designs.

**Exploration Process**: Four approaches considered:

1. **S7 wrapper with mutable environment** - Store position/tokens in environment property
   - Pro: Zero performance overhead (mutate in place)
   - Con: Validation only at construction, could still corrupt state

2. **Pure S7 with immutable state** - Thread new state through all parse functions
   - Pro: Functional purity, fully testable
   - Con: Every parse function must change, high refactor cost, breaks clean recursive structure

3. **S7 class with function properties** - Store methods as S7 properties
   - Pro: Type-safe functions, similar API
   - Con: Unusual pattern, all parse functions change (`$` → `@`)

4. **Runtime validation without S7** - Add bounds checks to existing closure
   - Pro: Minimal changes, no overhead
   - Con: Not formalized type system, just defensive programming

**None felt right.** All were forcing S7 onto the wrong problem.

**The Insight**: State machines ≠ Data structures

| Characteristic | Data Structures | State Machines |
|----------------|-----------------|----------------|
| **Mutability** | Immutable (value semantics) | Mutable (reference semantics) |
| **Lifecycle** | Created → passed → read | Created → mutated repeatedly |
| **Right tool** | S7 (type-safe values) | R6 (encapsulated mutable objects) |
| **Examples** | token, call_argument, AST nodes | Parser, linter cache |

**Solution**: Hybrid architecture - use both R6 and S7 for their strengths.

**Architecture**:
```
Data Layer (S7 - Immutable):
├── token                    # Lexer output
├── call_argument            # Function call args
├── variable_assignment      # Variable tracking
├── function_signature       # Type signatures
└── AST nodes               # Type syntax AST

State Machines (R6 - Mutable):
├── ParserState             # Token stream parser
└── [Future] LinterFileCache # Multi-pass type cache

Interaction Contract:
- R6 constructors validate S7 inputs
- R6 methods return S7 outputs
- Type-safe boundaries enforced
```

**R6 Implementation**:
```r
ParserState <- R6::R6Class(
  "ParserState",
  private = list(
    tokens = NULL,      # List of S7 token objects
    position = NULL,

    check_bounds = function() {
      if (private$position < 1 || private$position > length(private$tokens)) {
        stop(sprintf("Position %d out of bounds", private$position))
      }
    }
  ),

  public = list(
    initialize = function(tokens) {
      # Validate S7 inputs
      if (!all(vapply(tokens, function(t) S7::S7_inherits(t, token), logical(1)))) {
        stop("All tokens must be S7 token objects")
      }
      private$tokens <- tokens
      private$position <- 1L
    },

    current = function() {
      private$check_bounds()
      private$tokens[[private$position]]  # Returns S7 token
    },

    advance = function() {
      if (private$position < length(private$tokens)) {
        private$position <- private$position + 1L
      }
      private$check_bounds()
      private$tokens[[private$position]]  # Returns S7 token
    }
  )
)

# S7 wrapper for type-safe composition
parser_state <- S7::new_S3_class("ParserState")
```

**Benefits**:
- ✅ **Semantic correctness**: R6 designed for mutable state machines
- ✅ **Zero performance overhead**: Mutate in place, no object creation
- ✅ **Encapsulation**: Private fields protect internal state
- ✅ **Type-safe boundaries**: R6 validates S7 inputs, returns S7 outputs
- ✅ **Zero API changes**: Parser interface stays `parser$current()`
- ✅ **Honest architecture**: Acknowledges different needs (data vs. state)

### Strategic Decision: Defer R6 Typing Support

**Question raised**: If rdoc uses R6 internally, should it support typing R6 method signatures?

**Three options considered**:

**Option A: Use R6 internally, don't type it yet**
- Ship 1.0 focused on typing regular R functions (95% of use cases)
- Internal R6 remains untyped (simple, well-tested code)
- Add R6 typing in 2.0 if user demand emerges

**Option B: Full R6 support now**
- Type R6 methods with `@typedParam`/`@typedReturn`
- Handle R6 semantics (self, private, super, inheritance)
- Effort: 2-3 months additional development
- Risk: Delays shipping core functionality

**Option C: Minimal R6 support now**
- Basic method typing (skip inheritance, private methods)
- Covers 80% of R6 use cases
- Effort: 2-3 weeks
- Risk: Moderate scope increase

**Decision: Option A** - Use R6 internally, defer typing support.

**Rationale**:
1. **Focus on core value**: Regular function typing is primary use case
2. **Ship faster**: Get user feedback before expanding scope
3. **Validate demand**: See if users ask for R6 typing
4. **Internal R6 is simple**: ParserState ~100 lines, low risk
5. **Pragmatic**: Right tool for the job (R6 for state), but don't over-commit

**User perspective**: "rdoc types my functions using roxygen2 tags. It uses R6 internally for performance, but doesn't type R6 yet."

**Future path**: If users request R6 typing and rdoc gains traction, add minimal R6 support in 2.0.

**Documentation**: Added to CLAUDE.md:
```markdown
## R6 Usage

rdoc uses R6 internally for stateful objects (e.g., ParserState) while using S7
for data structures. R6 provides the right semantics for mutable state machines.

**Architecture**: R6 state machines validate S7 inputs and return S7 outputs,
creating type-safe boundaries.

**Future**: R6 method typing support planned for 2.0, pending user demand.
```

**Key Insight**: Not everything should be S7. Choosing the right tool for the problem is more important than architectural purity. State machines (mutable, imperative) need different abstractions than data structures (immutable, declarative). R6 and S7 complement each other perfectly when used for their intended purposes.

This mirrors mature ecosystems:
- **Rust**: Immutable by default, but has `mut` for when you need it
- **Haskell**: Pure functional, but has `IORef` for mutable state
- **Clojure**: Immutable data, but has `atoms` for coordinated state

rdoc's hybrid R6+S7 architecture follows this pattern: immutable data (S7) with mutable state machines (R6) when semantically appropriate.

**What This Enabled**:
- Clean separation between data and state concerns
- Performance-optimized state machines without S7 overhead
- Foundation for future stateful components (linter cache formalization)
- Honest architecture that doesn't force wrong abstractions
- Clear upgrade path for R6 typing if demand emerges

---

## Phase 33: Namespace Import Abstraction (Box Module Formalization)

**Date**: 2025-10-28 13:35:00 UTC
**Effort**: 3 hours of design exploration
**Status**: ✅ Design Complete (implementation pending)

### Design Decision: Generic Namespace Import vs. Box-Specific Import

**Problem**: After formalizing tokens, call arguments, and variable assignments with S7 (Phases 29-31), the next opportunity was box module imports. These were stored as plain lists with 6 fields (module_path, module_name, alias, imports, attach_all, line).

Initial approach was to create `box_import_info` class, but deeper analysis revealed fundamental naming and abstraction questions.

**The Naming Journey**: Four critical questions emerged:

**Question 1: What about function-level aliasing?**
- Initial concern: Does `alias` property include function-level aliases?
- Investigation: rdoc only supports module-level aliasing (`m = mod/math`)
- Function-level aliasing (`mod/math[my_add = add]`) not supported by box
- **Decision**: `alias` is module-level only

**Question 2: Functions or Objects?**
- Original property name: `imports` (too ambiguous)
- Alternative: `selected_functions` (too narrow - box can export data, classes, enums)
- **Decision**: `selected_objects` - accurate for any exported object

**Question 3: Module-specific or Generic?**
- Initial class name: `box_import_info` or `box_module_import`
- Discovery: Box supports **both** file-based modules AND package imports:
  - File modules: `box::use(mod/math)` → rdoc currently handles
  - Packages: `box::use(dplyr)` → rdoc doesn't handle yet
- **Realization**: "module" in class name is too narrow

**Question 4: Box-specific or Concept-focused?**
- Key insight: rdoc already parses `library()` calls separately (R/linter-check.R:288-317)
- Both create **namespace imports** with similar structure:
  - `library(dplyr)` → package attached to global namespace
  - `box::use(dplyr)` → package imported with qualified access
  - `box::use(mod/math)` → module imported with qualified access
- **Architecture choice**: Should we unify these or keep separate?

**The Abstraction Debate**:

Two philosophies considered:

**Philosophy A: Implementation-Focused**
- Keep `box_import` for box::use() only
- `library()` handled separately (current architecture)
- PRO: Matches current code structure
- CON: Duplicates concept, misses abstraction

**Philosophy B: Concept-Focused**
- Create generic `namespace_import` for all mechanisms
- Unify `library()`, `require()`, and `box::use()`
- PRO: Correct abstraction, future-proof
- CON: Bigger architectural change

**Solution**: Generic abstraction with pragmatic scope.

**Architecture**:
```r
namespace_import <- S7::new_class(
  "namespace_import",
  properties = list(
    source_type = S7::class_character,        # "package" | "module"
    source_path = S7::class_character,        # "dplyr" or "mod/math"
    namespace_name = S7::class_character,     # Derived from source_path
    namespace_alias = S7::class_character | NULL,  # Module/package alias
    selected_objects = S7::class_character | NULL, # Selective imports
    attach_all = S7::class_logical,           # Attach to namespace
    import_mechanism = S7::class_character,   # "library" | "require" | "box"
    line = S7::class_integer
  ),
  validator = function(self) {
    # Validate source_type
    if (!self@source_type %in% c("package", "module")) {
      return("source_type must be 'package' or 'module'")
    }

    # Validate import_mechanism
    if (!self@import_mechanism %in% c("library", "require", "box")) {
      return("import_mechanism must be 'library', 'require', or 'box'")
    }

    # library/require constraints
    if (self@import_mechanism %in% c("library", "require")) {
      if (!is.null(self@namespace_alias)) {
        return("library/require do not support aliasing")
      }
      if (!is.null(self@selected_objects)) {
        return("library/require do not support selective imports")
      }
      if (!self@attach_all) {
        return("library/require always attach all exports")
      }
    }

    # Box selective vs attach_all mutual exclusion
    if (self@import_mechanism == "box") {
      if (!is.null(self@selected_objects) && self@attach_all) {
        return("Cannot have both selective imports and attach_all")
      }
    }

    # Modules only via box
    if (self@source_type == "module" && self@import_mechanism != "box") {
      return("Modules can only be imported via box")
    }

    NULL
  }
)
```

**Business Rules Encoded**:

1. **Mutual exclusion** (box only): `selected_objects` XOR `attach_all`
2. **Module derivation**: `namespace_name` from last component of `source_path`
3. **Mechanism constraints**:
   - `library/require`: Always `attach_all=TRUE`, no aliasing, no selection
   - `box`: Supports all features
4. **Source type constraint**: Modules only importable via box
5. **Positive line**: Source location must be positive integer

**Comparison Table**:

| Feature | `library(dplyr)` | `box::use(dplyr)` | `box::use(mod/math[add])` |
|---------|------------------|-------------------|---------------------------|
| source_type | "package" | "package" | "module" |
| source_path | "dplyr" | "dplyr" | "mod/math" |
| namespace_alias | NULL | NULL or "dp" | NULL or "m" |
| selected_objects | NULL | NULL | ["add"] |
| attach_all | TRUE | FALSE | FALSE |
| import_mechanism | "library" | "box" | "box" |

**Implementation Scope**:

**Phase 33 (Current)**:
- Create `namespace_import` class (generic name)
- Only construct from `box::use()` statements (current capability)
- `import_mechanism` always "box"

**Future Phase**:
- Also construct from `library()` and `require()` calls
- Unify type loading pipeline
- Enable cross-mechanism analysis

**Key Insight**: Choosing the right abstraction requires looking beyond current implementation to the underlying concept. "Box import" is an implementation detail; "namespace import" is the concept. By naming the class generically but scoping implementation pragmatically, we achieve both correctness and practicality.

The discussion revealed that great naming comes from:
1. **Understanding semantics** (module-level vs function-level aliasing)
2. **Precision** (objects vs functions)
3. **Future-proofing** (modules AND packages)
4. **Abstraction** (namespace concept unifies library() and box::use())

**What This Enabled**:
- Type-safe box module/package imports with validation
- Foundation for unified namespace import handling
- Clear semantics for aliasing, selection, and attachment
- Future path to formalize library() calls with same abstraction
- Honest architecture that acknowledges the underlying concept

---

## Phase 34: types.rds Redesign - Versioned Export Metadata

**Date**: 2025-10-29 03:30:00 UTC
**Status**: 📋 Design Phase (Implementation Pending)

### Design Decision: Versioned Container with Export Type Hierarchy

**Problem**: Current types.rds format lacks future-proofing:
- No format versioning (can't evolve without breaking changes)
- No package metadata (can't debug or trace issues)
- Only stores functions (R packages also export classes, data objects)
- Plain list structure (no extensibility path)

**Solution**: Create comprehensive export metadata format with three-level structure:

1. **Container**: `type_metadata` - Top-level wrapper with versioning and package info
2. **Export hierarchy**: `exported_item` base class with subclasses:
   - `exported_function` - Function signatures (current functionality)
   - `exported_class` - Class constructors and properties (Phase B)
   - `exported_data` - Data objects with types (Phase C)
3. **Incremental phases**: Add container first (Phase A), then extend with classes/data

**Rationale**:

**Why versioned container:**
- Enables format evolution without breaking old readers
- Stores rdoc version, timestamp, package info for debugging
- Self-documenting structure (format_version field)
- Migration path for future changes (v1 → v2 conversion logic)

**Why export hierarchy:**
- R packages export more than functions (classes, data, constants)
- S7 classes need both constructor signature and property types
- Data objects can be typed via @typedReturn
- Single namespace mirrors R's actual export model

**Why incremental phases:**
- Phase A (immediate): Just add container, no new functionality
- Phase B (later): Add S7 class extraction
- Phase C (later): Add data object typing
- Reduces risk, validates design at each step

**Seven Key Design Decisions**:

1. **File separation**: Keep `type-metadata.R` (internal) and `type-exports.R` (serialization) separate
2. **Type storage**: Convert S7 property types to strings for consistency
3. **Scope**: Only typed exports in types.rds, linter enforces completeness
4. **Redundancy**: Keep both S7 class type and string export_type field for stability
5. **Re-exports**: Exclude from types.rds (get types from origin package)
6. **Phase A scope**: Only add container, no class/data support yet
7. **Constructor vs properties**: Constructors from @typedParam tags, properties auto-extracted from S7::new_class()

**Key Insight**: S7 classes ARE their constructors, so they're documented as functions with @typedParam/@typedReturn. This means constructor signatures come from existing roclet logic (no auto-generation needed), while properties are auto-extracted from class definitions. Both serve different validation purposes: constructor signature validates instantiation calls, properties validate property access.

**Format Evolution Strategy**: Format v1 stores types as strings (current approach). Future format v2 could store parsed AST instead, with migration logic converting strings to AST at load time. Versioning enables this kind of breaking change without ecosystem disruption.

**What This Enables**:

**Immediate (Phase A - container only):**
- Format versioning for future evolution
- Package metadata for debugging (rdoc version, timestamp)
- Migration path for breaking changes
- Self-documenting serialization format

**Near-term (Phase B - S7 classes):**
- Type check class instantiation: `Person(name = "Alice", age = 30)`
- Validate property access: `person@name`
- Ensure property types match class definitions
- Catch class-related type errors at lint time

**Long-term (Phase C - data objects):**
- Type data object usage: `iris` is `data.frame[150,5]`
- Validate column access and operations
- Document dataset types explicitly
- Complete coverage of package exports (functions + classes + data)

**No Backward Compatibility Needed**: Since rdoc hasn't released yet, we can redesign types.rds format cleanly without migration burden from v0 (plain list) to v1 (versioned container).

**Related Documentation**: See PHASE_34_TYPES_RDS_REDESIGN.md for complete design decisions and implementation plan.

---

## Phase 34B: S7 Class Support - Property Extraction

**Date**: 2025-10-29 13:57:00 UTC
**Status**: ✅ Complete (45 tests passing, 1125 total)

### Design Decision: AST-Based Property Extraction with Full Type Names

**Problem**: Phase 34A created the container structure, but types.rds only stored functions. R packages also export S7 classes, and we needed a way to extract and store class metadata including properties.

**Solution**: Parse S7::new_class() calls using R's AST to extract properties and convert S7 class objects to strings while preserving full type names.

**Key Implementation Details**:

1. **Detection**: Check if block contains `S7::new_class` or `new_class` pattern
2. **Constructor from Tags**: Extract constructor signature from @typedParam/@typedReturn (reuses existing logic)
3. **Properties from AST**: Parse `properties = list(...)` argument to extract property types
4. **Full Name Preservation**: Convert `class_character` → `"class_character"` (NOT `"character"`)
5. **Dual Storage**: Store both constructor signature (for instantiation validation) and properties (for future property access validation)

**Rationale**:

**Why AST parsing:**
- Robust against formatting variations
- Accurate extraction without regex fragility
- Consistent with rdoc's existing parsing approach
- Handles both `S7::new_class` and `new_class` patterns

**Why preserve full type names:**
- `class_character` ≠ base `character` (S7 has validation, coercion rules)
- Maintains S7 type system distinctions
- Consistent with how we store all types in rdoc
- Future-proof: preserves full type information for advanced validation

**Why separate constructor and properties:**
- Constructor signature validates instantiation: `Person(name = "Alice", age = 30)`
- Properties enable future property access validation: `person@name` (deferred to later phase)
- Constructor parameters ≠ properties (constructors may have extra params like `validate = TRUE`)

**Key Insight**: S7 classes ARE their constructors, so they're documented as functions with @typedParam/@typedReturn. This means constructor signatures come from existing roclet logic (no auto-generation needed), while properties are auto-extracted from the S7::new_class() definition. Both pieces of metadata serve different validation purposes.

**Example Transformation**:

```r
# Input: S7 class definition
#' Person class
#' @typedParam name {class_character[1]} Person's name
#' @typedParam age {class_numeric[1]} Person's age
#' @typedReturn {Person} A new Person instance
#' @export
Person <- S7::new_class(
  "Person",
  properties = list(
    name = class_character,
    age = class_numeric
  )
)

# Output in types.rds:
type_metadata(
  exports = list(
    "Person" = exported_class(
      name = "Person",
      export_type = "class",
      class_system = "S7",
      constructor_signature = function_signature(
        params = list(
          name = param_type(type = "class_character[1]", ...),
          age = param_type(type = "class_numeric[1]", ...)
        ),
        return = return_type(type = "Person", ...)
      ),
      properties = list(
        name = param_type(type = "class_character", description = ""),
        age = param_type(type = "class_numeric", description = "")
      )
    )
  )
)
```

**What This Enables**:

**Immediate (Phase 34B):**
- S7 classes stored in types.rds alongside functions
- Property types captured with full S7 type names
- Constructor validation works via constructor_signature
- Foundation for property access validation

**Near-term (Future Phase):**
- Property access validation: `person@name` type checking
- Inheritance validation: Check property access on parent classes
- Property type mismatches caught at lint time

**Scope Boundaries**:

**Included in Phase 34B:**
- ✅ S7 class detection and property extraction
- ✅ Constructor signature from @typedParam/@typedReturn
- ✅ Full type name preservation (class_character, not character)
- ✅ Basic property list extraction
- ✅ Parent class extraction (parsed but not yet used)

**Deferred to Future Phases:**
- ❌ Property access validation (`person@name` linting)
- ❌ R6 class support
- ❌ S3/S4 class support
- ❌ Property defaults extraction
- ❌ Property validator extraction

**Implementation Approach**:

1. **Detection**: `is_s7_class_definition()` checks for S7::new_class pattern
2. **Extraction**: `extract_s7_class_info()` orchestrates metadata gathering
3. **Property Parsing**: `extract_s7_properties()` walks AST to find `properties = list(...)`
4. **Type Conversion**: `s7_class_expr_to_string()` converts S7 class objects to strings
5. **Wrapping**: `roclet_output` detects S7 class metadata and wraps in `exported_class`

**Test Coverage**: 45 new tests in test-s7-class-extraction.R covering:
- Type string conversion (symbols, qualified names, unions)
- Property extraction (simple, empty, missing)
- Class detection (with/without S7:: prefix)
- Full integration (roclet processing, output generation)
- Mixed exports (functions + classes in same package)

**Related Documentation**: See PHASE_34B_S7_CLASS_SUPPORT.md for detailed implementation plan.

### Pending Design Discussion: Scope Tracking for new_class()

**Date**: 2025-10-29 (Identified during test refactoring)

**Issue**: Current detection logic in `is_s7_class_definition()` matches ANY `new_class()` call, not just S7's. This could create false positives if other packages define functions named `new_class()`.

**Current Implementation**:
```r
is_s7_class_definition <- function(block) {
  # Method 1: Check if evaluated value is S7 class object
  if (inherits(block$object$value, "S7_class")) return(TRUE)

  # Method 2: Check for "new_class" pattern in source
  if (grepl("new_class", deparse(block$call))) return(TRUE)
}
```

**The Problem**: Method 2 has no scope tracking:
- Matches `new_class(...)` from any package
- Matches `MyPackage::new_class(...)` from non-S7 packages
- Could incorrectly identify classes from other OOP systems

**Why Not Fixed Yet**:
- Low priority: S7's `new_class()` is unique enough that collisions are unlikely
- Method 1 already provides correct detection for evaluated objects (used during real roclet execution)
- Method 2 mainly supports testing scenarios with unevaluated expressions
- No false positives observed in practice

**Potential Solutions** (if this becomes a problem):
1. **Strict detection**: Only match `S7::new_class` (but breaks code using `library(S7); new_class(...)`)
2. **Namespace tracking**: Check if S7 is imported in the file scope
3. **Evaluated-only**: Remove Method 2, require S7 to be loadable during roclet execution

**Decision**: Document but don't fix. The dual-method approach (evaluated object + pattern matching) provides good coverage, and real-world usage goes through Method 1. If false positives emerge, revisit with namespace tracking solution.

**Related Code**: R/roclet-types.R:218-240 (is_s7_class_definition)

---

## Cross-Cutting Insights

### 1. Leverage Existing Infrastructure

**Pattern**: Reuse well-designed systems instead of reimplementing.

**Examples**:
- Phase 12.1: Use S7's compatibility checking, not string comparisons
- Phase 14: Use S7's union validation, not custom logic
- Phase 21: Use AST parsing, not custom DSL

**Benefit**: ~60% less code, automatic improvements from upstream, fewer bugs.

---

### 2. Parse, Don't Validate with Regex

**Pattern**: When validation gets complex, write a parser.

**Tipping Point**: 12+ regexes with brittle edge cases (Phase 13).

**Result**: 250-line parser replaced scattered regexes, better errors, easier to extend.

**Lesson**: If you're writing complex regex with lookaheads/lookbehinds, you probably need a parser.

---

### 3. Deliver Iteratively

**Pattern**: 80/20 rule - deliver 80% of value with 20% of effort, iterate if needed.

**Examples**:
- Phase 24.1: Exact matching (3 hours) solves immediate problem, inheritance later (3-5 days)
- Phase 22: Three modes (8 hours) provides clear upgrade path

**Benefit**: Fast feedback, validate assumptions before heavy investment.

---

### 4. Opinionated Design Reduces Cognitive Load

**Pattern**: Make decisions for users when there's a clearly better choice.

**Examples**:
- NULL must come first in unions (matches S7 convention)
- `[]` for length, `<>` for element type (zero ambiguity)
- Exported mode as recommended default for packages

**Lesson**: "Convention over configuration" applies to type systems too. Fewer choices = easier to learn.

---

### 5. False Positives Destroy Trust

**Pattern**: Under-report rather than over-report.

**Example**: Phase 23 nesting detection - better to miss edge cases than flag correct code.

**Lesson**: Users tune out linters that cry wolf. Precision matters more than recall for linters.

---

## Next Phase Updates

When implementing future phases, add entries following this template:

```markdown
## Phase X: [Feature Name]

**Date**: [Month Year]
**Effort**: [Hours/Days]
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

---

## Appendix: Historical Research

### TypeScript and Python Type System Evolution (2012-2015)

**Research Method**: Multiple web searches, cross-referenced sources
**Date**: January 2025

This research informed rdoc's design decisions, particularly for external type support (Phase 24.1).

#### TypeScript Timeline (2012-2014)

| Year | Event |
|------|-------|
| **2010** | Anders Hejlsberg starts development at Microsoft |
| **Oct 2012** | TypeScript 0.8 public release |
| **2012** | Boris Yankov starts DefinitelyTyped (immediately!) |
| **Nov 2012** | TypeScript 0.8.1 - source maps, JSDoc support |
| **Dec 2012** | TypeScript 0.8.2 - usability improvements |
| **Apr 2014** | TypeScript 1.0 - stable release |

**Key Decisions**:
1. **Structural typing** - Based on JavaScript's duck typing patterns
2. **Declaration files** - `.d.ts` format from day 1
3. **Explicit inheritance** - `class Dog extends Animal` in declarations
4. **DefinitelyTyped** - Community-driven manual curation
5. **Microsoft endorsement** - Anders promoted DefinitelyTyped in every talk

**Coverage Growth**:
- 2012: ~50 packages
- 2014: ~500 packages
- Today: 8,000+ packages

**Quote from Anders Hejlsberg** (TypeScript creator):
> "TypeScript's structural type system was designed based on how JavaScript code is typically written. Because JavaScript widely uses anonymous objects like function expressions and object literals, it's much more natural to represent the kinds of relationships found in JavaScript libraries with a structural type system instead of a nominal one."

**DefinitelyTyped Origin** (Boris Yankov):
> "The repository wasn't complicated; it was just a folder with subfolders underneath; each folder representing a project - one for jQuery, one for jQuery UI, one for Knockout. Boris had laid simple but dependable foundations and Definitely Typed had been born."

#### Python Timeline (2012-2015)

| Year | Event |
|------|-------|
| **2012** | Jukka Lehtosalo starts mypy (PhD at Cambridge) |
| **2013** | Guido van Rossum meets Jukka at PyCon, suggests rewrite |
| **Sep 2014** | PEP 484 created (Guido, Jukka, Łukasz) |
| **May 2015** | PEP 484 accepted |
| **Sep 2015** | Python 3.5 released with type hints |
| **2015-2016** | Typeshed repository started |

**Key Decisions**:
1. **Gradual typing** - Optional, not mandatory
2. **Stub files** - `.pyi` format specified in PEP 484
3. **Explicit inheritance** - `class Dog(Animal)` in stubs
4. **Typeshed** - Community-driven manual curation
5. **External checker** - mypy runs separately from Python

**Coverage Growth**:
- 2015-2016: ~50 packages
- 2018: PEP 561 (distributed types)
- Today: 300+ packages in typeshed

**PEP 484 Quote**:
> "This proposal aims to provide a standard syntax for type annotations, opening up Python code to easier static analysis and refactoring, potential runtime type checking, and (perhaps, in some contexts) code generation utilizing type information."

**Mypy Origin** (from documentation):
> "Mypy was started by Jukka Lehtosalo during his Ph.D. studies at Cambridge around 2012. Initially, Mypy started as a standalone variant of Python with seamless dynamic and static typing. Following a suggestion by Guido van Rossum, Mypy was rewritten to use annotations instead, making it a static type checker for regular Python code."

**Typeshed Scaling Challenge** (PEP 484):
> "If the package can be released publicly, it can be added to typeshed. However, this does not scale and becomes a burden on the maintainers of typeshed."

**They knew it didn't scale, but it was the best option available at the time.**

#### Common Patterns

Both TypeScript and Python:
1. ✅ Used explicit declarations (.d.ts/.pyi) from day 1
2. ✅ Stored inheritance in declaration files
3. ✅ Accepted manual curation as necessary evil
4. ✅ Started with centralized repos (DefinitelyTyped/Typeshed)
5. ✅ Evolved to distributed types later
6. ✅ Shipped with limited coverage, iterated
7. ✅ Community-driven scaling

**Why this worked**:
- JavaScript and Python had **explicit class definitions**
- Declarations could **mirror source structure**
- Type checkers could **parse declarations**
- Large communities provided **curation labor**

#### Critical Differences: R vs JavaScript/Python

| Factor | JavaScript/Python | R (S3) | R (S7) |
|--------|------------------|--------|--------|
| **Class system** | First-class from start | Strings only | First-class (2023+) |
| **Explicit definitions** | Yes | No | Yes |
| **Mirrorable structure** | Yes | No | Yes |
| **When available** | 1995/2012 | 1993-2023 | 2023+ |

**The constraint**: R historically didn't have what TypeScript/Python had (formal class system)

**The opportunity**: R now has S7 (formal classes with metadata)

**The decision**: Use S7 auto-discovery instead of manual curation

#### What rdoc Learned from History

**Adopt**:
- ✅ Gradual typing (three-level mode system)
- ✅ Optional, not mandatory
- ✅ Package-bundled types (inst/types.rds)
- ✅ Progressive enhancement
- ✅ Ship early with limited features

**Adapt**:
- ✅ Skip manual curation (S7 makes it unnecessary)
- ✅ Auto-discovery over central database
- ✅ Start distributed (where TS/Python ended up)
- ✅ Let ecosystem mature (S7 adoption)

**Avoid**:
- ❌ Centralized manual curation (doesn't scale for R)
- ❌ Waiting for perfect coverage (ship with what works)
- ❌ Trying to solve S3's dynamism (accept limitations)
- ❌ Reimplementing what S7 provides (leverage existing)

#### Research Sources

**TypeScript**:
- TypeScript Blog (devblogs.microsoft.com/typescript)
- "Definitely Typed: The Movie" (johnnyreilly.com)
- TypeScript Documentation (typescriptlang.org)
- TypeScript Wikipedia entry
- DefinitelyTyped GitHub repository

**Python**:
- PEP 484 - Type Hints (peps.python.org)
- PEP 483 - Theory of Type Hints
- PEP 561 - Distributing and Packaging Type Information
- mypy documentation (mypy.readthedocs.io)
- Typeshed GitHub repository
- "The state of mypy" (LWN.net)

**Cross-references**: Multiple sources confirmed the same historical facts (release dates, key people, design decisions).

---

## Document Metadata

**Created**: January 2025
**Last Updated**: 2025-11-09 20:25:56 UTC (Phase 35 - Length Constraint Removal)
**Total Phases Documented**: 28 major phases
**Maintained By**: rdoc contributors
**Purpose**: Technical reference for understanding rdoc's evolution

---

## Phase 35: Removal of Length Constraint Support

**Date**: 2025-11-09
**Effort**: 1 day
**Status**: ✅ Complete (1026 tests passing)

### Design Decision: Remove Scalar/Length Constraint Syntax

**Problem**: The `[N]` syntax for length constraints (e.g., `numeric[1]` for scalars) fought against R's vectorized nature and created user confusion.

**Solution**: Removed all length constraint support, keeping only element type constraints `<type>` for generics.

**Rationale**:
- **R is fundamentally vectorized**: Fighting this creates friction with R's core design philosophy
- **Incomplete implementation**: Static analysis couldn't reliably check length for constructed vectors (`c(1, 2)`)
- **Implementation complexity**: Required `@length_constraint` property, `actual_length` parameter threading, and special-case logic throughout the codebase
- **User confusion**: Scalars work for literals but not expressions - inconsistent behavior is worse than no behavior
- **Not truly R-like**: R doesn't distinguish scalars from length-1 vectors at the type level

**What Was Removed**:
- `[N]` syntax for length constraints (e.g., `numeric[1]`, `character[5]`)
- `@length_constraint` property from `type_ref` S7 class
- `check_length_constraint()` function
- `actual_length` parameter from `types_compatible()`
- All length constraint parsing logic from `parse_type_constraints()`
- 22+ test files updated, `test-linter-bracket-syntax.R` → `test-element-types.R`

**What Was Kept**:
- Element type constraints: `list<integer>` for generic types
- All other type system features (unions, external types, NULL safety, etc.)

**Key Insight**: Sometimes removing a feature makes the system better. R's vectorization is a core strength - type checking should embrace it, not fight it. Accept imprecision on vector lengths rather than provide inconsistent behavior.

**What This Enabled**:
- Cleaner, simpler type system aligned with R's philosophy
- Removed 500+ lines of constraint-checking code
- Reduced cognitive load for users (one less syntax to learn)
- Better alignment with how R developers actually think about types

**Migration Path**: Users should:
- Remove `[N]` from all type annotations
- Accept that `numeric` means "numeric vector of any length"
- Use prose documentation for scalar requirements (just like base R)
- Rely on runtime checks for length validation when needed

---
