# Tests for Phase 24.1: External Type Support (package::class syntax)

test_that("lexer tokenizes :: operator", {
  tokens <- lex_type_syntax("roxygen2::roclet")

  expect_equal(length(tokens), 4)  # package, ::, class, EOF
  expect_equal(tokens[[1]]$type, "IDENTIFIER")
  expect_equal(tokens[[1]]$value, "roxygen2")
  expect_equal(tokens[[2]]$type, "DOUBLE_COLON")
  expect_equal(tokens[[2]]$value, "::")
  expect_equal(tokens[[3]]$type, "IDENTIFIER")
  expect_equal(tokens[[3]]$value, "roclet")
  expect_equal(tokens[[4]]$type, "EOF")
})

test_that("lexer rejects single colon", {
  expect_error(
    lex_type_syntax("roxygen2:roclet"),
    "Use '::' for package qualification"
  )
})

test_that("parser handles package-qualified types", {
  ast <- parse_type_syntax("roxygen2::roclet")

  expect_equal(ast$node_type, "type")
  expect_equal(ast$base_type, "roclet")
  expect_equal(ast$package, "roxygen2")
  expect_null(ast$element_type)
  expect_null(ast$length_constraint)
})

test_that("parser handles package-qualified types with length constraint", {
  ast <- parse_type_syntax("roxygen2::roclet[1]")

  expect_equal(ast$node_type, "type")
  expect_equal(ast$base_type, "roclet")
  expect_equal(ast$package, "roxygen2")
  expect_equal(ast$length_constraint, 1)
})

test_that("parser handles list with external element type", {
  ast <- parse_type_syntax("list<roxygen2::roclet>")

  expect_equal(ast$node_type, "type")
  expect_equal(ast$base_type, "list")
  expect_null(ast$package)
  expect_equal(ast$element_type$node_type, "type")
  expect_equal(ast$element_type$base_type, "roclet")
  expect_equal(ast$element_type$package, "roxygen2")
})

test_that("parser handles complex external type combinations", {
  ast <- parse_type_syntax("list<roxygen2::roclet>[3]")

  expect_equal(ast$base_type, "list")
  expect_null(ast$package)
  expect_equal(ast$length_constraint, 3)
  expect_equal(ast$element_type$base_type, "roclet")
  expect_equal(ast$element_type$package, "roxygen2")
})

test_that("parser handles unions with external types", {
  ast <- parse_type_syntax("roxygen2::roclet | lintr::Linter")

  expect_equal(ast$node_type, "union")
  expect_equal(length(ast$types), 2)
  expect_equal(ast$types[[1]]$base_type, "roclet")
  expect_equal(ast$types[[1]]$package, "roxygen2")
  expect_equal(ast$types[[2]]$base_type, "Linter")
  expect_equal(ast$types[[2]]$package, "lintr")
})

test_that("parser handles mixed internal and external types in unions", {
  ast <- parse_type_syntax("class_integer | roxygen2::roclet")

  expect_equal(ast$node_type, "union")
  expect_equal(length(ast$types), 2)
  expect_equal(ast$types[[1]]$base_type, "class_integer")
  expect_null(ast$types[[1]]$package)
  expect_equal(ast$types[[2]]$base_type, "roclet")
  expect_equal(ast$types[[2]]$package, "roxygen2")
})

test_that("parser rejects incomplete package qualification", {
  expect_error(
    parse_type_syntax("roxygen2::"),
    "Expected class name after '::'"
  )
})

test_that("ast_to_string preserves package qualification", {
  ast <- parse_type_syntax("roxygen2::roclet")
  result <- ast_to_string(ast)

  expect_equal(result, "roxygen2::roclet")
})

test_that("ast_to_string handles complex external types", {
  ast <- parse_type_syntax("list<roxygen2::roclet>[3]")
  result <- ast_to_string(ast)

  expect_equal(result, "list<roxygen2::roclet>[3]")
})

test_that("ast_to_string handles unions with external types", {
  ast <- parse_type_syntax("roxygen2::roclet | lintr::Linter")
  result <- ast_to_string(ast)

  expect_equal(result, "roxygen2::roclet | lintr::Linter")
})

test_that("resolve_external_type creates S7 wrapper for S3 class", {
  s7_class <- resolve_external_type("roxygen2::roclet")

  expect_s3_class(s7_class, "S7_S3_class")
  # S7 wrapper doesn't store package name, just class name
})

test_that("resolve_external_type returns NULL for non-external types", {
  result <- resolve_external_type("class_integer")

  expect_null(result)
})

test_that("resolve_external_type returns NULL for invalid syntax", {
  result <- resolve_external_type("invalid::syntax::here")

  expect_null(result)
})

test_that("type_string_to_s7_class handles external types", {
  s7_class <- type_string_to_s7_class("roxygen2::roclet")

  expect_s3_class(s7_class, "S7_S3_class")
})

test_that("type_string_to_s7_class still handles built-in S7 types", {
  s7_class <- type_string_to_s7_class("class_integer")

  expect_identical(s7_class, S7::class_integer)
})

test_that("rdoc_union_to_s7 handles external types in unions", {
  ast <- parse_type_syntax("class_integer | roxygen2::roclet")
  s7_union <- rdoc_union_to_s7(ast)

  # Should create a union without error
  expect_s3_class(s7_union, "S7_union")
})

test_that("types_compatible: external type matches itself", {
  result <- types_compatible("roxygen2::roclet", "roxygen2::roclet")

  expect_true(result)
})

test_that("types_compatible: different external types don't match", {
  result <- types_compatible("roxygen2::roclet", "lintr::Linter")

  expect_false(result)
})

test_that("types_compatible: external type doesn't match built-in (Phase 24.1 - no inheritance)", {
  # Phase 24.1: No inheritance checking, so roclet (which inherits from list)
  # should NOT match class_list
  result <- types_compatible("roxygen2::roclet", "class_list")

  expect_false(result)
})

test_that("types_compatible: external type doesn't match different package", {
  result <- types_compatible("roxygen2::roclet", "other::roclet")

  expect_false(result)
})

test_that("types_compatible handles external types in unions", {
  result <- types_compatible("roxygen2::roclet", "roxygen2::roclet | lintr::Linter")

  expect_true(result)
})

test_that("external types work in type annotations (integration test)", {
  skip_if_not_installed("lintr")

  lint_file <- withr::local_tempfile(fileext = ".R")
  writeLines(c(
    "#' Function returning external type",
    "#' @typedReturn {roxygen2::roclet}",
    "#' @export",
    "get_roclet <- function() {",
    "  roxygen2::roclet('test')",
    "}"
  ), lint_file)

  # Should not error during linting
  expect_no_error({
    lints <- lintr::lint(lint_file, linters = list(type_consistency = type_consistency_linter(mode = "exported")))
  })
})

test_that("external types propagate through function calls (integration test)", {
  skip_if_not_installed("lintr")

  lint_file <- withr::local_tempfile(fileext = ".R")
  writeLines(c(
    "#' Get a roclet (skip return validation for Phase 24.1)",
    "#' @typedParam name {class_character[1]}",
    "get_roclet <- function(name) {",
    "  # Skipping @typedReturn to avoid return validation",
    "  # Phase 24.1 focuses on parameter type checking",
    "  roxygen2::roclet(name)",
    "}",
    "",
    "#' Process a roclet - this function has type annotations",
    "#' @typedParam roc {roxygen2::roclet}",
    "process_roclet <- function(roc) {",
    "  # Just check that roc parameter validates correctly",
    "  roc",
    "}",
    "",
    "# Direct usage with explicit type",
    "my_roclet <- roxygen2::roclet('test')",
    "#' @typedParam x {roxygen2::roclet}",
    "use_roclet <- function(x) x"
  ), lint_file)

  lints <- lintr::lint(lint_file, linters = list(type_consistency = type_consistency_linter()))

  # Should have no type errors for the typed functions
  expect_length(lints, 0)
})

test_that("external types reject type mismatches (integration test)", {
  skip_if_not_installed("lintr")

  lint_file <- withr::local_tempfile(fileext = ".R")
  writeLines(c(
    "#' Get a roclet",
    "#' @typedReturn {roxygen2::roclet}",
    "get_roclet <- function() roxygen2::roclet('test')",
    "",
    "#' Process a linter (wrong type)",
    "#' @typedParam lint {lintr::Linter}",
    "process_linter <- function(lint) lint()",
    "",
    "# Usage",
    "r <- get_roclet()",
    "process_linter(r)  # Should error: roclet != Linter"
  ), lint_file)

  lints <- lintr::lint(lint_file, linters = list(type_consistency = type_consistency_linter()))

  # Should have 1 type error
  expect_gte(length(lints), 1)

  # Check that the error message mentions the type mismatch
  lint_messages <- sapply(lints, function(l) l$message)
  expect_true(any(grepl("lintr::Linter", lint_messages)))
})

# Edge Case Tests

test_that("lexer rejects triple colon (:::)", {
  # Triple colon is for internal functions, not allowed in type annotations
  expect_error(
    lex_type_syntax("roxygen2:::internal"),
    "Use '::' for package qualification"
  )
})

test_that("parser handles NULL | external type unions", {
  ast <- parse_type_syntax("NULL | roxygen2::roclet")

  expect_equal(ast$node_type, "union")
  expect_equal(length(ast$types), 2)
  expect_equal(ast$types[[1]]$base_type, "NULL")
  expect_null(ast$types[[1]]$package)
  expect_equal(ast$types[[2]]$base_type, "roclet")
  expect_equal(ast$types[[2]]$package, "roxygen2")
})

test_that("types_compatible: NULL | external type works correctly", {
  # NULL matches NULL | roxygen2::roclet
  result1 <- types_compatible("NULL", "NULL | roxygen2::roclet")
  expect_true(result1)

  # roxygen2::roclet matches NULL | roxygen2::roclet
  result2 <- types_compatible("roxygen2::roclet", "NULL | roxygen2::roclet")
  expect_true(result2)

  # Other types don't match
  result3 <- types_compatible("class_integer", "NULL | roxygen2::roclet")
  expect_false(result3)
})

test_that("external types in complex nested unions", {
  # Should enforce NULL-first rule
  expect_error(
    parse_type_syntax("class_integer | roxygen2::roclet | NULL | lintr::Linter"),
    "NULL must be first in union"
  )

  # Correct order
  ast_correct <- parse_type_syntax("NULL | class_integer | roxygen2::roclet | lintr::Linter")
  expect_equal(ast_correct$node_type, "union")
  expect_equal(length(ast_correct$types), 4)
  expect_equal(ast_correct$types[[1]]$base_type, "NULL")
  expect_equal(ast_correct$types[[2]]$base_type, "class_integer")
  expect_equal(ast_correct$types[[3]]$base_type, "roclet")
  expect_equal(ast_correct$types[[3]]$package, "roxygen2")
  expect_equal(ast_correct$types[[4]]$base_type, "Linter")
  expect_equal(ast_correct$types[[4]]$package, "lintr")
})

test_that("external type doesn't conflict with S7 built-in of same name", {
  # Hypothetical: if an external package had a class called "list"
  # It should be distinct from class_list

  # This is implicitly tested by string matching - package::list != class_list
  result <- types_compatible("hypothetical::list", "class_list")
  expect_false(result)

  # They're different types
  result2 <- types_compatible("class_list", "hypothetical::list")
  expect_false(result2)
})
