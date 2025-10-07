test_that("roclet_types can be created", {
  roclet <- roclet_types()

  expect_s3_class(roclet, "roclet_types")
  expect_s3_class(roclet, "roclet")
})

test_that("has_typed_tags detects typed tags", {
  # Create mock block with typed tags
  tag1 <- structure(
    list(val = list(param = "x", type = "class_numeric", description = "input")),
    class = c("roxy_tag_typedParam", "roxy_tag")
  )

  block_with_tags <- list(tags = list(tag1))

  expect_true(has_typed_tags(block_with_tags))
})

test_that("has_typed_tags returns FALSE for blocks without typed tags", {
  # Regular param tag
  tag1 <- structure(list(), class = c("roxy_tag_param", "roxy_tag"))

  block_without_tags <- list(tags = list(tag1))

  expect_false(has_typed_tags(block_without_tags))
})

test_that("get_function_name extracts name from block", {
  block <- list(object = list(alias = "my_function"))

  expect_equal(get_function_name(block), "my_function")
})

test_that("get_function_name uses topic if alias is NULL", {
  block <- list(object = list(topic = "my_function", alias = NULL))

  expect_equal(get_function_name(block), "my_function")
})

test_that("get_function_name returns NULL if no object", {
  block <- list(object = NULL)

  expect_null(get_function_name(block))
})

test_that("extract_type_info_from_block extracts params and return", {
  tag_param <- structure(
    list(val = list(param = "x", type = "class_numeric", description = "input")),
    class = c("roxy_tag_typedParam", "roxy_tag")
  )

  tag_return <- structure(
    list(val = list(type = "class_numeric", description = "output")),
    class = c("roxy_tag_typedReturn", "roxy_tag")
  )

  block <- list(tags = list(tag_param, tag_return))

  result <- extract_type_info_from_block(block)

  expect_equal(result$params$x$type, "class_numeric")
  expect_equal(result$params$x$description, "input")
  expect_equal(result$return$type, "class_numeric")
  expect_equal(result$return$description, "output")
})

test_that("extract_type_info_from_block handles multiple params", {
  tag1 <- structure(
    list(val = list(param = "x", type = "class_numeric", description = "first")),
    class = c("roxy_tag_typedParam", "roxy_tag")
  )

  tag2 <- structure(
    list(val = list(param = "y", type = "class_character", description = "second")),
    class = c("roxy_tag_typedParam", "roxy_tag")
  )

  block <- list(tags = list(tag1, tag2))

  result <- extract_type_info_from_block(block)

  expect_length(result$params, 2)
  expect_equal(result$params$x$type, "class_numeric")
  expect_equal(result$params$y$type, "class_character")
})

test_that("extract_type_info_from_block returns NULL if no typed tags", {
  tag <- structure(list(), class = c("roxy_tag_param", "roxy_tag"))
  block <- list(tags = list(tag))

  result <- extract_type_info_from_block(block)

  expect_null(result)
})

test_that("roclet_process extracts types from blocks", {
  # Create a mock block
  tag_param <- structure(
    list(val = list(param = "x", type = "class_numeric", description = "input")),
    class = c("roxy_tag_typedParam", "roxy_tag")
  )

  block <- list(
    tags = list(tag_param),
    object = list(alias = "test_function")
  )

  roclet <- roclet_types()
  results <- roclet_process.roclet_types(roclet, list(block), NULL, ".")

  expect_length(results, 1)
  expect_equal(names(results), "test_function")
  expect_equal(results$test_function$params$x$type, "class_numeric")
})

test_that("roclet_output creates inst/types.rds", {
  results <- list(
    my_func = list(
      params = list(
        x = list(type = "class_numeric", description = "input")
      )
    )
  )

  temp_dir <- withr::local_tempdir()
  roclet <- roclet_types()

  output_file <- roclet_output.roclet_types(roclet, results, temp_dir)

  expect_true(file.exists(output_file))
  expect_equal(basename(output_file), "types.rds")

  # Verify contents
  saved_data <- readRDS(output_file)
  expect_equal(saved_data, results)
})

test_that("roclet_output returns empty if no results", {
  temp_dir <- withr::local_tempdir()
  roclet <- roclet_types()

  output_file <- roclet_output.roclet_types(roclet, list(), temp_dir)

  expect_length(output_file, 0)
})

test_that("end-to-end roclet workflow", {
  skip_if_not_installed("roxygen2", "7.0.0")

  # For now, skip this full integration test
  # The roclet works when called directly (as shown in other tests)
  # Full roxygenize() integration requires the package to be installed
  skip("Full roxygenize integration requires installed package")
})
