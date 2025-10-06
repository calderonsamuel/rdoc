test_that("base class types are recognized in annotations", {
  skip_if_not_installed("xml2")

  # Just verify the type annotations parse without error
  expect_no_error(validate_type_syntax("call"))
  expect_no_error(validate_type_syntax("environment"))
  expect_no_error(validate_type_syntax("function"))
  expect_no_error(validate_type_syntax("name"))

  # Verify they resolve to S7 classes
  expect_identical(type_string_to_s7_class("call"), S7::class_call)
  expect_identical(type_string_to_s7_class("environment"), S7::class_environment)
  expect_identical(type_string_to_s7_class("function"), S7::class_function)
  expect_identical(type_string_to_s7_class("name"), S7::class_name)
})

test_that("S7 union types are recognized (atomic, language, vector)", {
  skip_if_not_installed("S7")

  # Verify they resolve to S7 unions
  expect_s3_class(type_string_to_s7_class("atomic"), "S7_union")
  expect_s3_class(type_string_to_s7_class("language"), "S7_union")
  expect_s3_class(type_string_to_s7_class("vector"), "S7_union")

  # Verify compatibility: literal types should be compatible with unions
  expect_true(types_compatible("logical", "atomic"))
  expect_true(types_compatible("integer", "atomic"))
  expect_true(types_compatible("double", "atomic"))
  expect_true(types_compatible("character", "atomic"))

  expect_true(types_compatible("list", "vector"))
  expect_true(types_compatible("integer", "vector"))  # atomic is part of vector
})

test_that("S3 wrapper types are recognized (data.frame, Date, factor, formula)", {
  skip_if_not_installed("S7")

  # Verify they resolve to S7 S3 wrappers
  expect_s3_class(type_string_to_s7_class("data.frame"), "S7_S3_class")
  expect_s3_class(type_string_to_s7_class("Date"), "S7_S3_class")
  expect_s3_class(type_string_to_s7_class("factor"), "S7_S3_class")
  expect_s3_class(type_string_to_s7_class("formula"), "S7_S3_class")

  # Verify type compatibility
  expect_true(types_compatible("data.frame", "data.frame"))
  expect_true(types_compatible("Date", "Date"))
  expect_true(types_compatible("factor", "factor"))
})

test_that("POSIX types are recognized (POSIXct, POSIXlt, POSIXt)", {
  skip_if_not_installed("S7")

  # Verify they resolve to S7 S3 wrappers
  expect_s3_class(type_string_to_s7_class("POSIXct"), "S7_S3_class")
  expect_s3_class(type_string_to_s7_class("POSIXlt"), "S7_S3_class")
  expect_s3_class(type_string_to_s7_class("POSIXt"), "S7_S3_class")

  # Verify type compatibility
  expect_true(types_compatible("POSIXct", "POSIXct"))
  expect_true(types_compatible("POSIXlt", "POSIXlt"))
  expect_true(types_compatible("POSIXt", "POSIXt"))
})

test_that("POSIXct inherits from POSIXt", {
  skip_if_not_installed("S7")

  # POSIXct should be compatible with POSIXt (inheritance)
  expect_true(s7_class_compatible(S7::class_POSIXct, S7::class_POSIXt))
  expect_true(types_compatible("POSIXct", "POSIXt"))
})

test_that("any type accepts anything", {
  skip_if_not_installed("S7")

  # Verify 'any' resolves to S7::class_any
  expect_identical(type_string_to_s7_class("any"), S7::class_any)

  # All types should be compatible with 'any'
  expect_true(types_compatible("integer", "any"))
  expect_true(types_compatible("character", "any"))
  expect_true(types_compatible("logical", "any"))
  expect_true(types_compatible("NULL", "any"))
  expect_true(types_compatible("data.frame", "any"))
  expect_true(types_compatible("list", "any"))
})

test_that("missing type is forbidden with helpful error", {
  expect_error(
    rdoc:::validate_type_syntax("missing"),
    "Type 'missing' is not allowed"
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
    "Type 'missing' is not allowed"
  )

  expect_error(
    rdoc:::validate_type_syntax("integer | missing"),
    "Type 'missing' is not allowed"
  )
})

test_that("type mismatches detected for new types", {
  skip_if_not_installed("xml2")

  code <- "
#' @typedParam x {call}
takes_call <- function(x) { x }

#' @typedParam x {environment}
takes_env <- function(x) { x }

#' @typedParam x {factor}
takes_factor <- function(x) { x }

# Should fail
takes_call(123)
takes_env('text')
takes_factor(1:10)
"

  lints <- lintr::lint(text = code, linters = list(rdoc::type_consistency_linter()))
  expect_length(lints, 3)
  expect_match(lints[[1]]$message, "call", ignore.case = TRUE)
  expect_match(lints[[2]]$message, "environment", ignore.case = TRUE)
  expect_match(lints[[3]]$message, "factor", ignore.case = TRUE)
})

test_that("atomic union accepts all atomic types", {
  skip_if_not_installed("S7")

  # All atomic types should be compatible with 'atomic'
  expect_true(types_compatible("logical", "atomic"))
  expect_true(types_compatible("integer", "atomic"))
  expect_true(types_compatible("double", "atomic"))
  expect_true(types_compatible("complex", "atomic"))
  expect_true(types_compatible("character", "atomic"))
  expect_true(types_compatible("raw", "atomic"))

  # Non-atomic should NOT be compatible
  expect_false(types_compatible("list", "atomic"))
  expect_false(types_compatible("data.frame", "atomic"))
})

test_that("language union accepts call and name", {
  skip_if_not_installed("S7")

  # language is call | name
  expect_true(types_compatible("call", "language"))
  expect_true(types_compatible("name", "language"))

  # Non-language types should NOT be compatible
  expect_false(types_compatible("integer", "language"))
  expect_false(types_compatible("character", "language"))
})

test_that("vector union accepts atomic, list, expression", {
  skip_if_not_installed("S7")

  # vector = atomic | list | expression
  expect_true(types_compatible("integer", "vector"))  # atomic member
  expect_true(types_compatible("double", "vector"))   # atomic member
  expect_true(types_compatible("list", "vector"))
  expect_true(types_compatible("expression", "vector"))

  # Non-vector types should NOT be compatible
  expect_false(types_compatible("data.frame", "vector"))
  expect_false(types_compatible("environment", "vector"))
})

test_that("new types work in return positions", {
  skip_if_not_installed("xml2")

  code <- "
#' @typedReturn {call}
returns_call <- function() { quote(foo()) }

#' @typedReturn {environment}
returns_env <- function() { new.env() }

#' @typedReturn {Date}
returns_date <- function() { Sys.Date() }

#' @typedParam x {call}
takes_call <- function(x) { x }

#' @typedParam env {environment}
takes_env <- function(env) { env }

#' @typedParam d {Date}
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
#' @typedParam names {character[3]}
takes_names <- function(names) { names }

#' @typedParam items {list<integer>[5]}
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
#' @typedParam x {NULL | Date}
maybe_date <- function(x) { x }

#' @typedParam x {call | name}
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
