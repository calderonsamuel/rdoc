test_that("extract_box_imports parses full module import", {
  skip_if_not_installed("xml2")

  code <- "
box::use(mod/math)
"

  xml_text <- xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE))
  xml <- xml2::read_xml(xml_text)
  imports <- extract_box_imports(xml)

  expect_length(imports, 1)
  expect_equal(imports[[1]]$module_path, "mod/math")
  expect_equal(imports[[1]]$module_name, "math")
  expect_null(imports[[1]]$alias)
  expect_null(imports[[1]]$imports)
  expect_false(imports[[1]]$attach_all)
})

test_that("extract_box_imports parses aliased import", {
  skip_if_not_installed("xml2")

  code <- "
box::use(m = mod/math)
"

  xml_text <- xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE))
  xml <- xml2::read_xml(xml_text)
  imports <- extract_box_imports(xml)

  expect_length(imports, 1)
  expect_equal(imports[[1]]$module_path, "mod/math")
  expect_equal(imports[[1]]$module_name, "math")
  expect_equal(imports[[1]]$alias, "m")
  expect_null(imports[[1]]$imports)
  expect_false(imports[[1]]$attach_all)
})

test_that("extract_box_imports parses selective imports", {
  skip_if_not_installed("xml2")

  code <- "
box::use(mod/math[add, multiply])
"

  xml_text <- xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE))
  xml <- xml2::read_xml(xml_text)
  imports <- extract_box_imports(xml)

  expect_length(imports, 1)
  expect_equal(imports[[1]]$module_path, "mod/math")
  expect_equal(imports[[1]]$module_name, "math")
  expect_null(imports[[1]]$alias)
  expect_equal(imports[[1]]$imports, c("add", "multiply"))
  expect_false(imports[[1]]$attach_all)
})

test_that("extract_box_imports parses attach-all imports", {
  skip_if_not_installed("xml2")

  code <- "
box::use(mod/math[...])
"

  xml_text <- xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE))
  xml <- xml2::read_xml(xml_text)
  imports <- extract_box_imports(xml)

  expect_length(imports, 1)
  expect_equal(imports[[1]]$module_path, "mod/math")
  expect_equal(imports[[1]]$module_name, "math")
  expect_null(imports[[1]]$alias)
  expect_null(imports[[1]]$imports)
  expect_true(imports[[1]]$attach_all)
})

test_that("extract_box_imports parses relative path imports", {
  skip_if_not_installed("xml2")

  code <- "
box::use(./local/utils)
box::use(../shared/helpers)
"

  xml_text <- xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE))
  xml <- xml2::read_xml(xml_text)
  imports <- extract_box_imports(xml)

  expect_length(imports, 2)
  expect_equal(imports[[1]]$module_path, "./local/utils")
  expect_equal(imports[[1]]$module_name, "utils")
  expect_equal(imports[[2]]$module_path, "../shared/helpers")
  expect_equal(imports[[2]]$module_name, "helpers")
})

test_that("extract_box_imports parses nested module paths", {
  skip_if_not_installed("xml2")

  code <- "
box::use(company/project/module/utils)
"

  xml_text <- xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE))
  xml <- xml2::read_xml(xml_text)
  imports <- extract_box_imports(xml)

  expect_length(imports, 1)
  expect_equal(imports[[1]]$module_path, "company/project/module/utils")
  expect_equal(imports[[1]]$module_name, "utils")
})

test_that("extract_box_imports handles multiple imports in one call", {
  skip_if_not_installed("xml2")

  code <- "
box::use(
  mod/math,
  m = mod/strings,
  ./local/utils[helper],
  data/constants[...]
)
"

  xml_text <- xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE))
  xml <- xml2::read_xml(xml_text)
  imports <- extract_box_imports(xml)

  expect_length(imports, 4)

  # First: full import
  expect_equal(imports[[1]]$module_path, "mod/math")
  expect_null(imports[[1]]$alias)
  expect_null(imports[[1]]$imports)

  # Second: aliased
  expect_equal(imports[[2]]$module_path, "mod/strings")
  expect_equal(imports[[2]]$alias, "m")

  # Third: selective with relative path
  expect_equal(imports[[3]]$module_path, "./local/utils")
  expect_equal(imports[[3]]$imports, "helper")

  # Fourth: attach-all
  expect_equal(imports[[4]]$module_path, "data/constants")
  expect_true(imports[[4]]$attach_all)
})

test_that("extract_box_imports handles single-segment paths", {
  skip_if_not_installed("xml2")

  code <- "
box::use(utils)
"

  xml_text <- xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE))
  xml <- xml2::read_xml(xml_text)
  imports <- extract_box_imports(xml)

  expect_length(imports, 1)
  expect_equal(imports[[1]]$module_path, "utils")
  expect_equal(imports[[1]]$module_name, "utils")
})

test_that("extract_box_imports returns empty list for no imports", {
  skip_if_not_installed("xml2")

  code <- "
x <- 1 + 2
y <- 3 * 4
"

  xml_text <- xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE))
  xml <- xml2::read_xml(xml_text)
  imports <- extract_box_imports(xml)

  expect_length(imports, 0)
})

test_that("extract_box_imports ignores non-box use calls", {
  skip_if_not_installed("xml2")

  code <- "
library(dplyr)
use <- function() {}
use()
"

  xml_text <- xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE))
  xml <- xml2::read_xml(xml_text)
  imports <- extract_box_imports(xml)

  expect_length(imports, 0)
})

test_that("extract_box_imports captures line numbers", {
  skip_if_not_installed("xml2")

  code <- "
x <- 1

box::use(mod/math)

y <- 2

box::use(mod/strings)
"

  xml_text <- xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE))
  xml <- xml2::read_xml(xml_text)
  imports <- extract_box_imports(xml)

  expect_length(imports, 2)
  expect_equal(imports[[1]]$line, 4)
  expect_equal(imports[[2]]$line, 8)
})

test_that("extract_box_imports handles aliased selective imports", {
  skip_if_not_installed("xml2")

  code <- "
box::use(m = mod/math[add, multiply])
"

  xml_text <- xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE))
  xml <- xml2::read_xml(xml_text)
  imports <- extract_box_imports(xml)

  expect_length(imports, 1)
  expect_equal(imports[[1]]$module_path, "mod/math")
  expect_equal(imports[[1]]$alias, "m")
  expect_equal(imports[[1]]$imports, c("add", "multiply"))
  expect_false(imports[[1]]$attach_all)
})

test_that("extract_box_imports handles complex real-world scenario", {
  skip_if_not_installed("xml2")

  code <- "
# Import different modules
box::use(
  data/db,                      # Full import
  m = models/user,              # Aliased
  ./utils[validate, format],    # Selective local
  ../shared/constants[...]      # Attach all from parent
)

# Use the modules
result <- db$query('SELECT * FROM users')
user <- m$create_user(name = 'Alice')
valid <- validate(user)
"

  xml_text <- xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE))
  xml <- xml2::read_xml(xml_text)
  imports <- extract_box_imports(xml)

  expect_length(imports, 4)
  expect_equal(imports[[1]]$module_path, "data/db")
  expect_equal(imports[[2]]$module_path, "models/user")
  expect_equal(imports[[2]]$alias, "m")
  expect_equal(imports[[3]]$module_path, "./utils")
  expect_equal(imports[[3]]$imports, c("validate", "format"))
  expect_equal(imports[[4]]$module_path, "../shared/constants")
  expect_true(imports[[4]]$attach_all)
})
