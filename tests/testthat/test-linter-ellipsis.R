# Tests for ellipsis (...) handling

test_that("ellipsis with class_any accepts any types", {
  skip_if_not_installed("lintr")

  code <- "
    #' Test function
    #' @typedParam x {class_numeric} first value
    #' @typedParam ... {class_any} additional arguments
    #' @typedReturn {class_numeric} result
    foo <- function(x, ...) { x }

    foo(1)
    foo(1, 2, 3)
    foo(1, 'text', TRUE, list())
    foo(1, a = 2, b = 'named')
  "

  lints <- lintr::lint(text = code, linters = list(type_consistency = type_consistency_linter()))
  expect_length(lints, 0)
})

test_that("ellipsis without annotation is allowed", {
  skip_if_not_installed("lintr")

  code <- "
    #' Test function
    #' @typedParam x {class_numeric} first value
    #' @typedReturn {class_numeric} result
    foo <- function(x, ...) { x }

    foo(1, 'anything', TRUE)
  "

  lints <- lintr::lint(text = code, linters = list(type_consistency = type_consistency_linter()))
  expect_length(lints, 0)
})

test_that("ellipsis without type produces lint error", {
  skip_if_not_installed("lintr")

  code <- "
    #' Test function
    #' @typedParam x {class_numeric} first value
    #' @typedParam ... additional arguments
    #' @typedReturn {class_numeric} result
    foo <- function(x, ...) { x }

    foo(1, 'anything', TRUE)
  "

  lints <- lintr::lint(text = code, linters = list(type_consistency = type_consistency_linter()))
  expect_length(lints, 1)
  expect_match(lints[[1]]$message, "Invalid format: expected 'param \\{type\\} description'")
})

test_that("ellipsis without type or description produces lint error", {
  skip_if_not_installed("lintr")

  code <- "
    #' Test function
    #' @typedParam x {class_numeric} first value
    #' @typedParam ...
    #' @typedReturn {class_numeric} result
    foo <- function(x, ...) { x }

    foo(1, 'text', TRUE)
  "

  lints <- lintr::lint(text = code, linters = list(type_consistency = type_consistency_linter()))
  expect_length(lints, 1)
  expect_match(lints[[1]]$message, "Invalid format: expected 'param \\{type\\} description'")
})

test_that("ellipsis is not required in strict mode", {
  skip_if_not_installed("lintr")

  # Ellipsis without annotation should not error in strict mode
  code <- "
    # rdoc: strict
    #' Test function
    #' @typedParam x {class_numeric} first value
    #' @typedReturn {class_numeric} result
    #' @export
    foo <- function(x, ...) { x }
  "

  lints <- lintr::lint(text = code, linters = list(type_consistency = type_consistency_linter(mode = "strict")))
  expect_length(lints, 0)
})

test_that("ellipsis with class_any in strict mode works", {
  skip_if_not_installed("lintr")

  code <- "
    # rdoc: strict
    #' Test function
    #' @typedParam x {class_numeric} first value
    #' @typedParam ... {class_any} additional arguments
    #' @typedReturn {class_numeric} result
    #' @export
    foo <- function(x, ...) { x }

    foo(1, 2, 'text', TRUE)
  "

  lints <- lintr::lint(text = code, linters = list(type_consistency = type_consistency_linter(mode = "strict")))
  expect_length(lints, 0)
})

test_that("ellipsis can be used for forwarding", {
  skip_if_not_installed("lintr")

  code <- "
    #' Wrapper function
    #' @typedParam x {class_numeric} data
    #' @typedParam ... {class_any} passed to mean()
    #' @typedReturn {class_numeric} mean value
    mean_wrapper <- function(x, ...) {
      mean(x, ...)
    }

    mean_wrapper(1:10, na.rm = TRUE)
    mean_wrapper(1:10, trim = 0.1)
  "

  lints <- lintr::lint(text = code, linters = list(type_consistency = type_consistency_linter()))
  expect_length(lints, 0)
})

test_that("ellipsis can collect variadic arguments", {
  skip_if_not_installed("lintr")

  code <- "
    #' Collect all arguments
    #' @typedParam ... {class_any} values to collect
    #' @typedReturn {class_list} list of arguments
    collect <- function(...) {
      list(...)
    }

    collect(1, 2, 3)
    collect('a', 'b', 'c')
    collect(x = 1, y = 2, z = 3)
  "

  lints <- lintr::lint(text = code, linters = list(type_consistency = type_consistency_linter()))
  expect_length(lints, 0)
})

test_that("ellipsis with only class_any is supported", {
  skip_if_not_installed("lintr")

  code <- "
    #' Function with only ellipsis
    #' @typedParam ... {class_any} all arguments
    #' @typedReturn {class_numeric} result
    foo <- function(...) { 42 }

    foo(1, 2, 3)
    foo()
  "

  lints <- lintr::lint(text = code, linters = list(type_consistency = type_consistency_linter()))
  expect_length(lints, 0)
})

test_that("empty ellipsis call is valid", {
  skip_if_not_installed("lintr")

  code <- "
    #' Test function
    #' @typedParam x {class_numeric} value
    #' @typedParam ... {class_any} additional
    #' @typedReturn {class_numeric} result
    foo <- function(x, ...) { x }

    foo(1)  # No ellipsis args
  "

  lints <- lintr::lint(text = code, linters = list(type_consistency = type_consistency_linter()))
  expect_length(lints, 0)
})

test_that("ellipsis with non-class_any type produces lint error", {
  skip_if_not_installed("lintr")

  code <- "
    #' Test function
    #' @typedParam x {class_numeric} value
    #' @typedParam ... {class_numeric} additional numeric values
    #' @typedReturn {class_numeric} result
    foo <- function(x, ...) { x }
  "

  lints <- lintr::lint(text = code, linters = list(type_consistency = type_consistency_linter()))

  expect_length(lints, 1)
  expect_match(lints[[1]]$message, "Ellipsis parameter '...' only supports \\{class_any\\} type annotation")
  expect_match(lints[[1]]$message, "Got \\{class_numeric\\}")
  expect_match(lints[[1]]$message, "Use: @typedParam ... \\{class_any\\} description")
})

test_that("ellipsis with class_character produces lint error", {
  skip_if_not_installed("lintr")

  code <- "
    #' Test function
    #' @typedParam ... {class_character} string arguments
    #' @typedReturn {class_character} result
    foo <- function(...) { 'result' }
  "

  lints <- lintr::lint(text = code, linters = list(type_consistency = type_consistency_linter()))

  expect_length(lints, 1)
  expect_match(lints[[1]]$message, "Ellipsis parameter '...' only supports \\{class_any\\} type annotation")
  expect_match(lints[[1]]$message, "Got \\{class_character\\}")
})

test_that("ellipsis with union type produces lint error", {
  skip_if_not_installed("lintr")

  code <- "
    #' Test function
    #' @typedParam ... {class_numeric | class_character} mixed args
    #' @typedReturn {class_list} result
    foo <- function(...) { list(...) }
  "

  lints <- lintr::lint(text = code, linters = list(type_consistency = type_consistency_linter()))

  expect_length(lints, 1)
  expect_match(lints[[1]]$message, "Ellipsis parameter '...' only supports \\{class_any\\} type annotation")
  expect_match(lints[[1]]$message, "Got \\{class_numeric \\| class_character\\}")
})

test_that("error message provides helpful guidance", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam ... {class_numeric} numbers
    foo <- function(...) { }
  "

  lints <- lintr::lint(text = code, linters = list(type_consistency = type_consistency_linter()))

  expect_length(lints, 1)
  expect_match(lints[[1]]$message, "only \\{class_any\\} is allowed")
  expect_match(lints[[1]]$message, "Use: @typedParam ... \\{class_any\\} description")
})
