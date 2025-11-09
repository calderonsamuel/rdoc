test_that("types_compatible accepts element type constraints", {
  # Element type checking is placeholder, should always pass for now
  expect_true(types_compatible("class_list", "class_list<class_integer>"))
  expect_true(types_compatible("class_list", "class_list<class_character>"))
})

test_that("types_compatible rejects parentheses syntax", {
  # Parenthesis syntax is invalid - should be rejected by validator
  expect_error(types_compatible("class_integer", "class_integer(1)"))
  expect_error(types_compatible("class_numeric", "class_numeric(5)"))
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

test_that("format_type_spec used in error messages shows element type syntax", {
  # Test that our display logic works
  parsed <- parse_type_constraints("class_list<class_integer>")
  formatted <- format_type_constraints(parsed)
  expect_equal(formatted, "class_list<class_integer>")
})
