meta_files_from_written <- function(written_files) {
  written_files |>
    dplyr::mutate(outpath = basename(.data$outpath)) |>
    dplyr::select(tbl = "tbl_name", "prefix", fout = "outpath", fin = "raw_path") |>
    dplyr::mutate(dplyr::across(dplyr::where(is.character), as.character))
}

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
#' @param input_dirs (`character(n)`)\cr
#' Input directory (can be multiple).
#' @param output_dir (`character(1)`)\cr
#' Output directory.
#'
#' @returns Single-row tibble of metadata with list columns for `input_dirs`,
#'   `pkg_versions`, and `files`.
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
#' input_dirs <- "/path/to/wigits/run123"
#' output_dir <- "/path/to/nemo/outputs/run123"
#' nemo_metadata(files, pkgs, input_id, output_id, input_dirs, output_dir)
#' @export
nemo_metadata <- function(files, pkgs, input_id, output_id, input_dirs, output_dir) {
  stopifnot(
    is.data.frame(files),
    rlang::is_character(pkgs),
    rlang::is_character(input_dirs),
    rlang::is_scalar_character(output_dir),
    rlang::is_scalar_character(input_id) || is.null(input_id),
    rlang::is_scalar_character(output_id) || is.null(output_id)
  )
  stopifnot(all(purrr::map_lgl(pkgs, pkg_found)))
  pkg_versions <- pkgs |>
    tibble::as_tibble_col(column_name = "name") |>
    dplyr::rowwise() |>
    dplyr::mutate(version = as.character(utils::packageVersion(.data$name))) |>
    dplyr::ungroup()
  input_id <- input_id %||% NA_character_
  output_id <- output_id %||% NA_character_
  tibble::tibble(
    input_id = input_id,
    output_id = output_id,
    input_dirs = list(input_dirs),
    output_dir = output_dir,
    pkg_versions = list(as.data.frame(pkg_versions)),
    files = list(as.data.frame(files))
  )
}
