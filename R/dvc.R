#' Download DVC-tracked File
#'
#' Parses a `.dvc` pointer file and downloads the corresponding data file from
#' the public Cloudflare R2 remote.
#'
#' @param x Path to a `.dvc` pointer file.
#' @param output_dir Directory to write the downloaded file into.
#' @param overwrite Logical. If `FALSE`, skip if the file already exists.
#' @param pkg_nm Package name, used to point to the Cloudflare R2 bucket of
#' interest.
#'
#' @return Path to the downloaded file, or `NULL` if skipped.
#'
#' @examples
#' x <- system.file("extdata/dvc-example/sampleA.tool1.table1.tsv.dvc", package = "nemo")
#' output_dir <- file.path(tempdir(), "dvc_single_test")
#' result <- dvc_download_file(x, output_dir)
#' result_cached <- dvc_download_file(x, output_dir, overwrite = FALSE)
#'
#' @testexamples
#' expect_true(file.exists(result))
#' expect_null(result_cached)
#' @export
dvc_download_file <- function(
  x,
  output_dir,
  overwrite = FALSE,
  pkg_nm = "nemo"
) {
  base_url <- paste0(
    "https://pub-a01f7a6f4beb4056910d1ba371542fc7.r2.dev/",
    pkg_nm,
    "/r-pkg/dvc/files/md5"
  )
  lines <- readLines(x, warn = FALSE)
  md5_line <- grep("md5:", lines, value = TRUE)[1]
  path_line <- grep("path:", lines, value = TRUE)[1]
  if (is.na(md5_line) || is.na(path_line)) {
    return(NULL)
  }
  md5 <- trimws(sub(".*md5:", "", md5_line))
  rel_path <- trimws(sub(".*path:", "", path_line))
  out_file <- file.path(output_dir, rel_path)
  if (!overwrite && file.exists(out_file)) {
    return(NULL)
  }
  fs::dir_create(output_dir)
  url <- paste0(base_url, "/", substr(md5, 1, 2), "/", substr(md5, 3, nchar(md5)))
  utils::download.file(url, out_file, quiet = TRUE)
  out_file
}

#' Download All DVC-tracked Data
#'
#' Scans the input directory for `.dvc` pointer files and downloads each
#' corresponding data file from the public Cloudflare R2 remote,
#' preserving the subdirectory structure.
#' No credentials are required since the remote is publicly accessible.
#'
#' @param input_dir Path to the input directory to search for DVC files.
#' @param output_dir Path to the output directory.
#' @param overwrite Logical. If `FALSE`, skip files that already exist.
#' @param pkg_nm Package name, used to point to the Cloudflare R2 bucket of
#' interest.
#'
#' @return Invisibly returns a character vector of paths to downloaded files.
#'
#' @examples
#' \dontrun{
#' input_dir <- system.file("extdata", package = "nemo")
#' output_dir <- file.path(tempdir(), "dvc_dl_test")
#' result <- dvc_download_all(input_dir, output_dir)
#' result_cached <- dvc_download_all(input_dir, output_dir)
#' }
#' @export
dvc_download_all <- function(input_dir, output_dir, overwrite = FALSE, pkg_nm = "nemo") {
  dvc_files <- list.files(input_dir, pattern = "\\.dvc$", recursive = TRUE, full.names = TRUE)
  downloaded <- character(0)
  for (dvc_file in dvc_files) {
    # TODO: fix when specifying full path to dvc_file parent directory
    rel_subdir <- sub(input_dir, "", dirname(dvc_file))
    result <- dvc_download_file(
      dvc_file,
      file.path(output_dir, rel_subdir),
      overwrite = overwrite,
      pkg_nm = pkg_nm
    )
    if (!is.null(result)) downloaded <- c(downloaded, result)
  }
  message(
    sprintf("Downloaded %d / %d files to %s", length(downloaded), length(dvc_files), output_dir)
  )
  invisible(downloaded)
}
