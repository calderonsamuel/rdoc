# Integration tests for NULL safety (Phase 14)

test_that("NULL safety validates optional parameters", {
  skip_if_not_installed("xml2")

  code <- "
#' @typedParam name {NULL | character} optional name
#' @typedReturn {character}
greet <- function(name = NULL) {
  if (is.null(name)) 'Hello!' else paste('Hello', name)
}

# Valid calls
greet(NULL)
greet('Alice')
greet()
"

  lints <- lintr::lint(text = code, linters = list(type_consistency_linter()))
  expect_length(lints, 0)
})

test_that("NULL safety rejects NULL to non-nullable parameter", {
  skip_if_not_installed("xml2")

  code <- "
#' @typedParam name {character} required name
greet <- function(name) {
  paste('Hello', name)
}

greet(NULL)  # Should lint
"

  lints <- lintr::lint(text = code, linters = list(type_consistency_linter()))
  expect_length(lints, 1)
  expect_match(lints[[1]]$message, "NULL|character", ignore.case = TRUE)
})

test_that("NULL safety validates NULL returns", {
  skip_if_not_installed("xml2")

  code <- "
#' @typedParam id {integer}
#' @typedReturn {NULL | list} user or NULL
get_user <- function(id) {
  if (id < 1) return(NULL)
  list(id = id, name = 'User')
}

result <- get_user(0L)  # Can be NULL (use integer literal)
result <- get_user(1L)  # Can be list
"

  lints <- lintr::lint(text = code, linters = list(type_consistency_linter()))
  expect_length(lints, 0)
})

test_that("NULL safety validates multi-way unions", {
  skip_if_not_installed("xml2")

  code <- "
#' @typedParam value {NULL | integer | character} flexible input
process <- function(value) {
  value
}

process(NULL)
process(1L)
process('text')
"

  lints <- lintr::lint(text = code, linters = list(type_consistency_linter()))
  expect_length(lints, 0)
})

test_that("NULL safety rejects wrong type in union", {
  skip_if_not_installed("xml2")

  code <- "
#' @typedParam value {NULL | integer | character}
process <- function(value) {
  value
}

process(3.14)  # numeric/double not in union
"

  lints <- lintr::lint(text = code, linters = list(type_consistency_linter()))
  expect_length(lints, 1)
})

test_that("NULL must be first in union (parser enforces)", {
  # Parser should reject NULL not first
  expect_error(
    parse_type_syntax("integer | NULL"),
    "NULL must be first"
  )

  expect_error(
    parse_type_syntax("integer | character | NULL"),
    "NULL must be first"
  )

  # NULL first should work
  expect_silent(parse_type_syntax("NULL | integer"))
  expect_silent(parse_type_syntax("NULL | integer | character"))
})

test_that("NULL safety works with S7 classes", {
  skip_if_not_installed("xml2")

  code <- "
#' @typedParam value {NULL | class_integer}
process <- function(value) {
  value
}

process(NULL)
process(1L)
"

  lints <- lintr::lint(text = code, linters = list(type_consistency_linter()))
  expect_length(lints, 0)
})

test_that("NULL safety validates complex optional types", {
  skip_if_not_installed("xml2")

  code <- "
#' @typedParam items {NULL | list<integer>} optional list
process <- function(items = NULL) {
  items
}

process(NULL)
process(list(1L, 2L, 3L))
"

  lints <- lintr::lint(text = code, linters = list(type_consistency_linter()))
  expect_length(lints, 0)
})

# Additional edge case tests

test_that("multi-way unions work correctly", {
  skip_if_not_installed("xml2")

  code <- "
#' @typedParam value {NULL | integer | character | logical}
flexible <- function(value) { value }

flexible(NULL)
flexible(123L)
flexible('text')
flexible(TRUE)
flexible(3.14)  # Should fail
"

  lints <- lintr::lint(text = code, linters = list(type_consistency_linter()))
  
  # Should have 1 lint for the double
  expect_length(lints, 1)
  expect_match(lints[[1]]$message, "numeric|double", ignore.case = TRUE)
})

test_that("chained union function calls work", {
  skip_if_not_installed("xml2")

  code <- "
#' @typedReturn {NULL | integer}
step1 <- function() { 42L }

#' @typedParam x {NULL | integer}
#' @typedReturn {NULL | character}
step2 <- function(x) {
  if (is.null(x)) return(NULL)
  as.character(x)
}

#' @typedParam x {NULL | character}
step3 <- function(x) { x }

# Chain: NULL|int → NULL|char → final
result <- step3(step2(step1()))
"

  lints <- lintr::lint(text = code, linters = list(type_consistency_linter()))
  expect_length(lints, 0)
})

test_that("union to union compatibility", {
  skip_if_not_installed("xml2")

  code <- "
#' @typedParam value {NULL | integer | character}
big_union <- function(value) { value }

#' @typedParam value {integer | character}  
small_union <- function(value) { value }

# Smaller union should be compatible with larger
x <- 123L
big_union(x)
small_union(x)
"

  lints <- lintr::lint(text = code, linters = list(type_consistency_linter()))
  expect_length(lints, 0)
})

test_that("union narrowing detected in chains", {
  skip_if_not_installed("xml2")

  code <- "
#' @typedReturn {NULL | integer}
maybe_int <- function() { NULL }

#' @typedParam x {integer}
requires_int <- function(x) { x }

# Should fail: union → non-union
requires_int(maybe_int())
"

  lints <- lintr::lint(text = code, linters = list(type_consistency_linter()))
  
  # Should have 1 lint for narrowing
  expect_length(lints, 1)
  expect_match(lints[[1]]$message, "NULL.*integer|union", ignore.case = TRUE)
})
