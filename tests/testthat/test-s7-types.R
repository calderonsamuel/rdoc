# Tests for R/s7-types.R
# S7 type system integration and normalization

# normalize_type_name() tests ----

test_that("normalize_type_name strips class_ prefix", {
  expect_equal(normalize_type_name("class_integer"), "integer")
  expect_equal(normalize_type_name("class_double"), "double")
  expect_equal(normalize_type_name("class_character"), "character")
  expect_equal(normalize_type_name("class_logical"), "logical")
  expect_equal(normalize_type_name("class_numeric"), "numeric")
})

test_that("normalize_type_name handles types without prefix", {
  expect_equal(normalize_type_name("integer"), "integer")
  expect_equal(normalize_type_name("double"), "double")
  expect_equal(normalize_type_name("character"), "character")
  expect_equal(normalize_type_name("logical"), "logical")
  expect_equal(normalize_type_name("numeric"), "numeric")
})

test_that("normalize_type_name handles whitespace", {
  expect_equal(normalize_type_name("  integer  "), "integer")
  expect_equal(normalize_type_name("  class_integer  "), "integer")
})

test_that("normalize_type_name preserves S7 base types", {
  expect_equal(normalize_type_name("list"), "list")
  expect_equal(normalize_type_name("expression"), "expression")
  expect_equal(normalize_type_name("NULL"), "NULL")
  expect_equal(normalize_type_name("raw"), "raw")
  expect_equal(normalize_type_name("complex"), "complex")
})

# is_s7_base_type() tests ----

test_that("is_s7_base_type recognizes S7 base types", {
  expect_true(is_s7_base_type("integer"))
  expect_true(is_s7_base_type("double"))
  expect_true(is_s7_base_type("character"))
  expect_true(is_s7_base_type("logical"))
  expect_true(is_s7_base_type("numeric"))
  expect_true(is_s7_base_type("list"))
  expect_true(is_s7_base_type("NULL"))
  expect_true(is_s7_base_type("raw"))
  expect_true(is_s7_base_type("complex"))
  expect_true(is_s7_base_type("expression"))
})

test_that("is_s7_base_type recognizes S7 types with class_ prefix", {
  expect_true(is_s7_base_type("class_integer"))
  expect_true(is_s7_base_type("class_double"))
  expect_true(is_s7_base_type("class_character"))
  expect_true(is_s7_base_type("class_logical"))
  expect_true(is_s7_base_type("class_numeric"))
})

test_that("is_s7_base_type rejects non-S7 types", {
  expect_false(is_s7_base_type("data.frame"))
  expect_false(is_s7_base_type("matrix"))
  expect_false(is_s7_base_type("factor"))
  expect_false(is_s7_base_type("Date"))
  expect_false(is_s7_base_type("unknown"))
})

# type_string_to_s7_class() tests ----

test_that("type_string_to_s7_class maps to S7 classes", {
  skip_if_not_installed("S7")

  expect_identical(type_string_to_s7_class("integer"), S7::class_integer)
  expect_identical(type_string_to_s7_class("double"), S7::class_double)
  expect_identical(type_string_to_s7_class("character"), S7::class_character)
  expect_identical(type_string_to_s7_class("logical"), S7::class_logical)
  expect_identical(type_string_to_s7_class("numeric"), S7::class_numeric)
})

test_that("type_string_to_s7_class handles class_ prefix", {
  skip_if_not_installed("S7")

  expect_identical(type_string_to_s7_class("class_integer"), S7::class_integer)
  expect_identical(type_string_to_s7_class("class_double"), S7::class_double)
  expect_identical(type_string_to_s7_class("class_character"), S7::class_character)
})

test_that("type_string_to_s7_class returns NULL for non-S7 types and NULL type", {
  # NULL type returns NULL (since it's not an S7 class)
  expect_null(type_string_to_s7_class("NULL"))
  # Unknown types return NULL
  expect_null(type_string_to_s7_class("data.frame"))
  expect_null(type_string_to_s7_class("matrix"))
  expect_null(type_string_to_s7_class("unknown"))
})

# s7_class_to_type_string() tests ----

test_that("s7_class_to_type_string converts S7 classes to strings", {
  skip_if_not_installed("S7")

  expect_equal(s7_class_to_type_string(S7::class_integer), "integer")
  expect_equal(s7_class_to_type_string(S7::class_double), "double")
  expect_equal(s7_class_to_type_string(S7::class_character), "character")
  expect_equal(s7_class_to_type_string(S7::class_logical), "logical")
  expect_equal(s7_class_to_type_string(S7::class_numeric), "numeric")
})

# s7_types_compatible() tests ----

test_that("s7_types_compatible handles exact matches", {
  expect_true(s7_types_compatible("integer", "integer"))
  expect_true(s7_types_compatible("double", "double"))
  expect_true(s7_types_compatible("character", "character"))
})

test_that("s7_types_compatible handles class_ prefix in both arguments", {
  expect_true(s7_types_compatible("class_integer", "integer"))
  expect_true(s7_types_compatible("integer", "class_integer"))
  expect_true(s7_types_compatible("class_integer", "class_integer"))
})

test_that("s7_types_compatible handles numeric union", {
  # numeric accepts integer or double
  expect_true(s7_types_compatible("integer", "numeric"))
  expect_true(s7_types_compatible("double", "numeric"))
  expect_true(s7_types_compatible("numeric", "integer"))
  expect_true(s7_types_compatible("numeric", "double"))
})

test_that("s7_types_compatible rejects incompatible types", {
  expect_false(s7_types_compatible("integer", "character"))
  expect_false(s7_types_compatible("double", "logical"))
  expect_false(s7_types_compatible("character", "integer"))
})

# Integration tests with types_compatible() ----

test_that("types_compatible uses normalize_type_name for basic types", {
  expect_true(types_compatible("class_integer", "integer"))
  expect_true(types_compatible("integer", "class_integer"))
  expect_true(types_compatible("class_integer", "class_integer"))
})

test_that("types_compatible handles class_ prefix in union types", {
  expect_true(types_compatible("class_integer", "integer | NULL"))
  expect_true(types_compatible("integer", "class_integer | NULL"))
  expect_true(types_compatible("class_integer | NULL", "integer"))
})

test_that("types_compatible handles S7 numeric union with class_ prefix", {
  expect_true(types_compatible("class_integer", "numeric"))
  expect_true(types_compatible("class_double", "numeric"))
  expect_true(types_compatible("integer", "class_numeric"))
  expect_true(types_compatible("double", "class_numeric"))
})

test_that("types_compatible handles length constraints with class_ prefix", {
  expect_true(types_compatible("class_integer(1)", "integer(1)"))
  expect_true(types_compatible("integer(1)", "class_integer(1)"))
  expect_true(types_compatible("class_integer(1)", "integer"))
})
