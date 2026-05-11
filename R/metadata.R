#' Assemble run metadata
#'
#' @param files (`tibble()`)\cr
#' Written files.
#' @param pkgs (`character(n)`)\cr
#' Packages to include versions of.
#' @param input_id
#' Input ID to use for the dataset (e.g. `run123`).
#' @param output_id (`character(1)`)\cr
#' Output ID to use for the dataset (e.g. `run123`).
#' @param input_dir (`character(n)`)\cr
#' Input directory (can be multiple).
#' @param output_dir (`character(1)`)\cr
#' Output directory.
#'
#' @returns List of metadata.
#'
#' @examples
#' files <- tibble::tibble(
#'   tbl_name = c("purple_qc", "amber_qc"),
#'   prefix = c("S123", "S123"),
#'   outpath = c("S123_purple_qc.tsv", "S123_amber_qc.tsv")
#' )
#' pkgs <- c("nemo")
#' input_id <- "run123"
#' output_id <- ulid::ulid()
#' input_dir <- "/path/to/wigits/run123"
#' output_dir <- "/path/to/nemo/outputs/run123"
#' nemo_metadata(files, pkgs, input_id, output_id, input_dir, output_dir)
#' @export
nemo_metadata <- function(files, pkgs, input_id, output_id, input_dir, output_dir) {
  stopifnot(
    is.data.frame(files),
    rlang::is_character(pkgs),
    rlang::is_character(input_dir),
    rlang::is_character(output_dir, n = 1)
  )
  stopifnot(all(purrr::map_lgl(pkgs, pkg_found)))
  pkg_versions <- pkgs |>
    tibble::as_tibble_col(column_name = "name") |>
    dplyr::rowwise() |>
    dplyr::mutate(version = as.character(utils::packageVersion(.data$name))) |>
    dplyr::ungroup()
  list(
    input_id = jsonlite::unbox(input_id),
    output_id = jsonlite::unbox(output_id),
    input_dirs = I(input_dir),
    output_dir = jsonlite::unbox(output_dir),
    pkg_versions = pkg_versions,
    files = files
  )
}
