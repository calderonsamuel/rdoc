# Tests for three-level mode system
# Modes: "lenient" (default), "exported" (public API), "strict" (all functions)

# Basic linter creation (merged from test-linter.R) ----

test_that("type_consistency_linter can be created", {
  linter <- type_consistency_linter()

  expect_s3_class(linter, "linter")
})

# Phase 22: Mode Parameter Design ----

test_that("type_consistency_linter accepts mode parameter", {
  linter_lenient <- type_consistency_linter(mode = "lenient")
  expect_s3_class(linter_lenient, "linter")

  linter_exported <- type_consistency_linter(mode = "exported")
  expect_s3_class(linter_exported, "linter")

  linter_strict <- type_consistency_linter(mode = "strict")
  expect_s3_class(linter_strict, "linter")
})

test_that("default mode is lenient", {
  linter_default <- type_consistency_linter()
  expect_s3_class(linter_default, "linter")
})

test_that("invalid mode throws error", {
  expect_error(
    type_consistency_linter(mode = "invalid"),
    "should be one of"
  )
})

# Mode: lenient ----

test_that("lenient mode: ignores untyped functions", {
  skip_if_not_installed("lintr")

  code <- "
    #' Calculate sum
    #' @param x A number
    #' @param y Another number
    calculate <- function(x, y) x + y
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(mode = "lenient"))

  expect_equal(length(lints), 0)
})

test_that("lenient mode: validates typed functions", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam x {class_numeric}
    #' @typedReturn {class_numeric}
    process <- function(x) x * 2

    process('text')
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(mode = "lenient"))

  expect_gte(length(lints), 1)
  expect_true(any(grepl("integer.*double.*character", vapply(lints, function(l) l$message, character(1)))))
})

test_that("lenient mode: skips unknown types silently", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam x {class_numeric}
    process <- function(x) x * 2

    foo <- function() 42
    result <- foo()
    process(result)
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(mode = "lenient"))

  expect_equal(length(lints), 0)
})

test_that("lenient mode: allows exported functions without types", {
  skip_if_not_installed("lintr")

  code <- "
    #' Public function
    #' @export
    public_add <- function(x, y) x + y
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(mode = "lenient"))

  expect_equal(length(lints), 0)
})

# Mode: exported ----

test_that("exported mode: requires types on exported functions", {
  skip_if_not_installed("lintr")

  code <- "
    #' Public API function
    #' @export
    public_add <- function(x, y) x + y
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(mode = "exported"))

  expect_gte(length(lints), 3)  # x, y, return
  messages <- vapply(lints, function(l) l$message, character(1))
  expect_true(any(grepl("missing type annotation", messages, ignore.case = TRUE)))
})

test_that("exported mode: allows internal functions without types", {
  skip_if_not_installed("lintr")

  code <- "
    #' Internal helper
    .internal_multiply <- function(a, b) a * b
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(mode = "exported"))

  expect_equal(length(lints), 0)
})

test_that("exported mode: validates typed exported functions", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam x {class_numeric}
    #' @typedReturn {class_numeric}
    #' @export
    process <- function(x) x * 2

    process('text')
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(mode = "exported"))

  expect_gte(length(lints), 1)
  expect_true(any(grepl("integer.*double.*character", vapply(lints, function(l) l$message, character(1)))))
})

test_that("exported mode: accepts fully typed exported function", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam x {class_numeric}
    #' @typedParam y {class_numeric}
    #' @typedReturn {class_numeric}
    #' @export
    add <- function(x, y) x + y
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(mode = "exported"))

  expect_equal(length(lints), 0)
})

test_that("exported mode: handles mixed exported and internal functions", {
  skip_if_not_installed("lintr")

  code <- "
    #' Public function (needs types)
    #' @export
    public_add <- function(x, y) x + y

    #' Internal helper (types optional)
    .internal_multiply <- function(a, b) a * b

    #' Typed exported (complete, should pass)
    #' @typedParam z {class_numeric}
    #' @typedReturn {class_numeric}
    #' @export
    good_fn <- function(z) z * 2
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(mode = "exported"))

  # Should only flag public_add (3 lints), not .internal_multiply or good_fn
  expect_gte(length(lints), 3)
  messages <- vapply(lints, function(l) l$message, character(1))

  # All lints should reference public_add
  expect_true(all(grepl("public_add|Parameter '[xy]'", messages)))

  # Should NOT reference internal_multiply or good_fn
  expect_false(any(grepl("internal_multiply|good_fn|Parameter 'z'", messages)))
})

test_that("exported mode: detects @export with extra whitespace", {
  skip_if_not_installed("lintr")

  code <- "
    #' Function with whitespace
    #'   @export
    exported_fn <- function(x) x
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(mode = "exported"))

  expect_gte(length(lints), 2)  # x and return
})

test_that("exported mode: does not trigger on @exportS3method", {
  skip_if_not_installed("lintr")

  code <- "
    #' S3 method (not a public export in the same way)
    #' @exportS3method
    print.myclass <- function(x, ...) print('hi')
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(mode = "exported"))

  # Should NOT require types on @exportS3method (only @export)
  expect_equal(length(lints), 0)
})

test_that("exported mode: @keywords internal skips type checking (Phase 23)", {
  skip_if_not_installed("lintr")

  code <- "
    #' Internal but exported for testing
    #' @keywords internal
    #' @export
    .test_helper <- function(x) x
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(mode = "exported"))

  # Phase 23: @keywords internal provides explicit way to skip type checking
  # even for exported functions (useful for test helpers, internal utilities)
  expect_length(lints, 0)
})

test_that("exported mode: handles exported function with default parameters", {
  skip_if_not_installed("lintr")

  code <- "
    #' Function with defaults
    #' @export
    process <- function(x, y = 10, z = 'default') x + y
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(mode = "exported"))

  # Should flag all parameters regardless of defaults
  expect_gte(length(lints), 4)  # x, y, z, return
})

test_that("exported mode: handles exported function with ... parameter", {
  skip_if_not_installed("lintr")

  code <- "
    #' Function with ellipsis
    #' @param ... Additional arguments
    #' @export
    wrapper <- function(x, ...) x
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(mode = "exported"))

  # Should flag x and return, but ... is tricky (may skip)
  expect_gte(length(lints), 1)
})

test_that("exported mode: partial types on exported function", {
  skip_if_not_installed("lintr")

  code <- "
    #' Partially typed
    #' @typedParam x {class_numeric}
    #' @export
    partial <- function(x, y) x + y
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(mode = "exported"))

  # Should flag missing y and return
  expect_gte(length(lints), 2)
  messages <- vapply(lints, function(l) l$message, character(1))
  expect_true(any(grepl("Parameter 'y'", messages)))
  expect_true(any(grepl("return", messages, ignore.case = TRUE)))
})

# Mode: strict ----

test_that("strict mode: requires types on all functions", {
  skip_if_not_installed("lintr")

  code <- "
    #' Public function
    #' @export
    public_add <- function(x, y) x + y

    #' Internal function
    .internal_multiply <- function(a, b) a * b
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(mode = "strict"))

  # Should flag both functions: 3 lints each = 6 total
  expect_gte(length(lints), 6)
})

test_that("strict mode: flags functions without roxygen comments", {
  skip_if_not_installed("lintr")

  code <- "
    # Regular comment, not roxygen
    calculate <- function(x, y) x + y
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(mode = "strict"))

  expect_gte(length(lints), 3)
  expect_true(any(grepl("missing.*annotation", vapply(lints, function(l) l$message, character(1)), ignore.case = TRUE)))
})

test_that("strict mode: accepts fully typed functions", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam x {class_numeric}
    #' @typedParam y {class_numeric}
    #' @typedReturn {class_numeric}
    add <- function(x, y) x + y
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(mode = "strict"))

  expect_equal(length(lints), 0)
})

test_that("strict mode: warns on unknown variable types", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam x {class_numeric}
    #' @typedReturn {class_numeric}
    process <- function(x) x * 2

    # Untyped function - no @typedReturn
    foo <- function(n) n

    result <- foo(42)
    process(result)
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(mode = "strict"))

  # Should warn about unknown type from untyped function in strict mode
  expect_gte(length(lints), 1)
  expect_true(any(grepl("cannot verify type|unknown type", vapply(lints, function(l) l$message, character(1)), ignore.case = TRUE)))
})

test_that("strict mode: validates type errors", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam x {class_numeric}
    #' @typedReturn {class_numeric}
    process <- function(x) x * 2

    process('text')
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(mode = "strict"))

  expect_gte(length(lints), 1)
  expect_true(any(grepl("integer.*double.*character", vapply(lints, function(l) l$message, character(1)))))
})

test_that("strict mode: handles multiple functions in one file", {
  skip_if_not_installed("lintr")

  code <- "
    #' Complete function
    #' @typedParam x {class_numeric}
    #' @typedReturn {class_numeric}
    good <- function(x) x * 2

    #' Incomplete function
    #' @param y A number
    bad <- function(y) y + 1
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(mode = "strict"))

  # Should only flag the incomplete function
  expect_gte(length(lints), 2)
  messages <- vapply(lints, function(l) l$message, character(1))
  expect_false(any(grepl("\\bgood\\b", messages)))
  expect_false(any(grepl("\\bx\\b.*missing", messages)))
})

# Edge Cases ----

test_that("all modes: handles empty file", {
  skip_if_not_installed("lintr")

  code <- ""

  lints_lenient <- lintr::lint(text = code, linters = type_consistency_linter(mode = "lenient"))
  lints_exported <- lintr::lint(text = code, linters = type_consistency_linter(mode = "exported"))
  lints_strict <- lintr::lint(text = code, linters = type_consistency_linter(mode = "strict"))

  expect_equal(length(lints_lenient), 0)
  expect_equal(length(lints_exported), 0)
  expect_equal(length(lints_strict), 0)
})

test_that("all modes: handles file with only comments", {
  skip_if_not_installed("lintr")

  code <- "
    # This is a comment
    #' This is roxygen
  "

  lints_lenient <- lintr::lint(text = code, linters = type_consistency_linter(mode = "lenient"))
  lints_exported <- lintr::lint(text = code, linters = type_consistency_linter(mode = "exported"))
  lints_strict <- lintr::lint(text = code, linters = type_consistency_linter(mode = "strict"))

  expect_equal(length(lints_lenient), 0)
  expect_equal(length(lints_exported), 0)
  expect_equal(length(lints_strict), 0)
})

test_that("all modes: handles anonymous functions", {
  skip_if_not_installed("lintr")

  code <- "
    result <- lapply(1:3, function(x) x * 2)
  "

  # Anonymous functions don't have roxygen comments, so strict mode may or may not flag them
  # Current implementation likely skips them (no roxygen → no lints)
  lints_strict <- lintr::lint(text = code, linters = type_consistency_linter(mode = "strict"))

  # Should not crash, at minimum
  expect_true(is.list(lints_strict))
})

test_that("exported mode: case sensitivity of @export", {
  skip_if_not_installed("lintr")

  code <- "
    #' Function with wrong case
    #' @Export
    wrong_case <- function(x) x
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(mode = "exported"))

  # @Export (wrong case) should NOT trigger exported mode
  expect_equal(length(lints), 0)
})

test_that("exported mode: @export in middle of documentation", {
  skip_if_not_installed("lintr")

  code <- "
    #' Calculate sum
    #' This function adds numbers.
    #' @export
    #' It is very useful.
    add <- function(x, y) x + y
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(mode = "exported"))

  expect_gte(length(lints), 3)
})

test_that("exported mode: multiple @export tags", {
  skip_if_not_installed("lintr")

  code <- "
    #' Function
    #' @export
    #' @export
    duplicate_export <- function(x) x
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(mode = "exported"))

  # Should still detect as exported (even if duplicate)
  expect_gte(length(lints), 2)
})

test_that("all modes: function with no parameters", {
  skip_if_not_installed("lintr")

  code <- "
    #' @export
    get_constant <- function() 42
  "

  lints_exported <- lintr::lint(text = code, linters = type_consistency_linter(mode = "exported"))

  # Should only flag missing return type
  expect_equal(length(lints_exported), 1)
  expect_true(grepl("return", lints_exported[[1]]$message, ignore.case = TRUE))
})

test_that("all modes: combines type errors with missing annotation warnings", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam x {class_numeric}
    #' @export
    incomplete <- function(x, y) x + y

    incomplete('text', 5)
  "

  lints_exported <- lintr::lint(text = code, linters = type_consistency_linter(mode = "exported"))

  # Should flag: missing y type, missing return, AND type error
  expect_gte(length(lints_exported), 3)
  messages <- vapply(lints_exported, function(l) l$message, character(1))
  expect_true(any(grepl("Parameter 'y'", messages)))
  expect_true(any(grepl("return", messages, ignore.case = TRUE)))
  expect_true(any(grepl("integer.*double.*character", messages)))
})

test_that("exported mode: box module exported functions", {
  skip_if_not_installed("lintr")

  code <- "
    #' Box module function
    #' @export
    module_fn <- function(x) x * 2
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(mode = "exported"))

  # Box module @export should work same as regular @export
  expect_gte(length(lints), 2)
})

test_that("all modes: nested function definitions", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam x {class_numeric}
    #' @typedReturn {class_function}
    #' @export
    make_multiplier <- function(x) {
      # Inner function
      inner <- function(y) y * x
      inner
    }
  "

  lints_exported <- lintr::lint(text = code, linters = type_consistency_linter(mode = "exported"))

  # Outer function is typed, inner function handling depends on implementation
  # At minimum, should not crash
  expect_true(is.list(lints_exported))
})

test_that("mode values are case-sensitive", {
  expect_error(
    type_consistency_linter(mode = "Lenient"),
    "should be one of"
  )

  expect_error(
    type_consistency_linter(mode = "STRICT"),
    "should be one of"
  )
})

test_that("helpful error messages in all modes", {
  skip_if_not_installed("lintr")

  code <- "
    #' @export
    test <- function(x) x
  "

  lints_exported <- lintr::lint(text = code, linters = type_consistency_linter(mode = "exported"))

  # Check that messages are informative
  expect_gte(length(lints_exported), 1)
  messages <- vapply(lints_exported, function(l) l$message, character(1))
  expect_true(any(grepl("@typed", messages)))
})

# Error Position Accuracy ----

test_that("missing parameter type error points at parameter name, not function name", {
  skip_if_not_installed("lintr")

  code <- "
    # rdoc: strict
    #' @export
    untyped_exported <- function(x) {
      x + 1
    }
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(mode = "strict"))

  # Find the parameter error
  param_lints <- Filter(function(l) grepl("Parameter 'x' missing", l$message), lints)
  expect_length(param_lints, 1)

  lint <- param_lints[[1]]

  # Line should be where function is defined (line 4 in this code)
  expect_equal(lint$line_number, 4)

  # Column should point at parameter 'x' (column 36 in "function(x)")
  # Not at function name 'untyped_exported' (column 5)
  expect_true(lint$column_number >= 30)  # After 'function('
  expect_true(lint$column_number <= 40)  # Around 'x'
})

test_that("missing return type error points at function name, not FUNCTION keyword", {
  skip_if_not_installed("lintr")

  code <- "
    # rdoc: strict
    #' @export
    untyped_exported <- function(x) {
      x + 1
    }
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(mode = "strict"))

  # Find the return type error
  return_lints <- Filter(function(l) grepl("missing return type", l$message), lints)
  expect_length(return_lints, 1)

  lint <- return_lints[[1]]

  # Line should be where function is defined
  expect_equal(lint$line_number, 4)

  # Column should point at function name 'untyped_exported' (starts around column 5)
  # Not at 'function' keyword (column 25)
  expect_true(lint$column_number < 25)  # Before 'function' keyword
  expect_true(lint$column_number >= 5)  # At or after function name start
})
