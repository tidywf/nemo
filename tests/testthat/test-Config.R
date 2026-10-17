test_that("Config initialize validates inputs", {
  expect_error(Config$new("foo", "nemo"))
  expect_error(Config$new("tool1", "nonexistent_pkg"), "Config directory not found")
})

test_that("Config pattern and ftype methods", {
  conf <- Config$new("tool1", "nemo")
  expect_equal(nrow(conf$get_patterns()), 6)
  expect_equal(conf$get_pattern("table1"), "\\.tool1\\.table1\\.tsv$")
  expect_equal(dplyr::distinct(conf$get_ftypes(), .data$ftype) |> nrow(), 4)
  expect_equal(conf$get_ftype("table1"), "tsv")
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

test_that("Config validates outputs", {
  conf <- Config$new("tool1", "nemo")
  priv <- conf$.__enclos_env__$private
  good <- priv$tables

  bad <- good
  bad$table7$outputs$table7dp$description <- NULL
  bad$table7$outputs$table7main$columns[[1]]$versions <- NULL
  bad$table7$outputs$table1 <- good$table7$outputs$table7dp
  bad$table6$outputs <- list(table7dp = good$table7$outputs$table7dp)
  priv$tables <- bad
  err <- expect_error(priv$validate_tables(), "Invalid schema.yaml for nemo::tool1")
  msg <- conditionMessage(err)
  expect_match(msg, "table7 -> output 'table7dp': missing description")
  expect_match(msg, "table7 -> output 'table7main' -> column 'sample_id': missing versions")
  expect_match(msg, "table7: output name\\(s\\) clash with table name\\(s\\): table1")
  expect_match(msg, "declared by more than one table: table7dp")

  bad2 <- good
  bad2$table7$outputs <- list("x")
  priv$tables <- bad2
  expect_error(priv$validate_tables(), "outputs must be a non-empty named map")
})

test_that("Config output columns need no raw and stay out of raw schemas", {
  conf <- Config$new("tool1", "nemo")
  both <- conf$get_schemas_both()
  dp <- both$schema[both$name == "table7dp"][[1]]
  expect_true(all(is.na(dp$raw)))
  expect_false("table7dp" %in% conf$get_schemas_raw()$name)
  expect_equal(
    conf$get_schema_tidy("table7main", version = "v1.0.0")$field,
    c("sample_id", "reads_total")
  )
  expect_named(conf$get_col_map("table7dp"), c("raw", "tidy", "type", "description"))
})

test_that("Config validates output shape", {
  conf <- Config$new("tool1", "nemo")
  expect_equal(conf$get_output_shape("table7dp"), "exact")
  expect_error(conf$get_output_shape("table1"), "not found in outputs")
  priv <- conf$.__enclos_env__$private
  bad <- priv$tables
  bad$table7$outputs$table7dp$shape <- "loose"
  priv$tables <- bad
  expect_error(priv$validate_tables(), "output 'table7dp': shape must be one of exact, subset")
})

test_that("Config schema lookups are memoised but errors are not", {
  conf <- Config$new("tool1", "nemo")
  s1 <- conf$get_schema_tidy("table1", version = "v1.2.3")
  expect_identical(conf$get_schema_tidy("table1", version = "v1.2.3"), s1)
  expect_identical(conf$get_col_map("table6"), conf$get_col_map("table6"))
  expect_false(identical(conf$get_schema_raw("table1"), conf$get_schema_tidy("table1")))
  for (i in 1:2) {
    expect_error(conf$get_schema_tidy("foo"), "foo not found")
    expect_error(conf$get_schema_raw("table1", version = "v9"), "v9 not found")
  }
})
