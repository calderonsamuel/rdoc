test_that("parse_type_spec handles simple types", {
  result <- parse_type_spec("class_numeric")

  expect_equal(result$base, "class_numeric")
  expect_null(result$length)
})

test_that("parse_type_spec handles function parameter notation", {
  # Note: parse_type_spec supports (n) for function signatures, not type constraints
  # For type constraints, use parse_type_constraints with [n] syntax
  result <- parse_type_spec("class_function(x)")

  expect_equal(result$base, "class_function")
})

test_that("parse_type_spec handles length variable notation", {
  result <- parse_type_spec("class_character(n)")

  expect_equal(result$base, "class_character")
  expect_equal(result$length, "n")
})

test_that("parse_type_spec handles union types", {
  result <- parse_type_spec("class_character | NULL")

  expect_equal(result$type, "union")
  expect_length(result$types, 2)
  expect_equal(result$types[[1]]$base, "class_character")
  expect_equal(result$types[[2]]$base, "NULL")
})

test_that("parse_type_spec handles multi-union types", {
  result <- parse_type_spec("class_numeric | class_integer | class_complex")

  expect_equal(result$type, "union")
  expect_length(result$types, 3)
})

test_that("parse_type_spec handles S3 class notation", {
  result <- parse_type_spec("<lm>")

  expect_equal(result$base, "class")
  expect_equal(result$class, "lm")
})

test_that("parse_type_spec handles function signatures", {
  result <- parse_type_spec("class_function(class_numeric): class_logical")

  expect_equal(result$base, "class_function")
  expect_equal(result$args, "class_numeric")
  expect_equal(result$return, "class_logical")
})

test_that("parse_type_spec handles function with multiple args", {
  result <- parse_type_spec("class_function(class_numeric, class_character): class_data.frame")

  expect_equal(result$base, "class_function")
  expect_equal(result$args, c("class_numeric", "class_character"))
  expect_equal(result$return, "class_data.frame")
})

test_that("parse_type_spec handles function with no return", {
  result <- parse_type_spec("class_function(class_numeric)")

  expect_equal(result$base, "class_function")
  expect_equal(result$args, "class_numeric")
  expect_null(result$return)
})

test_that("is_union_type detects union types", {
  expect_true(is_union_type("class_character | NULL"))
  expect_true(is_union_type("a | b | c"))
  expect_false(is_union_type("class_numeric"))
})

test_that("split_union_types splits correctly", {
  result <- split_union_types("class_character | NULL")

  expect_equal(result, c("class_character", "NULL"))
})

test_that("split_union_types trims whitespace", {
  result <- split_union_types("class_character  |  NULL")

  expect_equal(result, c("class_character", "NULL"))
})

test_that("validate_type_spec validates correct types", {
  expect_true(validate_type_spec("class_numeric"))
  expect_true(validate_type_spec("class_numeric(1)"))
  expect_true(validate_type_spec("class_character | NULL"))
  expect_true(validate_type_spec("<lm>"))
})

test_that("is_base_type recognizes base types", {
  expect_true(is_base_type("class_numeric"))
  expect_true(is_base_type("class_character"))
  expect_true(is_base_type("class_data.frame"))
  expect_false(is_base_type("custom_type"))
})

test_that("is_base_type handles types with length constraints", {
  expect_true(is_base_type("class_numeric(1)"))
  expect_true(is_base_type("class_character(n)"))
})

test_that("base_r_types returns expected types", {
  types <- base_r_types()

  expect_true("class_numeric" %in% types)
  expect_true("class_character" %in% types)
  expect_true("class_data.frame" %in% types)
  expect_true("NULL" %in% types)
})

test_that("parse_type_spec handles whitespace", {
  result <- parse_type_spec("  class_numeric  ")

  expect_equal(result$base, "class_numeric")
})

test_that("parse_type_spec handles complex union with constraints", {
  result <- parse_type_spec("class_numeric(1) | NULL")

  expect_equal(result$type, "union")
  expect_equal(result$types[[1]]$base, "class_numeric")
  expect_equal(result$types[[1]]$length, "1")
  expect_equal(result$types[[2]]$base, "NULL")
})
