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
#' p5 <- system.file("extdata/tool1/latest/sampleA.tool1.table5.csv", package = "nemo")
#' (tidy3 <- obj1$tidy_table3(p3))
#' (raw5 <- obj1$parse_table5(p5))
#' (tidy5 <- obj1$tidy_table5(p5))
#'
#' obj1$run(output_dir = dir1, format = "parquet", input_id = "run1")
#' (lf <- list.files(dir1, pattern = "tool1.*parquet", full.names = FALSE))
#'
#' obj2 <- Tool1$new(indir)$tidy()
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
    #' @description Read `table5.csv` file (csv, no header, long format).
    #' @param x (`character(1)`)\cr
    #' Path to file.
    #' @return (`tibble()`)\cr
    #' Raw parsed tibble with columns `section`, `rg`, `variable`, `count`, `pct`.
    parse_table5 = function(x) {
      d <- readr::read_csv(
        x,
        col_names = c("section", "rg", "variable", "count", "pct"),
        col_types = "cccdd",
        show_col_types = FALSE
      )
      attr(d, "file_version") <- "latest"
      d[]
    },
    #' @description Tidy `table5.csv` file.
    #' @param x (`character(1)` or `tibble()`)\cr
    #' Path to file or already parsed tibble.
    #' @return (`tibble()`)\cr
    #' Tidy data in enframed tibble, pivoted wide from long format.
    tidy_table5 = function(x) {
      if (!tibble::is_tibble(x)) {
        x <- self$parse_table5(x)
      }
      version <- get_tbl_version_attr(x)
      col_map <- self$config$get_col_map("table5", version = version)
      raw_to_tidy <- col_map |> dplyr::select("raw", "tidy") |> tibble::deframe()
      raw_to_type <- col_map |> dplyr::select("tidy", "type") |> tibble::deframe()
      d_count <- x |>
        dplyr::filter(.data$variable %in% names(raw_to_tidy)) |>
        dplyr::mutate(tidy_var = raw_to_tidy[.data$variable]) |>
        dplyr::select("section", "rg", tidy_var = "tidy_var", value = "count") |>
        tidyr::pivot_wider(names_from = "tidy_var", values_from = "value")
      d_pct <- x |>
        dplyr::filter(.data$variable %in% names(raw_to_tidy), !is.na(.data$pct)) |>
        dplyr::mutate(tidy_var = paste0(raw_to_tidy[.data$variable], "_pct")) |>
        dplyr::select("section", "rg", tidy_var = "tidy_var", value = "pct") |>
        tidyr::pivot_wider(names_from = "tidy_var", values_from = "value")
      d_tidy <- dplyr::left_join(d_count, d_pct, by = c("section", "rg"))
      list(d_tidy) |>
        rlang::set_names("table5") |>
        nemo_enframe()
    }
  )
)
