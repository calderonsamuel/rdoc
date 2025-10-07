test_that("base class types are recognized in annotations", {
  skip_if_not_installed("xml2")

  # Just verify the type annotations parse without error
  expect_no_error(validate_type_syntax("class_call"))
  expect_no_error(validate_type_syntax("class_environment"))
  expect_no_error(validate_type_syntax("class_function"))
  expect_no_error(validate_type_syntax("class_name"))

  # Verify they resolve to S7 classes
  expect_identical(type_string_to_s7_class("class_call"), S7::class_call)
  expect_identical(type_string_to_s7_class("class_environment"), S7::class_environment)
  expect_identical(type_string_to_s7_class("class_function"), S7::class_function)
  expect_identical(type_string_to_s7_class("class_name"), S7::class_name)
})

test_that("S7 union types are recognized (atomic, language, vector)", {
  skip_if_not_installed("S7")

  # Verify they resolve to S7 unions
  expect_s3_class(type_string_to_s7_class("class_atomic"), "S7_union")
  expect_s3_class(type_string_to_s7_class("class_language"), "S7_union")
  expect_s3_class(type_string_to_s7_class("class_vector"), "S7_union")

  # Verify compatibility: literal types should be compatible with unions
  expect_true(types_compatible("class_logical", "class_atomic"))
  expect_true(types_compatible("class_integer", "class_atomic"))
  expect_true(types_compatible("class_double", "class_atomic"))
  expect_true(types_compatible("class_character", "class_atomic"))

  expect_true(types_compatible("class_list", "class_vector"))
  expect_true(types_compatible("class_integer", "class_vector"))  # atomic is part of vector
})

test_that("S3 wrapper types are recognized (data.frame, Date, factor, formula)", {
  skip_if_not_installed("S7")

  # Verify they resolve to S7 S3 wrappers
  expect_s3_class(type_string_to_s7_class("class_data.frame"), "S7_S3_class")
  expect_s3_class(type_string_to_s7_class("class_Date"), "S7_S3_class")
  expect_s3_class(type_string_to_s7_class("class_factor"), "S7_S3_class")
  expect_s3_class(type_string_to_s7_class("class_formula"), "S7_S3_class")

  # Verify type compatibility
  expect_true(types_compatible("class_data.frame", "class_data.frame"))
  expect_true(types_compatible("class_Date", "class_Date"))
  expect_true(types_compatible("class_factor", "class_factor"))
})

test_that("POSIX types are recognized (POSIXct, POSIXlt, POSIXt)", {
  skip_if_not_installed("S7")

  # Verify they resolve to S7 S3 wrappers
  expect_s3_class(type_string_to_s7_class("class_POSIXct"), "S7_S3_class")
  expect_s3_class(type_string_to_s7_class("class_POSIXlt"), "S7_S3_class")
  expect_s3_class(type_string_to_s7_class("class_POSIXt"), "S7_S3_class")

  # Verify type compatibility
  expect_true(types_compatible("class_POSIXct", "class_POSIXct"))
  expect_true(types_compatible("class_POSIXlt", "class_POSIXlt"))
  expect_true(types_compatible("class_POSIXt", "class_POSIXt"))
})

test_that("POSIXct inherits from POSIXt", {
  skip_if_not_installed("S7")

  # POSIXct should be compatible with POSIXt (inheritance)
  expect_true(s7_class_compatible(S7::class_POSIXct, S7::class_POSIXt))
  expect_true(types_compatible("class_POSIXct", "class_POSIXt"))
})

test_that("any type accepts anything", {
  skip_if_not_installed("S7")

  # Verify 'any' resolves to S7::class_any
  expect_identical(type_string_to_s7_class("class_any"), S7::class_any)

  # All types should be compatible with 'any'
  expect_true(types_compatible("class_integer", "class_any"))
  expect_true(types_compatible("class_character", "class_any"))
  expect_true(types_compatible("class_logical", "class_any"))
  expect_true(types_compatible("NULL", "class_any"))
  expect_true(types_compatible("class_data.frame", "class_any"))
  expect_true(types_compatible("class_list", "class_any"))
})

test_that("missing type is forbidden with helpful error", {
  expect_error(
    rdoc:::validate_type_syntax("missing"),
    "Type 'missing' or 'class_missing' is not allowed"
  )

  expect_error(
    rdoc:::validate_type_syntax("missing"),
    "Use missing\\(arg\\)"
  )

  expect_error(
    rdoc:::validate_type_syntax("missing"),
    "\\{NULL \\| Type\\}"
  )
})

test_that("missing in unions is also forbidden", {
  expect_error(
    rdoc:::validate_type_syntax("missing | integer"),
    "Type 'missing' or 'class_missing' is not allowed"
  )

  expect_error(
    rdoc:::validate_type_syntax("integer | missing"),
    "Type 'missing' or 'class_missing' is not allowed"
  )
})

test_that("class_missing type is also forbidden", {
  expect_error(
    rdoc:::validate_type_syntax("class_missing"),
    "Type 'missing' or 'class_missing' is not allowed"
  )

  expect_error(
    rdoc:::validate_type_syntax("class_missing"),
    "Use missing\\(arg\\)"
  )

  expect_error(
    rdoc:::validate_type_syntax("class_missing"),
    "\\{NULL \\| Type\\}"
  )
})

test_that("class_missing in unions is also forbidden", {
  expect_error(
    rdoc:::validate_type_syntax("class_missing | integer"),
    "Type 'missing' or 'class_missing' is not allowed"
  )

  expect_error(
    rdoc:::validate_type_syntax("integer | class_missing"),
    "Type 'missing' or 'class_missing' is not allowed"
  )
})

test_that("type mismatches detected for new types", {
  skip_if_not_installed("xml2")

  code <- "
#' @typedParam x {class_call}
takes_call <- function(x) { x }

#' @typedParam x {class_environment}
takes_env <- function(x) { x }

#' @typedParam x {class_factor}
takes_factor <- function(x) { x }

# Should fail
takes_call(123)
takes_env('text')
takes_factor(1:10)
"

  lints <- lintr::lint(text = code, linters = list(rdoc::type_consistency_linter()))
  expect_length(lints, 3)
  expect_match(lints[[1]]$message, "class_call", ignore.case = TRUE)
  expect_match(lints[[2]]$message, "class_environment", ignore.case = TRUE)
  expect_match(lints[[3]]$message, "class_factor", ignore.case = TRUE)
})

test_that("atomic union accepts all atomic types", {
  skip_if_not_installed("S7")

  # All atomic types should be compatible with 'atomic'
  expect_true(types_compatible("class_logical", "class_atomic"))
  expect_true(types_compatible("class_integer", "class_atomic"))
  expect_true(types_compatible("class_double", "class_atomic"))
  expect_true(types_compatible("class_complex", "class_atomic"))
  expect_true(types_compatible("class_character", "class_atomic"))
  expect_true(types_compatible("class_raw", "class_atomic"))

  # Non-atomic should NOT be compatible
  expect_false(types_compatible("class_list", "class_atomic"))
  expect_false(types_compatible("class_data.frame", "class_atomic"))
})

test_that("language union accepts call and name", {
  skip_if_not_installed("S7")

  # language is call | name
  expect_true(types_compatible("class_call", "class_language"))
  expect_true(types_compatible("class_name", "class_language"))

  # Non-language types should NOT be compatible
  expect_false(types_compatible("class_integer", "class_language"))
  expect_false(types_compatible("class_character", "class_language"))
})

test_that("vector union accepts atomic, list, expression", {
  skip_if_not_installed("S7")

  # vector = atomic | list | expression
  expect_true(types_compatible("class_integer", "class_vector"))  # atomic member
  expect_true(types_compatible("class_double", "class_vector"))   # atomic member
  expect_true(types_compatible("class_list", "class_vector"))
  expect_true(types_compatible("class_expression", "class_vector"))

  # Non-vector types should NOT be compatible
  expect_false(types_compatible("class_data.frame", "class_vector"))
  expect_false(types_compatible("class_environment", "class_vector"))
})

test_that("new types work in return positions", {
  skip_if_not_installed("xml2")

  code <- "
#' @typedReturn {class_call}
returns_call <- function() { quote(foo()) }

#' @typedReturn {class_environment}
returns_env <- function() { new.env() }

#' @typedReturn {class_Date}
returns_date <- function() { Sys.Date() }

#' @typedParam x {class_call}
takes_call <- function(x) { x }

#' @typedParam env {class_environment}
takes_env <- function(env) { env }

#' @typedParam d {class_Date}
takes_date <- function(d) { d }

# Should all pass
takes_call(returns_call())
takes_env(returns_env())
takes_date(returns_date())
"

  lints <- lintr::lint(text = code, linters = list(rdoc::type_consistency_linter()))
  expect_length(lints, 0)
})

test_that("new types work with length constraints", {
  skip_if_not_installed("xml2")

  code <- "
#' @typedParam names {class_character[3]}
takes_names <- function(names) { names }

#' @typedParam items {class_list<class_integer>[5]}
takes_items <- function(items) { items }

# These should pass type checking (length checked at runtime)
takes_names(c('a', 'b', 'c'))
takes_items(list(1L, 2L, 3L, 4L, 5L))
"

  lints <- lintr::lint(text = code, linters = list(rdoc::type_consistency_linter()))
  expect_length(lints, 0)
})

test_that("new types work in union annotations", {
  skip_if_not_installed("xml2")

  code <- "
#' @typedParam x {NULL | class_Date}
maybe_date <- function(x) { x }

#' @typedParam x {class_call | class_name}
takes_call_or_name <- function(x) { x }

maybe_date(NULL)
maybe_date(Sys.Date())

takes_call_or_name(quote(foo()))
takes_call_or_name(quote(x))
"

  lints <- lintr::lint(text = code, linters = list(rdoc::type_consistency_linter()))
  expect_length(lints, 0)
})

test_that("class_ prefix forms work for new types", {
  skip_if_not_installed("xml2")

  code <- "
#' @typedParam x {class_call}
takes_call <- function(x) { x }

#' @typedParam env {class_environment}
takes_env <- function(env) { env }

#' @typedParam d {class_Date}
takes_date <- function(d) { d }

takes_call(quote(foo()))
takes_env(new.env())
takes_date(Sys.Date())
"

  lints <- lintr::lint(text = code, linters = list(rdoc::type_consistency_linter()))
  expect_length(lints, 0)
})
