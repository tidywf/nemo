path <- system.file("extdata/tool1", package = "nemo")

test_that("Workflow1 initialize bundles Tool1", {
  wf <- Workflow1$new(path)
  expect_equal(length(wf$get_tools()), 1)
  expect_equal(wf$get_tools()[[1]]$name, "tool1")
})

test_that("Workflow1 list_files returns all parsers", {
  wf <- Workflow1$new(path)
  lf <- wf$list_files()
  expect_true(all(c("tool1_table1", "tool1_table2", "tool1_table4") %in% lf$tool_parser))
})

test_that("Workflow1 run writes expected outputs", {
  out <- withr::local_tempdir()
  Workflow1$new(path)$run(output_dir = out, format = "parquet", input_id = "run1")
  lf <- list.files(out, pattern = "tool1.*parquet", full.names = FALSE)
  expect_equal(sum(grepl("table4", lf)), 2)
})
