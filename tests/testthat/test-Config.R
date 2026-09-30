test_that("Config initialize validates inputs", {
  expect_error(Config$new("foo", "nemo"))
  expect_error(Config$new("tool1", "nonexistent_pkg"), "Config directory not found")
})

test_that("Config pattern and ftype methods", {
  conf <- Config$new("tool1", "nemo")
  expect_equal(nrow(conf$get_patterns()), 5)
  expect_equal(conf$get_pattern("table1"), "\\.tool1\\.table1\\.tsv$")
  expect_equal(dplyr::distinct(conf$get_ftypes(), .data$ftype) |> nrow(), 4)
  expect_equal(conf$get_ftype("table1"), "tsv")
})

test_that("Config description methods", {
  conf <- Config$new("tool1", "nemo")
  expect_true(is.character(conf$get_description("table1")))
  expect_equal(nrow(conf$get_descriptions()), 5)
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
  cm <- conf$get_col_map("table6")
  expect_named(cm, c("raw", "tidy", "type", "description"))
})

test_that("Config validates required table and column keys", {
  conf <- Config$new("tool1", "nemo")
  priv <- conf$.__enclos_env__$private
  good <- priv$tables
  expect_true(priv$validate_tables())

  bad <- good
  bad$table1$pattern <- NULL
  bad$table2$ftype <- c("tsv", "csv")
  bad$table3$columns[[1]]$versions <- NULL
  priv$tables <- bad
  err <- expect_error(priv$validate_tables(), "Invalid schema.yaml for nemo::tool1")
  expect_match(conditionMessage(err), "table1: missing pattern")
  expect_match(conditionMessage(err), "table2: not a single string: ftype")
  expect_match(conditionMessage(err), "table3 -> column '.+': missing versions")
})
