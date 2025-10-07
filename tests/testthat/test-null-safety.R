# Integration tests for NULL safety (Phase 14)

test_that("NULL safety validates optional parameters", {
  skip_if_not_installed("xml2")

  code <- "
#' @typedParam name {NULL | class_character} optional name
#' @typedReturn {class_character}
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
#' @typedParam name {class_character} required name
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
#' @typedParam id {class_integer}
#' @typedReturn {NULL | class_list} user or NULL
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
#' @typedParam value {NULL | class_integer | class_character} flexible input
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
#' @typedParam value {NULL | class_integer | class_character}
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
    parse_type_syntax("class_integer | NULL"),
    "NULL must be first"
  )

  expect_error(
    parse_type_syntax("class_integer | class_character | NULL"),
    "NULL must be first"
  )

  # NULL first should work
  expect_silent(parse_type_syntax("NULL | class_integer"))
  expect_silent(parse_type_syntax("NULL | class_integer | class_character"))
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
#' @typedParam items {NULL | class_list<class_integer>} optional list
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
#' @typedParam value {NULL | class_integer | class_character | class_logical}
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
#' @typedReturn {NULL | class_integer}
step1 <- function() { 42L }

#' @typedParam x {NULL | class_integer}
#' @typedReturn {NULL | class_character}
step2 <- function(x) {
  if (is.null(x)) return(NULL)
  as.character(x)
}

#' @typedParam x {NULL | class_character}
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
#' @typedParam value {NULL | class_integer | class_character}
big_union <- function(value) { value }

#' @typedParam value {class_integer | class_character}  
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
#' @typedReturn {NULL | class_integer}
maybe_int <- function() { NULL }

#' @typedParam x {class_integer}
requires_int <- function(x) { x }

# Should fail: union → non-union
requires_int(maybe_int())
"

  lints <- lintr::lint(text = code, linters = list(type_consistency_linter()))
  
  # Should have 1 lint for narrowing
  expect_length(lints, 1)
  expect_match(lints[[1]]$message, "NULL.*integer|union", ignore.case = TRUE)
})
