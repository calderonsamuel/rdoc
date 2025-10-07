# Tests for R/linter-validate.R
# Tests for return value validation

# Phase 7.2: Return Value Validation ----

test_that("linter validates explicit return statement matches @typedReturn", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedReturn {class_numeric} should return number
    get_value <- function() {
      return('text')
    }
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should warn: declared numeric but returns character
  expect_equal(length(lints), 1)
  expect_true(any(grepl("Return.*numeric.*character", vapply(lints, function(l) l$message, character(1)))))
})

test_that("linter validates implicit return (last expression) matches @typedReturn", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedReturn {class_character} should return text
    get_value <- function() {
      42
    }
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should warn: declared character but returns numeric
  expect_equal(length(lints), 1)
  expect_true(any(grepl("Return.*character.*numeric", vapply(lints, function(l) l$message, character(1)))))
})

test_that("linter passes when return type matches declaration", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedReturn {class_numeric} returns number
    get_number <- function() {
      return(42)
    }

    #' @typedReturn {class_character} returns text
    get_text <- function() {
      'hello'
    }
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should pass - both functions return correct types
  expect_equal(length(lints), 0)
})

test_that("linter skips validation for complex function bodies", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedReturn {class_numeric} complex logic
    calculate <- function(x) {
      if (x > 0) {
        return(x * 2)
      } else {
        return('error')
      }
    }
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should skip validation - too complex (multiple return paths)
  # Function still usable with inferred return type
  expect_equal(length(lints), 0)
})

test_that("linter validates return from constructor calls", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedReturn {class_numeric} should return number
    get_data <- function() {
      return(list(1, 2, 3))
    }
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should warn: declared numeric but returns list
  expect_equal(length(lints), 1)
  expect_true(any(grepl("Return.*numeric.*list", vapply(lints, function(l) l$message, character(1)))))
})

test_that("linter handles functions without @typedReturn", {
  skip_if_not_installed("lintr")

  code <- "
    # No @typedReturn annotation
    get_value <- function() {
      return('text')
    }
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should not error - no declared return type to validate
  expect_equal(length(lints), 0)
})

test_that("linter validates return from comparison operators", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedReturn {class_logical} is adult
    is_adult <- function(age) {
      age >= 18
    }
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should pass: comparison operator returns logical
  expect_equal(length(lints), 0)
})

test_that("linter catches wrong type with comparison operators", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedReturn {class_numeric} wrong type
    is_valid <- function(x) {
      x > 0
    }
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should warn: declared numeric but returns logical
  expect_equal(length(lints), 1)
  expect_true(any(grepl("Return.*numeric.*logical", vapply(lints, function(l) l$message, character(1)))))
})

test_that("linter validates return from logical operators", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedReturn {class_logical} combined check
    check_both <- function(x, y) {
      (x > 0) & (y < 10)
    }
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should pass: logical operators return logical
  expect_equal(length(lints), 0)
})
