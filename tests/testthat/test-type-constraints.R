test_that("parse_type_spec handles simple types without constraints", {
  result <- parse_type_constraints("class_integer")

  expect_equal(result$base_type, "class_integer")
  expect_null(result$length_constraint)
  expect_null(result$element_type)
})

test_that("parse_type_spec handles element type constraints with angle brackets", {
  result <- parse_type_constraints("class_list<class_integer>")

  expect_equal(result$base_type, "class_list")
  expect_equal(result$element_type, "class_integer")
  expect_null(result$length_constraint)
})

test_that("parse_type_spec handles nested element types", {
  result <- parse_type_constraints("class_list<class_character>")

  expect_equal(result$base_type, "class_list")
  expect_equal(result$element_type, "class_character")
  expect_null(result$length_constraint)
})

test_that("format_type_spec reconstructs simple types", {
  parsed <- list(base_type = "class_integer", length_constraint = NULL, element_type = NULL)
  result <- format_type_constraints(parsed)

  expect_equal(result, "class_integer")
})

test_that("format_type_spec reconstructs element type constraints", {
  parsed <- list(base_type = "class_list", length_constraint = NULL, element_type = "class_integer")
  result <- format_type_constraints(parsed)

  expect_equal(result, "class_list<class_integer>")
})

test_that("check_element_type always passes (placeholder)", {
  # Element type checking is placeholder for now
  expect_true(check_element_type("class_list", "class_integer"))
  expect_true(check_element_type("class_list", "class_character"))
})

test_that("parse_type_spec round-trips correctly", {
  specs <- c(
    "class_integer",
    "class_list<class_integer>"
  )

  for (spec in specs) {
    parsed <- parse_type_constraints(spec)
    formatted <- format_type_constraints(parsed)
    expect_equal(formatted, spec, info = paste("Failed for:", spec))
  }
})

# Edge cases (merged from test-bracket-edge-cases.R) ----

test_that("parse_type_constraints handles nested generics", {
  # Single nesting - should now work with .+ pattern
  result <- parse_type_constraints("class_list<class_list<class_integer>>")

  expect_equal(result$base_type, "class_list")
  expect_equal(result$element_type, "class_list<class_integer>")
  expect_type(result, "list")  # R's internal type is "list"
})

test_that("parse_type_constraints rejects empty angle brackets", {
  # With validation, empty angle brackets are now an error
  expect_error(
    parse_type_constraints("class_list<>"),
    "Expected type after '<'"
  )
})

test_that("parse_type_constraints handles whitespace in angle brackets", {
  result <- parse_type_constraints("class_list< class_integer >")

  # Actually DOES match with .+ pattern (whitespace preserved in element_type)
  expect_equal(result$base_type, "class_list")
  expect_equal(result$element_type, " class_integer ")
})

test_that("parse_type_constraints rejects double angle brackets", {
  # class_list<int><char> is malformed - validation catches it
  expect_error(
    parse_type_constraints("class_list<int><char>"),
    "Multiple element types"
  )
})

# Element type compatibility (merged from test-element-types.R) ----

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
