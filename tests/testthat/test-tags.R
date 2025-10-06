test_that("@typed-param parses basic types correctly", {
  tag <- list(raw = "x {numeric} vector of values")

  result <- tag_parse_typed_param(tag)

  expect_equal(result$val$param, "x")
  expect_equal(result$val$type, "numeric")
  expect_equal(result$val$description, "vector of values")
})

test_that("@typed-param handles scalar notation", {
  tag <- list(raw = "trim {numeric[1]} proportion to trim")

  result <- tag_parse_typed_param(tag)

  expect_equal(result$val$param, "trim")
  expect_equal(result$val$type, "numeric[1]")
  expect_equal(result$val$description, "proportion to trim")
})

test_that("@typed-param handles union types", {
  tag <- list(raw = "name {NULL | character} optional name")

  result <- tag_parse_typed_param(tag)

  expect_equal(result$val$param, "name")
  expect_equal(result$val$type, "NULL | character")
  expect_equal(result$val$description, "optional name")
})

test_that("@typed-param handles empty description", {
  tag <- list(raw = "x {numeric}")

  result <- tag_parse_typed_param(tag)

  expect_equal(result$val$param, "x")
  expect_equal(result$val$type, "numeric")
  expect_equal(result$val$description, "")
})

test_that("@typed-param handles complex types", {
  # TODO: Function signature syntax like function(numeric): logical
  # requires extending the parser to support parentheses in type context
  tag <- list(raw = "fn {class_function} filter function")

  result <- tag_parse_typed_param(tag)

  expect_equal(result$val$param, "fn")
  expect_equal(result$val$type, "class_function")
  expect_equal(result$val$description, "filter function")
})

test_that("@typed-param errors on invalid format", {
  tag <- list(raw = "invalid format without braces")

  expect_error(
    tag_parse_typed_param(tag),
    "Invalid.*@typedParam.*format"
  )
})

test_that("@typed-return parses correctly", {
  tag <- list(raw = "{numeric[1]} the mean value")

  result <- tag_parse_typed_return(tag)

  expect_equal(result$val$type, "numeric[1]")
  expect_equal(result$val$description, "the mean value")
})

test_that("@typed-return handles empty description", {
  tag <- list(raw = "{data.frame}")

  result <- tag_parse_typed_return(tag)

  expect_equal(result$val$type, "data.frame")
  expect_equal(result$val$description, "")
})

test_that("@typed-return handles union types", {
  tag <- list(raw = "{NULL | numeric} result or NULL if invalid")

  result <- tag_parse_typed_return(tag)

  expect_equal(result$val$type, "NULL | numeric")
  expect_equal(result$val$description, "result or NULL if invalid")
})

test_that("@typed-return errors on invalid format", {
  tag <- list(raw = "missing braces")

  expect_error(
    tag_parse_typed_return(tag),
    "Invalid.*@typedReturn.*format"
  )
})

test_that("@typed-param with S3 class notation", {
  # TODO: S3 class notation <lm> requires extending the parser
  # For now, use standard class notation
  tag <- list(raw = "model {class_lm} linear model object")

  result <- tag_parse_typed_param(tag)

  expect_equal(result$val$type, "class_lm")
  expect_equal(result$val$description, "linear model object")
})
