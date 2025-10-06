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

# s7_class_compatible() tests ----

test_that("s7_class_compatible handles exact matches", {
  skip_if_not_installed("S7")

  expect_true(s7_class_compatible(S7::class_integer, S7::class_integer))
  expect_true(s7_class_compatible(S7::class_double, S7::class_double))
  expect_true(s7_class_compatible(S7::class_character, S7::class_character))
})

test_that("s7_class_compatible handles numeric union", {
  skip_if_not_installed("S7")

  # numeric accepts integer or double
  expect_true(s7_class_compatible(S7::class_integer, S7::class_numeric))
  expect_true(s7_class_compatible(S7::class_double, S7::class_numeric))
})

test_that("s7_class_compatible rejects incompatible types", {
  skip_if_not_installed("S7")

  expect_false(s7_class_compatible(S7::class_integer, S7::class_character))
  expect_false(s7_class_compatible(S7::class_double, S7::class_logical))
  expect_false(s7_class_compatible(S7::class_character, S7::class_integer))
})

test_that("s7_class_compatible handles inheritance", {
  skip_if_not_installed("S7")

  # Create parent and child classes
  Parent <- S7::new_class("Parent")
  Child <- S7::new_class("Child", parent = Parent)

  # Child should be compatible with Parent
  expect_true(s7_class_compatible(Child, Parent))

  # Parent should NOT be compatible with Child
  expect_false(s7_class_compatible(Parent, Child))
})

# Integration tests with types_compatible() (S7-first) ----

test_that("types_compatible uses S7 for base types", {
  # Both short and class_ prefix forms resolve to S7 classes
  expect_true(types_compatible("class_integer", "integer"))
  expect_true(types_compatible("integer", "class_integer"))
  expect_true(types_compatible("class_integer", "class_integer"))
})

test_that("types_compatible handles S7 numeric union", {
  # S7's class_numeric is integer | double
  expect_true(types_compatible("class_integer", "numeric"))
  expect_true(types_compatible("class_double", "numeric"))
  expect_true(types_compatible("integer", "class_numeric"))
  expect_true(types_compatible("double", "class_numeric"))
})

test_that("types_compatible handles rdoc union types with S7", {
  # rdoc's | syntax still works, using S7 under the hood
  # Subtype → Union is valid (widening)
  expect_true(types_compatible("class_integer", "NULL | integer"))
  expect_true(types_compatible("integer", "NULL | class_integer"))
  expect_true(types_compatible("NULL", "NULL | integer"))

  # Union → Subtype is INVALID (narrowing without check)
  expect_false(types_compatible("NULL | class_integer", "integer"))
})

test_that("types_compatible handles length constraints", {
  # Length constraints are stripped, then S7 compatibility checked
  expect_true(types_compatible("class_integer[1]", "integer[1]"))
  expect_true(types_compatible("integer[1]", "class_integer[1]"))
  expect_true(types_compatible("class_integer[1]", "integer"))
})

test_that("types_compatible falls back for non-S7 types", {
  # Non-S7 types use string-based compatibility
  expect_true(types_compatible("data.frame", "data.frame"))
  expect_true(types_compatible("matrix", "matrix"))
  expect_false(types_compatible("data.frame", "matrix"))
})

# =============================================================================
# RDOC UNION TO S7 CONVERSION (Phase 14.2)
# =============================================================================

test_that("rdoc_union_to_s7 converts NULL | Type unions", {
  # Basic NULL union
  ast <- parse_type_syntax("NULL | integer")
  s7_union <- rdoc_union_to_s7(ast)

  expect_s3_class(s7_union, "S7_union")
  expect_equal(length(s7_union$classes), 2)
  expect_true(is.null(s7_union$classes[[1]]))  # NULL is first
  expect_equal(s7_union$classes[[2]]$class, "integer")
})

test_that("rdoc_union_to_s7 handles multi-way NULL unions", {
  # NULL | char | int
  ast <- parse_type_syntax("NULL | character | integer")
  s7_union <- rdoc_union_to_s7(ast)

  expect_s3_class(s7_union, "S7_union")
  expect_equal(length(s7_union$classes), 3)
  expect_true(is.null(s7_union$classes[[1]]))
  expect_equal(s7_union$classes[[2]]$class, "character")
  expect_equal(s7_union$classes[[3]]$class, "integer")
})

test_that("rdoc_union_to_s7 handles non-NULL unions", {
  # integer | character (no NULL)
  ast <- parse_type_syntax("integer | character")
  s7_union <- rdoc_union_to_s7(ast)

  expect_s3_class(s7_union, "S7_union")
  expect_equal(length(s7_union$classes), 2)
  expect_equal(s7_union$classes[[1]]$class, "integer")
  expect_equal(s7_union$classes[[2]]$class, "character")
})

test_that("rdoc_union_to_s7 handles single types", {
  # Not a union, just single type
  ast <- parse_type_syntax("integer")
  s7_class <- rdoc_union_to_s7(ast)

  expect_s3_class(s7_class, "S7_base_class")
  expect_equal(s7_class$class, "integer")
})

test_that("rdoc_union_to_s7 handles standalone NULL", {
  ast <- parse_type_syntax("NULL")
  result <- rdoc_union_to_s7(ast)

  expect_null(result)
})

test_that("rdoc_union_to_s7 uses S7 class objects", {
  # Verify we're using actual S7 classes
  ast <- parse_type_syntax("NULL | integer")
  s7_union <- rdoc_union_to_s7(ast)

  # Check that union members are actual S7 class objects
  expect_true(is.null(s7_union$classes[[1]]))  # NULL
  expect_equal(s7_union$classes[[2]], S7::class_integer)  # S7 class object
})

test_that("rdoc_union_to_s7 validates with s7_class_compatible", {
  # Create union
  ast <- parse_type_syntax("NULL | integer")
  s7_union <- rdoc_union_to_s7(ast)

  # Test compatibility
  expect_true(s7_class_compatible(S7::class_integer, s7_union))
  expect_true(s7_class_compatible(NULL, s7_union))
  expect_false(s7_class_compatible(S7::class_character, s7_union))
})

test_that("rdoc_union_to_s7 works with class_ prefix", {
  # Both syntaxes should work
  ast1 <- parse_type_syntax("NULL | integer")
  ast2 <- parse_type_syntax("NULL | class_integer")

  s7_union1 <- rdoc_union_to_s7(ast1)
  s7_union2 <- rdoc_union_to_s7(ast2)

  # Both should resolve to same S7 class
  expect_equal(s7_union1$classes[[2]], s7_union2$classes[[2]])
  expect_equal(s7_union1$classes[[2]], S7::class_integer)
})

test_that("rdoc_union_to_s7 handles complex types (future-proofing)", {
  # Currently ignores constraints, but should not error
  ast <- parse_type_syntax("NULL | list<integer>")
  s7_union <- rdoc_union_to_s7(ast)

  expect_s3_class(s7_union, "S7_union")
  expect_true(is.null(s7_union$classes[[1]]))
  expect_equal(s7_union$classes[[2]]$class, "list")

  # With length constraint
  ast <- parse_type_syntax("NULL | integer[5]")
  s7_union <- rdoc_union_to_s7(ast)

  expect_s3_class(s7_union, "S7_union")
  expect_equal(s7_union$classes[[2]]$class, "integer")
})
