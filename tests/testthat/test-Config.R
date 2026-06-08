test_that("Config initialize validates inputs", {
  expect_error(Config$new("foo", "nemo"))
  expect_error(Config$new("tool1", "nonexistent_pkg"), "Config directory not found")
})

test_that("Config pattern and ftype methods", {
  conf <- Config$new("tool1", "nemo")
  expect_equal(nrow(conf$get_patterns()), 6)
  expect_equal(conf$get_pattern("table1"), "\\.tool1\\.table1\\.tsv$")
  expect_equal(dplyr::distinct(conf$get_ftypes(), .data$ftype) |> nrow(), 5)
  expect_equal(conf$get_ftype("table1"), "txt")
})

test_that("Config description methods", {
  conf <- Config$new("tool1", "nemo")
  expect_true(is.character(conf$get_description("table1")))
  expect_equal(nrow(conf$get_descriptions()), 6)
})

test_that("Config schema methods", {
  conf <- Config$new("tool1", "nemo")
  rs <- conf$get_schemas_raw()
  ts <- conf$get_schemas_tidy()
  expect_equal(dplyr::filter(rs, .data$name == "table1") |> nrow(), 3)
  expect_equal(dplyr::filter(ts, .data$name == "table1") |> nrow(), 3)
  s1 <- conf$get_schema_raw("table1")
  expect_named(s1, c("version", "field", "type"))
  expect_equal(nrow(conf$get_schema_raw("table1", version = "v1.2.3")), 5)
  expect_equal(nrow(conf$get_schema_raw("table1", version = "v4.5.6")), 4)
  expect_error(conf$get_schema_raw("foo"))
  expect_error(conf$get_schema_raw("table1", version = "foo"))
})

test_that("Config get_col_map", {
  conf <- Config$new("tool1", "nemo")
  cm <- conf$get_col_map("table5")
  expect_named(cm, c("raw", "tidy", "type", "description"))
})
