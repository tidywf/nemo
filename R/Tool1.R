#' @title Tool1 Object
#'
#' @description
#' Tool1 file parsing and manipulation.
#' @examples
#' cls <- Tool1
#' indir <- system.file("extdata/tool1", package = "nemo")
#' odir <- tempdir()
#' id <- "tool1_run1"
#' obj <- cls$new(indir)
#' obj$nemofy(diro = odir, format = "parquet", input_id = id)
#' (lf <- list.files(odir, pattern = "tool1.*parquet", full.names = FALSE))
#' @testexamples
#' expect_equal(length(lf), 6)
#' @export
Tool1 <- R6::R6Class(
  "Tool1",
  inherit = Tool,
  public = list(
    #' @description Create a new Tool1 object.
    #' @param path (`character(1)`)\cr
    #' Output directory of tool. If `files_tbl` is supplied, this basically gets
    #' ignored.
    #' @param files_tbl (`tibble(n)`)\cr
    #' Tibble of files from [list_files_dir()].
    initialize = function(path = NULL, files_tbl = NULL) {
      super$initialize(name = "tool1", pkg = "nemo", path = path, files_tbl = files_tbl)
    },
    #' @description Read `table1.tsv` file.
    #' @param x (`character(1)`)\cr
    #' Path to file.
    parse_table1 = function(x) {
      self$.parse_file(x, "table1")
    },
    #' @description Tidy `table1.tsv` file.
    #' @param x (`character(1)`)\cr
    #' Path to file.
    tidy_table1 = function(x) {
      self$.tidy_file(x, "table1")
    },
    #' @description Read `table2.tsv` file.
    #' @param x (`character(1)`)\cr
    #' Path to file.
    parse_table2 = function(x) {
      self$.parse_file(x, "table2")
    },
    #' @description Tidy `table2.tsv` file.
    #' @param x (`character(1)`)\cr
    #' Path to file.
    tidy_table2 = function(x) {
      self$.tidy_file(x, "table2")
    },
    #' @description Read `table3.tsv` file.
    #' @param x (`character(1)`)\cr
    #' Path to file.
    parse_table3 = function(x) {
      d0 <- self$.parse_file_keyvalue(x, "table3")
      d0 |>
        set_tbl_version_attr(get_tbl_version_attr(d0))
    },
    #' @description Tidy `table3.tsv` file.
    #' @param x (`character(1)`)\cr
    #' Path to file.
    tidy_table3 = function(x) {
      self$.tidy_file(x, "table3", convert_types = TRUE)
    },
    #' @description Read `table4.tsv` file (no header).
    #' @param x (`character(1)`)\cr
    #' Path to file.
    parse_table4 = function(x) {
      self$.parse_file_nohead(x, "table4")
    },
    #' @description Tidy `table4.tsv` file.
    #' @param x (`character(1)`)\cr
    #' Path to file.
    tidy_table4 = function(x) {
      self$.tidy_file(x, "table4")
    },
    #' @description Read `table5.csv` file (csv, no header, long format).
    #' @param x (`character(1)`)\cr
    #' Path to file.
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
    #' @param x (`character(1)`)\cr
    #' Path to file or already parsed tibble.
    tidy_table5 = function(x) {
      if (!tibble::is_tibble(x)) {
        x <- self$parse_table5(x)
      }
      version <- get_tbl_version_attr(x)
      col_map <- self$get_col_map("table5", v = version)
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
        setNames("table5") |>
        enframe_data()
    }
  )
)
