test_that("parse_type_spec handles simple types without constraints", {
  result <- parse_type_constraints("class_integer")

  expect_equal(result$base_type, "class_integer")
  expect_null(result$length_constraint)
  expect_null(result$element_type)
})

test_that("parse_type_spec handles length constraints with square brackets", {
  result <- parse_type_constraints("class_integer[1]")

  expect_equal(result$base_type, "class_integer")
  expect_equal(result$length_constraint, 1)
  expect_null(result$element_type)
})

test_that("parse_type_spec handles multi-digit length constraints", {
  result <- parse_type_constraints("class_numeric[100]")

  expect_equal(result$base_type, "class_numeric")
  expect_equal(result$length_constraint, 100)
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

test_that("parse_type_spec handles combined constraints (element + length)", {
  result <- parse_type_constraints("class_list<class_numeric>[3]")

  expect_equal(result$base_type, "class_list")
  expect_equal(result$element_type, "class_numeric")
  expect_equal(result$length_constraint, 3)
})

test_that("parse_type_spec handles combined constraints with complex element type", {
  result <- parse_type_constraints("class_list<class_integer>[5]")

  expect_equal(result$base_type, "class_list")
  expect_equal(result$element_type, "class_integer")
  expect_equal(result$length_constraint, 5)
})

test_that("parse_type_spec preserves class_ prefix", {
  result <- parse_type_constraints("class_logical[1]")

  expect_equal(result$base_type, "class_logical")
  expect_equal(result$length_constraint, 1)
})

test_that("format_type_spec reconstructs simple types", {
  parsed <- list(base_type = "class_integer", length_constraint = NULL, element_type = NULL)
  result <- format_type_constraints(parsed)

  expect_equal(result, "class_integer")
})

test_that("format_type_spec reconstructs length constraints", {
  parsed <- list(base_type = "class_integer", length_constraint = 1, element_type = NULL)
  result <- format_type_constraints(parsed)

  expect_equal(result, "class_integer[1]")
})

test_that("format_type_spec reconstructs element type constraints", {
  parsed <- list(base_type = "class_list", length_constraint = NULL, element_type = "class_integer")
  result <- format_type_constraints(parsed)

  expect_equal(result, "class_list<class_integer>")
})

test_that("format_type_spec reconstructs combined constraints", {
  parsed <- list(base_type = "class_list", length_constraint = 3, element_type = "class_numeric")
  result <- format_type_constraints(parsed)

  expect_equal(result, "class_list<class_numeric>[3]")
})

test_that("check_length_constraint passes when constraint matches", {
  expect_true(check_length_constraint(1, 1))
  expect_true(check_length_constraint(5, 5))
  expect_true(check_length_constraint(100, 100))
})

test_that("check_length_constraint fails when constraint doesn't match", {
  expect_false(check_length_constraint(2, 1))
  expect_false(check_length_constraint(1, 5))
})

test_that("check_length_constraint passes when no constraint specified", {
  expect_true(check_length_constraint(1, NULL))
  expect_true(check_length_constraint(100, NULL))
})

test_that("check_length_constraint passes when actual length unknown", {
  expect_true(check_length_constraint(NULL, 1))
  expect_true(check_length_constraint(NULL, 5))
})

test_that("check_element_type always passes (placeholder)", {
  # Element type checking is placeholder for now
  expect_true(check_element_type("class_list", "class_integer"))
  expect_true(check_element_type("class_list", "class_character"))
})

test_that("parse_type_spec round-trips correctly", {
  specs <- c(
    "class_integer",
    "class_integer[1]",
    "class_list<class_integer>",
    "class_list<class_numeric>[3]"
  )

  for (spec in specs) {
    parsed <- parse_type_constraints(spec)
    formatted <- format_type_constraints(parsed)
    expect_equal(formatted, spec, info = paste("Failed for:", spec))
  }
})
