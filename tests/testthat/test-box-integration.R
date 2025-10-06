test_that("linter loads types from box module with full import", {
  skip_if_not_installed("xml2")

  # Create module file
  tmp_dir <- withr::local_tempdir()
  mod_dir <- file.path(tmp_dir, "mod")
  dir.create(mod_dir)
  module_file <- file.path(mod_dir, "math.r")
  writeLines(c(
    "#' @typedParam a {class_numeric[1]} first",
    "#' @typedParam b {class_numeric[1]} second",
    "#' @typedReturn {class_numeric[1]} sum",
    "#' @export",
    "add <- function(a, b) a + b"
  ), module_file)

  # Create script that uses module
  script_file <- file.path(tmp_dir, "script.r")
  writeLines(c(
    "box::use(mod/math)",
    "result <- math$add(1, 2)"  # Should pass
  ), script_file)

  # Parse and create XML
  code <- readLines(script_file)
  parsed <- parse(text = code, keep.source = TRUE)
  xml_text <- xmlparsedata::xml_parse_data(parsed)
  xml <- xml2::read_xml(xml_text)

  # Load module types
  types <- load_box_module_types(xml, script_file)

  expect_length(types, 1)
  expect_named(types, "math$add")
  expect_equal(types$`math$add`$params$a$type, "class_numeric[1]")
  expect_equal(types$`math$add`$return$type, "class_numeric[1]")
})

test_that("linter loads types from box module with aliased import", {
  skip_if_not_installed("xml2")

  tmp_dir <- withr::local_tempdir()
  mod_dir <- file.path(tmp_dir, "mod")
  dir.create(mod_dir)
  module_file <- file.path(mod_dir, "math.r")
  writeLines(c(
    "#' @typedParam x {class_numeric} value",
    "#' @typedReturn {class_numeric} doubled",
    "#' @export",
    "double <- function(x) x * 2"
  ), module_file)

  script_file <- file.path(tmp_dir, "script.r")
  writeLines(c(
    "box::use(m = mod/math)",
    "result <- m$double(5)"
  ), script_file)

  code <- readLines(script_file)
  parsed <- parse(text = code, keep.source = TRUE)
  xml_text <- xmlparsedata::xml_parse_data(parsed)
  xml <- xml2::read_xml(xml_text)

  types <- load_box_module_types(xml, script_file)

  expect_length(types, 1)
  expect_named(types, "m$double")
  expect_equal(types$`m$double`$params$x$type, "class_numeric")
})

test_that("linter loads types from box module with selective import", {
  skip_if_not_installed("xml2")

  tmp_dir <- withr::local_tempdir()
  mod_dir <- file.path(tmp_dir, "mod")
  dir.create(mod_dir)
  module_file <- file.path(mod_dir, "math.r")
  writeLines(c(
    "#' @typedParam a {class_numeric} first",
    "#' @typedParam b {class_numeric} second",
    "#' @typedReturn {class_numeric} sum",
    "#' @export",
    "add <- function(a, b) a + b",
    "",
    "#' @typedParam a {class_numeric} first",
    "#' @typedParam b {class_numeric} second",
    "#' @typedReturn {class_numeric} product",
    "#' @export",
    "multiply <- function(a, b) a * b"
  ), module_file)

  script_file <- file.path(tmp_dir, "script.r")
  writeLines(c(
    "box::use(mod/math[add])",  # Only import add, not multiply
    "result <- add(1, 2)"        # Should work
  ), script_file)

  code <- readLines(script_file)
  parsed <- parse(text = code, keep.source = TRUE)
  xml_text <- xmlparsedata::xml_parse_data(parsed)
  xml <- xml2::read_xml(xml_text)

  types <- load_box_module_types(xml, script_file)

  expect_length(types, 1)
  expect_named(types, "add")  # No prefix for selective import
  expect_equal(types$add$params$a$type, "class_numeric")
})

test_that("linter loads types from box module with attach-all", {
  skip_if_not_installed("xml2")

  tmp_dir <- withr::local_tempdir()
  mod_dir <- file.path(tmp_dir, "mod")
  dir.create(mod_dir)
  module_file <- file.path(mod_dir, "math.r")
  writeLines(c(
    "#' @typedParam x {class_numeric} value",
    "#' @typedReturn {class_numeric} result",
    "#' @export",
    "double <- function(x) x * 2",
    "",
    "#' @typedParam x {class_numeric} value",
    "#' @typedReturn {class_numeric} result",
    "#' @export",
    "triple <- function(x) x * 3"
  ), module_file)

  script_file <- file.path(tmp_dir, "script.r")
  writeLines(c(
    "box::use(mod/math[...])",  # Import all functions
    "a <- double(5)",
    "b <- triple(5)"
  ), script_file)

  code <- readLines(script_file)
  parsed <- parse(text = code, keep.source = TRUE)
  xml_text <- xmlparsedata::xml_parse_data(parsed)
  xml <- xml2::read_xml(xml_text)

  types <- load_box_module_types(xml, script_file)

  expect_length(types, 2)
  expect_setequal(names(types), c("double", "triple"))
})

test_that("linter handles module not found gracefully", {
  skip_if_not_installed("xml2")

  tmp_dir <- withr::local_tempdir()
  script_file <- file.path(tmp_dir, "script.r")
  writeLines(c(
    "box::use(nonexistent/module)",
    "x <- 1"
  ), script_file)

  code <- readLines(script_file)
  parsed <- parse(text = code, keep.source = TRUE)
  xml_text <- xmlparsedata::xml_parse_data(parsed)
  xml <- xml2::read_xml(xml_text)

  # Should not error, just return empty
  types <- load_box_module_types(xml, script_file)

  expect_length(types, 0)
})

test_that("linter handles module with no type annotations", {
  skip_if_not_installed("xml2")

  tmp_dir <- withr::local_tempdir()
  mod_dir <- file.path(tmp_dir, "mod")
  dir.create(mod_dir)
  module_file <- file.path(mod_dir, "util.r")
  writeLines(c(
    "#' Simple function without types",
    "#' @export",
    "helper <- function(x) x"
  ), module_file)

  script_file <- file.path(tmp_dir, "script.r")
  writeLines(c(
    "box::use(mod/util)",
    "x <- 1"
  ), script_file)

  code <- readLines(script_file)
  parsed <- parse(text = code, keep.source = TRUE)
  xml_text <- xmlparsedata::xml_parse_data(parsed)
  xml <- xml2::read_xml(xml_text)

  types <- load_box_module_types(xml, script_file)

  expect_length(types, 0)
})

test_that("linter handles relative module paths", {
  skip_if_not_installed("xml2")

  tmp_dir <- withr::local_tempdir()
  module_file <- file.path(tmp_dir, "utils.r")
  writeLines(c(
    "#' @typedParam x {class_numeric} value",
    "#' @typedReturn {class_logical} is valid",
    "#' @export",
    "validate <- function(x) !is.na(x)"
  ), module_file)

  script_file <- file.path(tmp_dir, "script.r")
  writeLines(c(
    "box::use(./utils)",
    "ok <- utils$validate(5)"
  ), script_file)

  code <- readLines(script_file)
  parsed <- parse(text = code, keep.source = TRUE)
  xml_text <- xmlparsedata::xml_parse_data(parsed)
  xml <- xml2::read_xml(xml_text)

  types <- load_box_module_types(xml, script_file)

  expect_length(types, 1)
  expect_named(types, "utils$validate")
})

test_that("linter handles multiple box::use() calls", {
  skip_if_not_installed("xml2")

  tmp_dir <- withr::local_tempdir()
  mod1_dir <- file.path(tmp_dir, "mod1")
  mod2_dir <- file.path(tmp_dir, "mod2")
  dir.create(mod1_dir)
  dir.create(mod2_dir)

  writeLines(c(
    "#' @typedParam x {class_numeric} value",
    "#' @typedReturn {class_numeric} result",
    "#' @export",
    "double <- function(x) x * 2"
  ), file.path(mod1_dir, "math.r"))

  writeLines(c(
    "#' @typedParam x {class_character} text",
    "#' @typedReturn {class_character} upper",
    "#' @export",
    "upcase <- function(x) toupper(x)"
  ), file.path(mod2_dir, "string.r"))

  script_file <- file.path(tmp_dir, "script.r")
  writeLines(c(
    "box::use(mod1/math)",
    "box::use(mod2/string)",
    "a <- math$double(5)",
    "b <- string$upcase('hello')"
  ), script_file)

  code <- readLines(script_file)
  parsed <- parse(text = code, keep.source = TRUE)
  xml_text <- xmlparsedata::xml_parse_data(parsed)
  xml <- xml2::read_xml(xml_text)

  types <- load_box_module_types(xml, script_file)

  expect_length(types, 2)
  expect_setequal(names(types), c("math$double", "string$upcase"))
})
