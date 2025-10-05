# Tests for strict mode functionality
# Strict mode spans multiple modules (linter.R, linter-check.R)

# Phase 9: Strict Mode ----

# Phase 9: Strict Mode ----

test_that("type_consistency_linter accepts strict parameter", {
  linter <- type_consistency_linter(strict = TRUE)
  expect_s3_class(linter, "linter")

  linter_false <- type_consistency_linter(strict = FALSE)
  expect_s3_class(linter_false, "linter")
})

test_that("strict mode flags function with missing @typedParam", {
  skip_if_not_installed("lintr")

  code <- "
    #' Calculate sum
    #' @param x A number
    #' @param y Another number
    calculate <- function(x, y) x + y
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(strict = TRUE))

  # Should flag both parameters missing type annotations
  expect_gte(length(lints), 2)
  expect_true(any(grepl("missing type annotation.*strict mode", vapply(lints, function(l) l$message, character(1)), ignore.case = TRUE)))
})

test_that("strict mode flags function with missing @typedReturn", {
  skip_if_not_installed("lintr")

  code <- "
    #' Calculate sum
    #' @typedParam x {numeric} First number
    #' @typedParam y {numeric} Second number
    calculate <- function(x, y) x + y
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(strict = TRUE))

  # Should flag missing return type annotation
  expect_gte(length(lints), 1)
  expect_true(any(grepl("missing return type annotation.*strict mode", vapply(lints, function(l) l$message, character(1)), ignore.case = TRUE)))
})

test_that("strict mode passes with complete type annotations", {
  skip_if_not_installed("lintr")

  code <- "
    #' Calculate sum
    #' @typedParam x {numeric} First number
    #' @typedParam y {numeric} Second number
    #' @typedReturn {numeric} The sum
    calculate <- function(x, y) x + y
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(strict = TRUE))

  # Should pass - all parameters and return have type annotations
  expect_equal(length(lints), 0)
})

test_that("lenient mode allows missing type annotations", {
  skip_if_not_installed("lintr")

  code <- "
    #' Calculate sum
    #' @param x A number
    #' @param y Another number
    calculate <- function(x, y) x + y
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(strict = FALSE))

  # Should not flag missing annotations in lenient mode
  expect_equal(length(lints), 0)
})

test_that("default mode is lenient", {
  skip_if_not_installed("lintr")

  code <- "
    #' Calculate sum
    #' @param x A number
    calculate <- function(x, y) x + y
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Default should be lenient - no lints for missing annotations
  expect_equal(length(lints), 0)
})

test_that("strict mode flags partial type annotations", {
  skip_if_not_installed("lintr")

  code <- "
    #' Process data
    #' @typedParam x {numeric} A number
    #' @param y Another parameter (missing type)
    process <- function(x, y) x + y
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(strict = TRUE))

  # Should flag parameter y and missing return type
  expect_gte(length(lints), 2)
  messages <- vapply(lints, function(l) l$message, character(1))
  expect_true(any(grepl("missing type annotation", messages, ignore.case = TRUE)))
})

test_that("strict mode warns on unknown variable types", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam x {numeric} A number
    #' @typedReturn {numeric} Result
    process <- function(x) x * 2

    # result type is unknown (no @typedReturn on foo)
    foo <- function() 42
    result <- foo()
    process(result)
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(strict = TRUE))

  # Should warn about unknown type from foo() in strict mode
  expect_gte(length(lints), 1)
  expect_true(any(grepl("cannot verify type|unknown type", vapply(lints, function(l) l$message, character(1)), ignore.case = TRUE)))
})

test_that("lenient mode skips unknown variable types", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam x {numeric} A number
    process <- function(x) x * 2

    # result type is unknown
    foo <- function() 42
    result <- foo()
    process(result)
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(strict = FALSE))

  # Lenient mode should skip unknown types - no error
  expect_equal(length(lints), 0)
})

test_that("strict mode flags functions without roxygen comments", {
  skip_if_not_installed("lintr")

  code <- "
    # Regular comment, not roxygen
    calculate <- function(x, y) x + y
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(strict = TRUE))

  # Should flag missing type annotations
  expect_gte(length(lints), 1)
  expect_true(any(grepl("missing.*annotation", vapply(lints, function(l) l$message, character(1)), ignore.case = TRUE)))
})

test_that("strict mode handles functions with default parameters", {
  skip_if_not_installed("lintr")

  code <- "
    #' Calculate with defaults
    #' @param x A number
    #' @param y Another number with default
    calculate <- function(x, y = 10) x + y
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(strict = TRUE))

  # Should flag both parameters regardless of defaults
  expect_gte(length(lints), 2)
})

test_that("strict mode handles functions with ... parameter", {
  skip_if_not_installed("lintr")

  code <- "
    #' Process with ellipsis
    #' @param x A number
    #' @param ... Additional arguments
    process <- function(x, ...) x
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(strict = TRUE))

  # Should flag x and return type, but maybe allow ... without type
  # (... is tricky to type - implementation decision)
  expect_gte(length(lints), 1)
})

test_that("strict mode only checks exported functions for return types", {
  skip_if_not_installed("lintr")

  # This test documents expected behavior - may need adjustment
  # based on implementation: should internal functions require @typedReturn?
  code <- "
    #' Internal helper
    #' @keywords internal
    #' @typedParam x {numeric} A number
    .internal_helper <- function(x) x * 2
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(strict = TRUE))

  # Decision: Should internal functions require @typedReturn in strict mode?
  # For now, let's require it for all functions
  expect_gte(length(lints), 1)
})

test_that("strict mode provides helpful error messages", {
  skip_if_not_installed("lintr")

  code <- "
    #' Test function
    #' @param x A number
    test <- function(x) x
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(strict = TRUE))

  # Check that messages are informative
  expect_gte(length(lints), 1)
  messages <- vapply(lints, function(l) l$message, character(1))
  expect_true(any(grepl("strict mode", messages, ignore.case = TRUE)))
  expect_true(any(grepl("@typed", messages)))
})

test_that("strict mode handles multiple functions in one file", {
  skip_if_not_installed("lintr")

  code <- "
    #' Complete function
    #' @typedParam x {numeric} A number
    #' @typedReturn {numeric} Result
    good <- function(x) x * 2

    #' Incomplete function
    #' @param y A number
    bad <- function(y) y + 1
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(strict = TRUE))

  # Should only flag the incomplete function
  expect_gte(length(lints), 2)
  # All lints should reference 'bad' or 'y', not 'good' or 'x'
  messages <- vapply(lints, function(l) l$message, character(1))
  expect_false(any(grepl("\\bgood\\b", messages)))
  expect_false(any(grepl("\\bx\\b.*missing", messages)))
})

test_that("strict mode combined with type checking still works", {
  skip_if_not_installed("lintr")

  code <- "
    #' Process number
    #' @typedParam x {numeric} A number
    #' @typedReturn {numeric} Result
    process <- function(x) x * 2

    # This call has wrong type AND missing annotations
    process('text')
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(strict = TRUE))

  # Should flag the type mismatch
  expect_gte(length(lints), 1)
  expect_true(any(grepl("numeric.*character", vapply(lints, function(l) l$message, character(1)))))
})
