path <- system.file("extdata/tool1", package = "nemo")
tools <- list(tool1 = Tool1)

test_that("Workflow list_files returns all matched parsers with tool column", {
  wf <- Workflow$new(name = "wf1", path = path, tools = tools)
  lf <- wf$list_files()
  expect_named(
    lf,
    c(
      "tool",
      "tool_parser",
      "parser",
      "bname",
      "size",
      "lastmodified",
      "path",
      "pattern",
      "prefix",
      "prefix_suffix"
    )
  )
  expect_true(all(c("tool1_table1", "tool1_table2", "tool1_table4") %in% lf$tool_parser))
})

test_that("Workflow filter_files + tidy + get_tbls", {
  wf <- Workflow$new(name = "wf1", path = path, tools = tools)
  wf$filter_files(exclude = "tool1_table6")
  wf$tidy()
  tbls <- wf$get_tbls()
  expect_false("tool1_table6" %in% tbls$tool_parser)
  expect_true("tool1_table4" %in% tbls$tool_parser)
  expect_named(
    tbls,
    c(
      "tool",
      "tool_parser",
      "parser",
      "bname",
      "size",
      "lastmodified",
      "path",
      "pattern",
      "prefix",
      "prefix_suffix",
      "tidy"
    )
  )
})

test_that("Workflow get_schemas_raw", {
  wf <- Workflow$new(name = "wf1", path = path, tools = tools)
  rs <- wf$get_schemas_raw()
  expect_named(rs, c("tool", "name", "tbl_description", "version", "schema"))
})

test_that("Workflow write produces correct outputs and written_files", {
  wf <- Workflow$new(name = "wf1", path = path, tools = tools)
  wf$filter_files(exclude = "tool1_table6")
  wf$tidy()
  out <- withr::local_tempdir()
  wf$write(output_dir = out, format = "parquet", input_id = "run1")
  lf <- list.files(out, pattern = "tool1.*parquet", full.names = TRUE)
  expect_equal(sum(grepl("table4", basename(lf))), 2)
  expect_named(wf$written_files, c("raw_path", "tool_parser", "prefix", "tbl_name", "outpath"))
})

test_that("Workflow get_metadata has correct structure", {
  wf <- Workflow$new(name = "wf1", path = path, tools = tools)
  wf$filter_files(exclude = "tool1_table6")
  wf$tidy()
  out <- withr::local_tempdir()
  wf$write(output_dir = out, format = "parquet", input_id = "run1")
  meta <- wf$get_metadata(input_id = "run1", output_id = "out1", output_dir = out)
  expect_named(
    meta,
    c("input_id", "output_id", "input_dirs", "output_dir", "pkg_versions", "files")
  )
})

test_that("Workflow run writes all parsers", {
  out <- withr::local_tempdir()
  wf <- Workflow$new(name = "wf2", path = path, tools = tools)
  wf$run(output_dir = out, format = "parquet", input_id = "run2")
  lf <- list.files(out, pattern = "tool1.*parquet", full.names = TRUE)
  expect_true(all(
    c("tool1_table1", "tool1_table4") %in%
      sub(".*_(tool1_table\\d).*", "\\1", basename(lf))
  ))
})

test_that("Workflow run after tidy writes, and repeated run is a no-op", {
  out <- withr::local_tempdir()
  wf <- Workflow$new(name = "wf3", path = path, tools = tools)
  wf$tidy()
  expect_no_error(wf$run(output_dir = out, format = "parquet", input_id = "run3"))
  expect_true(file.exists(file.path(out, "metadata.parquet")))
  n <- nrow(wf$written_files)
  expect_no_error(wf$run(output_dir = out, format = "parquet", input_id = "run3"))
  expect_equal(nrow(wf$written_files), n)
})

test_that("Workflow get_metadata before write lists matched files only", {
  d <- withr::local_tempdir()
  file.copy(file.path(path, "latest", "sampleA.tool1.table1.tsv"), d)
  writeLines("x", file.path(d, "unrelated.txt"))
  wf <- Workflow$new(name = "wf4", path = d, tools = tools)
  meta <- wf$get_metadata(input_id = "r", output_id = "o", output_dir = d)
  expect_equal(basename(meta$files[[1]]$fin), "sampleA.tool1.table1.tsv")
})
