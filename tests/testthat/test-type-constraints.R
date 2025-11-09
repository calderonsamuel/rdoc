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
