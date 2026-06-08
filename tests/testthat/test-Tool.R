path <- system.file("extdata/tool1", package = "nemo")
name <- "tool1"
pkg <- "nemo"

test_that("Tool initialize validates inputs", {
  expect_error(Tool$new(name = name, pkg = pkg), "Supply either")
  expect_error(
    Tool$new(name = name, pkg = pkg, path = path, files_tbl = list_files_dir(path)),
    "not both"
  )
  expect_error(
    Tool$new(name = name, pkg = pkg, path = "/nonexistent_path_xyz"),
    "Path does not exist"
  )
  expect_error(
    Tool$new(name = name, pkg = pkg, files_tbl = tibble::tibble(a = 1)),
    "must have columns"
  )
  expect_error(Tool$new(name = c("a", "b"), pkg = pkg, path = path))
  expect_error(Tool$new(name = name, pkg = c("nemo", "nemo"), path = path))
})

test_that("Tool initialize with files_tbl matches path init", {
  t_path <- Tool$new(name = name, pkg = pkg, path = path)
  t_ftbl <- Tool$new(name = name, pkg = pkg, files_tbl = list_files_dir(path))
  expect_equal(nrow(t_ftbl$list_files()), nrow(t_path$list_files()))
})

test_that("Tool filter_files include/exclude", {
  toolA <- Tool$new(name = name, pkg = pkg, path = path)
  toolA$filter_files(exclude = "tool1_table3")
  expect_false("tool1_table3" %in% toolA$list_files()$tool_parser)
  expect_true(all(
    c("tool1_table1", "tool1_table2", "tool1_table4") %in% toolA$list_files()$tool_parser
  ))

  toolB <- Tool$new(name = name, pkg = pkg, path = path)$filter_files(include = "tool1_table1")
  expect_equal(unique(toolB$list_files()$tool_parser), "tool1_table1")
})

test_that("Tool filter_files errors on bad input", {
  toolB <- Tool$new(name = name, pkg = pkg, path = path)$filter_files(include = "tool1_table1")
  expect_error(
    toolB$filter_files(include = "tool1_table1", exclude = "tool1_table3"),
    "You cannot define both include and exclude"
  )
  expect_error(
    Tool$new(name = name, pkg = pkg, path = path)$filter_files(include = "tool1_nonexistent"),
    "unknown tool_parser"
  )
  expect_error(
    Tool$new(name = name, pkg = pkg, path = path)$filter_files(exclude = "tool1_nonexistent"),
    "unknown tool_parser"
  )
})

test_that("Tool filter_files errors after tidy()", {
  tool <- Tool$new(name = name, pkg = pkg, path = path)$filter_files(
    include = "tool1_table1"
  )$tidy()
  expect_error(tool$filter_files(include = "tool1_table1"), "Cannot filter files after tidy")
})

test_that("Tool tidy produces correct structure", {
  tool <- Tool$new(name = name, pkg = pkg, path = path)$filter_files(
    exclude = "tool1_table5"
  )$tidy()
  expect_false("tool1_table5" %in% tool$list_files()$tool_parser)
  expect_true("tool1_table3" %in% tool$list_files()$tool_parser)
  expect_false(is.null(tool$get_tbls()))
  expect_named(
    tool$get_tbls(),
    c(
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
  t4 <- tool$get_tbls() |> dplyr::filter(tool_parser == "tool1_table4")
  expect_equal(nrow(t4), 2)
  t4_ncols <- purrr::map_int(t4$tidy, \(x) ncol(x$data[[1]]))
  expect_setequal(t4_ncols, c(3L, 5L))
})

test_that("Tool tidy with keep_raw = TRUE adds raw column", {
  tool <- Tool$new(name = name, pkg = pkg, path = path)$filter_files(include = "tool1_table1")$tidy(
    keep_raw = TRUE
  )
  expect_true("raw" %in% names(tool$get_tbls()))
})

test_that("Tool tidy with no matching files returns NULL tbls", {
  empty_dir <- withr::local_tempdir()
  tool <- Tool$new(name = name, pkg = pkg, path = empty_dir)$tidy()
  expect_null(tool$get_tbls())
})

test_that("Tool tidy is idempotent", {
  tool <- Tool$new(name = name, pkg = pkg, path = path)$filter_files(
    include = "tool1_table1"
  )$tidy()
  nr <- nrow(tool$get_tbls())
  tool$tidy()
  expect_equal(nrow(tool$get_tbls()), nr)
})

test_that("Tool write errors before tidy()", {
  tool <- Tool$new(name = name, pkg = pkg, path = path)
  expect_error(
    tool$write(output_dir = tempdir(), format = "parquet"),
    "Did you forget to tidy"
  )
})

test_that("Tool write errors on invalid format", {
  tool <- Tool$new(name = name, pkg = pkg, path = path)$filter_files(
    include = "tool1_table1"
  )$tidy()
  expect_error(tool$write(output_dir = tempdir(), format = "invalid"), "Output format")
})

test_that("Tool write with NULL tbls sets written_files to NULL", {
  empty_dir <- withr::local_tempdir()
  tool <- Tool$new(name = name, pkg = pkg, path = empty_dir)$tidy()
  tool$write(output_dir = tempdir(), format = "parquet")
  expect_null(tool$written_files)
})

test_that("Tool write is idempotent", {
  out <- withr::local_tempdir()
  tool <- Tool$new(name = name, pkg = pkg, path = path)$filter_files(
    include = "tool1_table1"
  )$tidy()
  tool$write(output_dir = out, format = "parquet")
  n_before <- length(list.files(out))
  tool$write(output_dir = out, format = "parquet")
  expect_equal(length(list.files(out)), n_before)
})

test_that("Tool write produces correct outputs and metadata", {
  out <- withr::local_tempdir()
  tool <- Tool$new(name = name, pkg = pkg, path = path)$filter_files(
    exclude = "tool1_table5"
  )$tidy()
  tool$write(output_dir = out, format = "parquet", input_id = "run1")
  lf <- list.files(out, full.names = TRUE)
  expect_equal(sum(grepl("table4", lf)), 2)
  meta <- arrow::read_parquet(file.path(out, "metadata_tool1.parquet"))
  expect_named(
    meta,
    c("input_id", "output_id", "input_dirs", "output_dir", "pkg_versions", "files")
  )
  expect_equal(meta$input_id, "run1")
  expect_named(tool$written_files, c("raw_path", "tool_parser", "prefix", "tbl_name", "outpath"))
})

test_that("Tool write with write_metadata = FALSE skips metadata file", {
  out <- withr::local_tempdir()
  Tool$new(name = name, pkg = pkg, path = path)$filter_files(include = "tool1_table1")$tidy()$write(
    output_dir = out,
    format = "parquet",
    write_metadata = FALSE
  )
  expect_false(any(grepl("^metadata_", basename(list.files(out)))))
})

test_that("Tool write errors when files_tbl init and write_metadata = TRUE", {
  expect_error(
    Tool$new(name = name, pkg = pkg, files_tbl = list_files_dir(path))$filter_files(
      include = "tool1_table1"
    )$tidy()$write(output_dir = tempdir(), format = "parquet"),
    "Cannot write metadata"
  )
})

test_that("Tool write succeeds when files_tbl init and write_metadata = FALSE", {
  out <- withr::local_tempdir()
  Tool$new(name = name, pkg = pkg, files_tbl = list_files_dir(path))$filter_files(
    include = "tool1_table1"
  )$tidy()$write(output_dir = out, format = "parquet", write_metadata = FALSE)
  expect_false(any(grepl("^metadata_", basename(list.files(out)))))
})

test_that("Tool write prepends id columns in correct order", {
  make_tool <- function() {
    Tool$new(name = name, pkg = pkg, path = path)$filter_files(include = "tool1_table1")$tidy()
  }
  read_pq <- function(d) {
    fs <- list.files(d, pattern = "[.]parquet$", full.names = TRUE)
    arrow::read_parquet(fs[!grepl("^metadata_", basename(fs))][1])
  }
  d0 <- withr::local_tempdir()
  di <- withr::local_tempdir()
  do_ <- withr::local_tempdir()
  dp <- withr::local_tempdir()
  da <- withr::local_tempdir()
  make_tool()$write(output_dir = d0, format = "parquet")
  make_tool()$write(output_dir = di, format = "parquet", input_id = "run1")
  make_tool()$write(output_dir = do_, format = "parquet", output_id = "out1")
  make_tool()$write(output_dir = dp, format = "parquet", prefix_include = TRUE)
  make_tool()$write(
    output_dir = da,
    format = "parquet",
    input_id = "run1",
    output_id = "out1",
    prefix_include = TRUE
  )
  expect_false(any(c("input_id", "output_id", "input_prefix") %in% names(read_pq(d0))))
  expect_equal(read_pq(di)$input_id[1], "run1")
  expect_equal(read_pq(do_)$output_id[1], "out1")
  expect_true("input_prefix" %in% names(read_pq(dp)))
  expect_equal(names(read_pq(da))[1:3], c("input_id", "input_prefix", "output_id"))
})

test_that("Tool run chains filter + tidy + write and records written_files", {
  out <- withr::local_tempdir()
  tool <- Tool$new(name = name, pkg = pkg, path = path)$run(
    output_dir = out,
    format = "parquet",
    exclude = "tool1_table5",
    input_id = "run2"
  )
  expect_named(tool$written_files, c("raw_path", "tool_parser", "prefix", "tbl_name", "outpath"))
  expect_false(any(grepl("table5", basename(list.files(out)))))
  expect_true(any(grepl("table1", basename(list.files(out)))))
})
