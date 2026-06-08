indir <- system.file("extdata/tool1", package = "nemo")

test_that("Tool1 initialize accepts path and files_tbl", {
  obj_path <- Tool1$new(indir)
  obj_ftbl <- Tool1$new(files_tbl = list_files_dir(indir))
  expect_equal(nrow(obj_ftbl$list_files()), nrow(obj_path$list_files()))
})

test_that("Tool1 parse_table5 from file path", {
  p5 <- system.file("extdata/tool1/latest/sampleA.tool1.table5.csv", package = "nemo")
  raw5 <- Tool1$new(indir)$parse_table5(p5)
  expect_named(raw5, c("section", "rg", "variable", "count", "pct"))
  expect_equal(nrow(raw5), 16)
})

test_that("Tool1 tidy_table3 from file path", {
  p3 <- system.file("extdata/tool1/latest/sampleA.tool1.table3.tsv", package = "nemo")
  tidy3 <- Tool1$new(indir)$tidy_table3(p3)
  expect_named(tidy3, c("name", "data"))
  expect_named(
    tidy3$data[[1]],
    c("sample_id", "qcstatus", "reads_total", "reads_map", "reads_unmap")
  )
})

test_that("Tool1 tidy_table3 from tibble input", {
  obj <- Tool1$new(indir)$tidy(keep_raw = TRUE)
  raw_tbl <- obj$get_tbls() |>
    dplyr::filter(parser == "table3") |>
    dplyr::slice(1) |>
    dplyr::pull(raw) |>
    _[[1]]
  tidy3 <- obj$tidy_table3(raw_tbl)
  expect_named(tidy3, c("name", "data"))
  expect_named(
    tidy3$data[[1]],
    c("sample_id", "qcstatus", "reads_total", "reads_map", "reads_unmap")
  )
})

test_that("Tool1 tidy_table5 from file path", {
  p5 <- system.file("extdata/tool1/latest/sampleA.tool1.table5.csv", package = "nemo")
  tidy5 <- Tool1$new(indir)$tidy_table5(p5)
  expect_named(tidy5, c("name", "data"))
  d <- tidy5$data[[1]]
  expect_named(
    d,
    c(
      "section",
      "rg",
      "reads_total",
      "reads_map",
      "reads_unmap",
      "bases_total",
      "reads_total_pct",
      "reads_map_pct",
      "reads_unmap_pct"
    )
  )
  expect_equal(nrow(d), 4L)
  expect_false(any(is.na(d$section)))
  expect_equal(sum(!is.na(d$rg)), 2L)
})

test_that("Tool1 tidy_table5 from tibble input", {
  obj <- Tool1$new(indir)$tidy(keep_raw = TRUE)
  raw_tbl <- obj$get_tbls() |>
    dplyr::filter(parser == "table5") |>
    dplyr::pull(raw) |>
    _[[1]]
  tidy5 <- obj$tidy_table5(raw_tbl)
  expect_named(tidy5, c("name", "data"))
  expect_named(
    tidy5$data[[1]],
    c(
      "section",
      "rg",
      "reads_total",
      "reads_map",
      "reads_unmap",
      "bases_total",
      "reads_total_pct",
      "reads_map_pct",
      "reads_unmap_pct"
    )
  )
})

test_that("Tool1 tidy produces correct table structure and version handling", {
  obj <- Tool1$new(indir)$tidy()
  expect_false(is.null(obj$get_tbls()))
  expect_named(
    obj$get_tbls(),
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
  expect_equal(nrow(obj$get_tbls() |> dplyr::filter(tool_parser == "tool1_table4")), 2)
  t3_ncols <- purrr::map_int(
    obj$get_tbls() |> dplyr::filter(parser == "table3") |> dplyr::pull(tidy),
    \(x) ncol(x$data[[1]])
  )
  expect_setequal(t3_ncols, c(3L, 5L))
  expect_named(
    obj$get_tbls() |>
      dplyr::filter(parser == "table5") |>
      dplyr::pull(tidy) |>
      _[[1]] |>
      _$data[[1]],
    c(
      "section",
      "rg",
      "reads_total",
      "reads_map",
      "reads_unmap",
      "bases_total",
      "reads_total_pct",
      "reads_map_pct",
      "reads_unmap_pct"
    )
  )
})

test_that("Tool1 run writes expected output files", {
  out <- withr::local_tempdir()
  Tool1$new(indir)$run(output_dir = out, format = "parquet", input_id = "run1")
  lf <- list.files(out, pattern = "tool1.*parquet", full.names = FALSE)
  expect_equal(sum(grepl("table4", lf)), 2)
})
