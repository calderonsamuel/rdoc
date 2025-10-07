# Tests for R/linter-extract.R
# Functions for extracting type information from roxygen comments

test_that("parse_typed_param_text parses correctly", {
  result <- parse_typed_param_text("x {class_numeric} input value")

  expect_equal(result$param, "x")
  expect_equal(result$type, "class_numeric")
  expect_equal(result$description, "input value")
})

test_that("parse_typed_return_text parses correctly", {
  result <- parse_typed_return_text("{class_numeric} output value")

  expect_equal(result$type, "class_numeric")
  expect_equal(result$description, "output value")
})
