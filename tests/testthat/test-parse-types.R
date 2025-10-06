test_that("parse_type_spec handles simple types", {
  result <- parse_type_spec("numeric")

  expect_equal(result$base, "numeric")
  expect_null(result$length)
})

test_that("parse_type_spec handles function parameter notation", {
  # Note: parse_type_spec supports (n) for function signatures, not type constraints
  # For type constraints, use parse_type_constraints with [n] syntax
  result <- parse_type_spec("function(x)")

  expect_equal(result$base, "function")
})

test_that("parse_type_spec handles length variable notation", {
  result <- parse_type_spec("character(n)")

  expect_equal(result$base, "character")
  expect_equal(result$length, "n")
})

test_that("parse_type_spec handles union types", {
  result <- parse_type_spec("character | NULL")

  expect_equal(result$type, "union")
  expect_length(result$types, 2)
  expect_equal(result$types[[1]]$base, "character")
  expect_equal(result$types[[2]]$base, "NULL")
})

test_that("parse_type_spec handles multi-union types", {
  result <- parse_type_spec("numeric | integer | complex")

  expect_equal(result$type, "union")
  expect_length(result$types, 3)
})

test_that("parse_type_spec handles S3 class notation", {
  result <- parse_type_spec("<lm>")

  expect_equal(result$base, "class")
  expect_equal(result$class, "lm")
})

test_that("parse_type_spec handles function signatures", {
  result <- parse_type_spec("function(numeric): logical")

  expect_equal(result$base, "function")
  expect_equal(result$args, "numeric")
  expect_equal(result$return, "logical")
})

test_that("parse_type_spec handles function with multiple args", {
  result <- parse_type_spec("function(numeric, character): data.frame")

  expect_equal(result$base, "function")
  expect_equal(result$args, c("numeric", "character"))
  expect_equal(result$return, "data.frame")
})

test_that("parse_type_spec handles function with no return", {
  result <- parse_type_spec("function(numeric)")

  expect_equal(result$base, "function")
  expect_equal(result$args, "numeric")
  expect_null(result$return)
})

test_that("is_union_type detects union types", {
  expect_true(is_union_type("character | NULL"))
  expect_true(is_union_type("a | b | c"))
  expect_false(is_union_type("numeric"))
})

test_that("split_union_types splits correctly", {
  result <- split_union_types("character | NULL")

  expect_equal(result, c("character", "NULL"))
})

test_that("split_union_types trims whitespace", {
  result <- split_union_types("character  |  NULL")

  expect_equal(result, c("character", "NULL"))
})

test_that("validate_type_spec validates correct types", {
  expect_true(validate_type_spec("numeric"))
  expect_true(validate_type_spec("numeric(1)"))
  expect_true(validate_type_spec("character | NULL"))
  expect_true(validate_type_spec("<lm>"))
})

test_that("is_base_type recognizes base types", {
  expect_true(is_base_type("numeric"))
  expect_true(is_base_type("character"))
  expect_true(is_base_type("data.frame"))
  expect_false(is_base_type("custom_type"))
})

test_that("is_base_type handles types with length constraints", {
  expect_true(is_base_type("numeric(1)"))
  expect_true(is_base_type("character(n)"))
})

test_that("base_r_types returns expected types", {
  types <- base_r_types()

  expect_true("numeric" %in% types)
  expect_true("character" %in% types)
  expect_true("data.frame" %in% types)
  expect_true("NULL" %in% types)
})

test_that("parse_type_spec handles whitespace", {
  result <- parse_type_spec("  numeric  ")

  expect_equal(result$base, "numeric")
})

test_that("parse_type_spec handles complex union with constraints", {
  result <- parse_type_spec("numeric(1) | NULL")

  expect_equal(result$type, "union")
  expect_equal(result$types[[1]]$base, "numeric")
  expect_equal(result$types[[1]]$length, "1")
  expect_equal(result$types[[2]]$base, "NULL")
})
