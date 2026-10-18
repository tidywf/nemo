#' @title Tool1 Object
#'
#' @description
#' Parses and tidies output files from Tool1. Table schemas and file patterns
#' are defined in `inst/config/tools/tool1/schema.yaml`. Custom parse and tidy
#' methods are provided for tables that require non-standard handling.
#'
#' @examples
#' indir <- system.file("extdata/tool1", package = "nemo")
#' dir1 <- tempdir()
#' obj1 <- Tool1$new(indir)
#'
#' p3 <- system.file("extdata/tool1/latest/sampleA.tool1.table3.tsv", package = "nemo")
#' (tidy3 <- obj1$tidy_table3(p3))
#'
#' obj1$run(output_dir = dir1, format = "parquet", input_id = "run1")
#' (lf <- list.files(dir1, pattern = "tool1.*parquet", full.names = FALSE))
#'
#' obj2 <- Tool1$new(indir)$tidy()
#'
#' # table7 fans out into the table7main + table7dp outputs
#' indir7 <- system.file("extdata/tool1_outputs", package = "nemo")
#' dir7 <- tempfile()
#' obj7 <- Tool1$new(indir7)$tidy()
#' (t7 <- obj7$get_tbls())
#' obj7$write(output_dir = dir7, format = "parquet", input_id = "run1")
#' (lf7 <- sort(basename(obj7$written_files$outpath)))
#' @testexamples
#' expect_equal(lf7, c(
#'   "sampleA_2_tool1_table7dp.parquet", "sampleA_2_tool1_table7main.parquet",
#'   "sampleA_tool1_table7dp.parquet", "sampleA_tool1_table7main.parquet"
#' ))
#' d7 <- tibble::deframe(t7$tidy[[which(grepl("latest", t7$path))]])
#' expect_named(d7$table7main, c("sample_id", "reads_total", "reads_mapped"))
#' expect_named(d7$table7dp, c("sample_id", "dp", "pct"))
#' expect_equal(d7$table7dp$dp, c(10, 20, 30))
#' d7_v1 <- tibble::deframe(t7$tidy[[which(grepl("v1.0.0", t7$path))]])
#' expect_named(d7_v1$table7main, c("sample_id", "reads_total"))
#' @export
Tool1 <- R6::R6Class(
  "Tool1",
  cloneable = FALSE,
  inherit = Tool,
  public = list(
    #' @description Create a new Tool1 object.
    #' @param path (`character(1)`)\cr
    #' Output directory of tool. If `files_tbl` is supplied, this is ignored.
    #' @param files_tbl (`tibble(n)`)\cr
    #' Tibble of files from [list_files_dir()].
    #' @return (`R6::R6Class()`)\cr
    #' R6 object.
    initialize = function(path = NULL, files_tbl = NULL) {
      super$initialize(name = "tool1", pkg = "nemo", path = path, files_tbl = files_tbl)
    },
    #' @description Tidy `table3.tsv` file with type conversion enabled.
    #' @param x (`character(1)` or `tibble()`)\cr
    #' Path to file or already parsed tibble.
    #' @return (`tibble()`)\cr
    #' Tidy data in enframed tibble.
    tidy_table3 = function(x) {
      private$tidy_file(x, "table3", convert_types = TRUE)
    },
    #' @description Tidy `table7.tsv` file.
    #' @param x (`character(1)` or `tibble()`)\cr
    #' Path to file or already parsed tibble.
    #' @return (`tibble()`)\cr
    #' Tidy data in enframed tibble.
    tidy_table7 = function(x) {
      if (!tibble::is_tibble(x)) {
        x <- private$parse_file(x, "table7")
      }
      version <- get_tbl_version_attr(x)
      colnames(x) <- self$config$get_schema_tidy("table7", version = version)[["field"]]
      main <- dplyr::select(x, !dplyr::starts_with("depth_cov_"))
      dp <- x |>
        dplyr::select("sample_id", dplyr::starts_with("depth_cov_")) |>
        tidyr::pivot_longer(
          dplyr::starts_with("depth_cov_"),
          names_to = "dp",
          names_prefix = "depth_cov_",
          names_transform = as.numeric,
          values_to = "pct"
        )
      list(
        table7main = set_tbl_version_attr(main, version),
        table7dp = set_tbl_version_attr(dp, version)
      ) |>
        nemo_enframe()
    }
  )
)
