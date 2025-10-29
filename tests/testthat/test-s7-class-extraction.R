test_that("s7_class_expr_to_string converts symbols", {
  expr <- quote(class_character)
  result <- s7_class_expr_to_string(expr)

  expect_equal(result, "class_character")
})

test_that("s7_class_expr_to_string handles S7:: qualified names", {
  expr <- quote(S7::class_numeric)
  result <- s7_class_expr_to_string(expr)

  expect_equal(result, "S7::class_numeric")
})

test_that("s7_class_expr_to_string handles complex expressions", {
  # For unions or other complex types, it should deparse
  expr <- quote(new_union(class_character, NULL))
  result <- s7_class_expr_to_string(expr)

  expect_true(grepl("new_union", result))
})

test_that("extract_s7_properties extracts simple properties", {
  # Create S7::new_class call expression
  expr <- quote(S7::new_class(
    "Person",
    properties = list(
      name = class_character,
      age = class_numeric
    )
  ))

  result <- extract_s7_properties(expr, globalenv())

  expect_type(result, "list")
  expect_length(result, 2)
  expect_named(result, c("name", "age"))

  expect_s7_class(result$name, param_type)
  expect_equal(result$name@type, "class_character")
  expect_equal(result$name@description, "")

  expect_s7_class(result$age, param_type)
  expect_equal(result$age@type, "class_numeric")
})

test_that("extract_s7_properties returns NULL for class without properties", {
  expr <- quote(S7::new_class("Simple"))

  result <- extract_s7_properties(expr, globalenv())

  expect_null(result)
})

test_that("extract_s7_properties handles empty properties list", {
  expr <- quote(S7::new_class(
    "Empty",
    properties = list()
  ))

  result <- extract_s7_properties(expr, globalenv())

  expect_null(result)
})

test_that("is_s7_class_definition detects S7 classes", {
  # Mock block with S7::new_class
  block <- list(
    object = list(
      value = quote(S7::new_class("Person", properties = list(name = class_character)))
    )
  )

  expect_true(is_s7_class_definition(block))
})

test_that("is_s7_class_definition detects new_class without S7:: prefix", {
  # Some code might use library(S7) and call new_class directly
  block <- list(
    object = list(
      value = quote(new_class("Person", properties = list(name = class_character)))
    )
  )

  expect_true(is_s7_class_definition(block))
})

test_that("is_s7_class_definition returns FALSE for functions", {
  block <- list(
    object = list(
      value = quote(function(x) x + 1)
    )
  )

  expect_false(is_s7_class_definition(block))
})

test_that("is_s7_class_definition returns FALSE for NULL", {
  block <- list(object = NULL)

  expect_false(is_s7_class_definition(block))
})

test_that("extract_s7_class_info extracts complete class metadata", {
  # Create mock block
  tag_param1 <- structure(
    list(val = list(param = "name", type = "class_character[1]", description = "Person's name")),
    class = c("roxy_tag_typedParam", "roxy_tag")
  )

  tag_param2 <- structure(
    list(val = list(param = "age", type = "class_numeric[1]", description = "Person's age")),
    class = c("roxy_tag_typedParam", "roxy_tag")
  )

  tag_return <- structure(
    list(val = list(type = "Person", description = "A new Person instance")),
    class = c("roxy_tag_typedReturn", "roxy_tag")
  )

  block <- list(
    tags = list(tag_param1, tag_param2, tag_return),
    object = list(
      value = quote(S7::new_class(
        "Person",
        properties = list(
          name = class_character,
          age = class_numeric
        )
      ))
    )
  )

  result <- extract_s7_class_info(block, globalenv())

  expect_type(result, "list")
  expect_true(result$is_s7_class)
  expect_equal(result$class_system, "S7")

  # Check constructor signature
  expect_s7_class(result$constructor_signature, function_signature)
  expect_equal(result$constructor_signature@params$name@type, "class_character[1]")
  expect_equal(result$constructor_signature@params$age@type, "class_numeric[1]")
  expect_equal(result$constructor_signature@return@type, "Person")

  # Check properties
  expect_type(result$properties, "list")
  expect_length(result$properties, 2)
  expect_equal(result$properties$name@type, "class_character")
  expect_equal(result$properties$age@type, "class_numeric")
})

test_that("roclet_output wraps S7 classes in exported_class", {
  # Simulate roclet_process results with S7 class
  results <- list(
    Person = list(
      is_s7_class = TRUE,
      class_system = "S7",
      constructor_signature = function_signature(
        params = list(
          name = param_type(type = "class_character", description = "Name")
        ),
        return = return_type(type = "Person", description = "Instance")
      ),
      properties = list(
        name = param_type(type = "class_character", description = "")
      )
    )
  )

  temp_dir <- withr::local_tempdir()

  # Create DESCRIPTION file
  desc_file <- file.path(temp_dir, "DESCRIPTION")
  writeLines(c("Package: testpkg", "Version: 1.0.0"), desc_file)

  roclet <- roclet_types()
  output_file <- roclet_output.roclet_types(roclet, results, temp_dir)

  # Verify file created
  expect_true(file.exists(output_file))

  # Load and verify contents
  saved_data <- readRDS(output_file)

  expect_s7_class(saved_data, type_metadata)
  expect_length(saved_data@exports, 1)
  expect_equal(names(saved_data@exports), "Person")

  # Verify exported_class structure
  person_class <- saved_data@exports$Person
  expect_s7_class(person_class, exported_class)
  expect_equal(person_class@name, "Person")
  expect_equal(person_class@export_type, "class")
  expect_equal(person_class@class_system, "S7")

  # Verify constructor
  expect_s7_class(person_class@constructor_signature, function_signature)
  expect_equal(person_class@constructor_signature@params$name@type, "class_character")

  # Verify properties
  expect_length(person_class@properties, 1)
  expect_equal(person_class@properties$name@type, "class_character")
})

test_that("roclet_output handles mixed functions and classes", {
  # Simulate results with both function and class
  results <- list(
    my_func = function_signature(
      params = list(x = param_type(type = "numeric", description = "Input")),
      return = return_type(type = "numeric", description = "Output")
    ),
    MyClass = list(
      is_s7_class = TRUE,
      class_system = "S7",
      constructor_signature = function_signature(
        params = list(),
        return = return_type(type = "MyClass", description = "Instance")
      ),
      properties = NULL
    )
  )

  temp_dir <- withr::local_tempdir()
  desc_file <- file.path(temp_dir, "DESCRIPTION")
  writeLines(c("Package: testpkg", "Version: 1.0.0"), desc_file)

  roclet <- roclet_types()
  output_file <- roclet_output.roclet_types(roclet, results, temp_dir)

  saved_data <- readRDS(output_file)

  expect_length(saved_data@exports, 2)

  # Verify function
  expect_s7_class(saved_data@exports$my_func, exported_function)
  expect_equal(saved_data@exports$my_func@export_type, "function")

  # Verify class
  expect_s7_class(saved_data@exports$MyClass, exported_class)
  expect_equal(saved_data@exports$MyClass@export_type, "class")
})
