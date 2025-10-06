test_that("types_compatible accepts bracket syntax for length constraints", {
  expect_true(types_compatible("class_integer", "class_integer[1]", actual_length = 1))
  expect_false(types_compatible("class_integer", "class_integer[1]", actual_length = 2))
  expect_true(types_compatible("class_numeric", "class_numeric[5]", actual_length = 5))
})

test_that("types_compatible accepts bracket syntax for element type constraints", {
  # Element type checking is placeholder, should always pass for now
  expect_true(types_compatible("class_list", "class_list<class_integer>"))
  expect_true(types_compatible("class_list", "class_list<class_character>"))
})

test_that("types_compatible accepts combined bracket syntax", {
  # Combined: class_list<class_numeric>[3]
  expect_true(types_compatible("class_list", "class_list<class_numeric>[3]", actual_length = 3))
  expect_false(types_compatible("class_list", "class_list<class_numeric>[3]", actual_length = 5))
})

test_that("types_compatible with bracket syntax maintains S7 type checking", {
  # Should still respect S7 type hierarchy
  expect_true(types_compatible("class_integer", "class_numeric[1]", actual_length = 1))
  expect_false(types_compatible("class_character", "class_numeric[1]", actual_length = 1))
})

test_that("types_compatible rejects parentheses syntax", {
  # Parenthesis syntax is invalid - should be rejected by validator
  expect_error(types_compatible("class_integer", "class_integer(1)"))
  expect_error(types_compatible("class_numeric", "class_numeric(5)"))
})

test_that("linter parses bracket syntax in annotations without error", {
  skip_if_not_installed("xml2")
  skip_if_not_installed("lintr")

  code <- "
  #' Test function
  #' @typedParam x {class_integer[1]} scalar integer
  test_fn <- function(x) {
    x
  }

  # Length checking for c() calls requires deeper analysis
  # For now, we just verify the syntax is accepted
  test_fn(c(1L, 2L))
  "

  # Should not throw parsing errors
  result <- lintr::lint(text = code, linters = type_consistency_linter())

  # No errors expected (length inference not yet implemented for c() calls)
  expect_type(result, "list")
})

test_that("linter accepts bracket syntax for scalar literals", {
  skip_if_not_installed("xml2")
  skip_if_not_installed("lintr")

  code <- "
  #' Test function
  #' @typedParam x {class_integer[1]} scalar integer
  test_fn <- function(x) {
    x
  }

  # Scalar literal should work (length = 1 inferred)
  test_fn(42L)
  "

  result <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should have NO lint warnings
  expect_length(result, 0)
})

test_that("linter handles element type syntax in annotations", {
  skip_if_not_installed("xml2")
  skip_if_not_installed("lintr")

  code <- "
  #' Test function
  #' @typedParam items {class_list<class_integer>} list of integers
  test_fn <- function(items) {
    items
  }

  # Should pass - list constructor
  test_fn(list(1L, 2L, 3L))
  "

  result <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should have NO lint warnings (element type checking is placeholder)
  expect_length(result, 0)
})

test_that("linter handles combined bracket syntax", {
  skip_if_not_installed("xml2")
  skip_if_not_installed("lintr")

  code <- "
  #' Test function
  #' @typedParam pairs {class_list<class_numeric>[2]} list of exactly 2 numbers
  test_fn <- function(pairs) {
    pairs
  }

  # Should pass - list constructor (length checking needs runtime info)
  test_fn(list(1.5, 2.5))
  "

  result <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should have NO lint warnings (we can't check list length statically)
  expect_length(result, 0)
})

test_that("format_type_spec used in error messages shows bracket syntax", {
  # Test that our display logic works
  parsed <- parse_type_constraints("class_integer[1]")
  formatted <- format_type_constraints(parsed)
  expect_equal(formatted, "class_integer[1]")

  parsed2 <- parse_type_constraints("class_list<class_integer>")
  formatted2 <- format_type_constraints(parsed2)
  expect_equal(formatted2, "class_list<class_integer>")
})
