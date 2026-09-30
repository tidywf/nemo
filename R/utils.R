#' List Files
#'
#' Lists files inside a given directory.
#'
#' @param path (`character(n)`)\cr
#' Character vector of one or more paths.
#' @param max_files (`integer(1)`)\cr
#' Max files returned.
#' @param type (`character(n)`)\cr
#' File type(s) to return (e.g. any, file, directory). See `fs::dir_info`.
#' Symlinks are followed and classified by their target, so a symlink to a
#' file counts as a `file` (with the target's size and modification time);
#' broken symlinks are dropped.
#'
#' @return A tibble with file basename, size, last modification timestamp
#' and full path.
#' @examples
#' d <- system.file("R", package = "nemo")
#' x <- list_files_dir(d)
#' # symlinked files are included
#' d2 <- fs::dir_create(tempfile())
#' f <- fs::file_create(file.path(d2, "real.tsv"))
#' fs::link_create(f, file.path(d2, "link.tsv"))
#' x2 <- list_files_dir(d2)
#' @testexamples
#' expect_equal(names(x), c("bname", "size", "lastmodified", "path"))
#' expect_setequal(x2$bname, c("real.tsv", "link.tsv"))
#' @export
list_files_dir <- function(path, max_files = NULL, type = "file") {
  # normalise the roots, not each file: that would resolve symlinks to their
  # targets and replace the basename we match patterns against
  paths <- fs::dir_ls(path = normalizePath(path), recurse = TRUE, type = "any")
  d <- fs::file_info(paths, follow = TRUE)
  # follow = TRUE also rewrites `path` to the target; keep the link's path
  d$path <- paths
  if (!"any" %in% type) {
    keep <- type
    # NA type = broken symlink
    d <- dplyr::filter(d, !is.na(.data$type), .data$type %in% keep)
  }
  d <- d |>
    dplyr::mutate(
      path = as.character(.data$path),
      bname = basename(.data$path),
      lastmodified = .data$modification_time
    ) |>
    dplyr::select("bname", "size", "lastmodified", "path")
  if (!is.null(max_files)) {
    d <- d |>
      dplyr::slice_head(n = max_files)
  }
  d
}

#' Get Table Version Attribute
#'
#' Get the version attribute from a table.
#' @param tbl (`tibble()`)\cr
#' Table with a version attribute.
#' @examples
#' path <- system.file("extdata/tool1", package = "nemo")
#' path2 <- file.path(path, "v1.2.3", "sampleA.tool1.table1.tsv")
#' x <- Tool1$new(path)$tidy(keep_raw = TRUE)
#' ind <- which(x$get_tbls()$path == path2)
#' stopifnot(length(ind) == 1)
#' (v <- get_tbl_version_attr(x$get_tbls()$raw[[ind]]))
#'
#' @testexamples
#' expect_equal(v, "v1.2.3")
#' @export
get_tbl_version_attr <- function(tbl) {
  v <- attr(tbl, "file_version")
  if (is.null(v)) {
    nemo_stop("The table does not have the required attribute: file_version")
  }
  v
}

#' Set Table Version Attribute
#'
#' Set the version attribute on a table.
#' @param tbl (`tibble()`)\cr
#' Table with a version attribute.
#' @param v (`character(1)`)\cr
#' Version string to set.
#' @examples
#' d <- tibble::tibble(a = 1:3, b = letters[1:3])
#' v <- "v1.2.3"
#' d <- set_tbl_version_attr(d, v)
#' (a <- attr(d, "file_version"))
#'
#' @testexamples
#' expect_equal(a, v)
#' @export
set_tbl_version_attr <- function(tbl, v) {
  attr(tbl, "file_version") <- v
  tbl
}

#' Create Empty Tibble
#'
#' From https://stackoverflow.com/a/62535671/2169986. Useful for handling
#' edge cases with empty data. e.g. virusbreakend.vcf.summary.tsv
#'
#' @param cnames (`character(n)`)\cr
#' Character vector of column names to use.
#' @param ctypes (`character(n)`)\cr
#' Character vector of column types corresponding to `cnames`.
#'
#' @return A tibble with 0 rows and the given column names.
#' @examples
#' (x <- empty_tbl(cnames = c("a", "b", "c")))
#' @testexamples
#' expect_equal(nrow(x), 0)
#' @export
empty_tbl <- function(cnames, ctypes = readr::cols(.default = "c")) {
  d <- readr::read_csv(I("\n"), col_names = cnames, col_types = ctypes)
  d[]
}

#' Enframe Data
#'
#' @return Enframed data with column name "data".
#' @param x (`list()`)\cr
#' List to enframe.
#' @export
nemo_enframe <- function(x) {
  tibble::enframe(x, name = "name", value = "data")
}

#' Get Python Binary
#'
#' Get the path to the Python binary in the system PATH.
#' @keywords internal
get_python <- function() {
  py <- Sys.which("python")
  if (!nzchar(py)) {
    nemo_stop("Cannot find Python in PATH.")
  }
  py
}

#' Nemoverse Workflow Dispatcher
#'
#' Dispatches the nemoverse workflow class based on the chosen workflow.
#'
#' @param wf Workflow name.
#' @return The nemo workflow class to initiate.
#' @examples
#' (fun <- nemoverse_wf_dispatch("workflow1"))
#' @testexamples
#' expect_identical(fun, Workflow1)
#' expect_error(nemoverse_wf_dispatch("foo"))
#' @export
nemoverse_wf_dispatch <- function(wf) {
  nemo_assert_not_null(wf)
  wfs <- list(
    wigits = list(pkg = "tidywigits", wf = "Wigits", repo = "https://github.com/tidywf/tidywigits"),
    dragen = list(pkg = "tidydragen", wf = "Dragen", repo = "https://github.com/tidywf/tidydragen"),
    workflow1 = list(pkg = "nemo", wf = "Workflow1", repo = "https://github.com/tidywf/nemo")
  )
  all_wfs <- names(wfs)
  if (!wf %in% all_wfs) {
    all_wfs_glued <- glue::glue_collapse(all_wfs, sep = ", ", last = " or ")
    msg <- glue("Workflow '{wf}' not found. Available: {all_wfs_glued}")
    nemo_stop(msg)
  }
  x <- wfs[[wf]]
  if (!pkg_found(x[["pkg"]])) {
    nemo_stop(glue("Package {x[['pkg']]} not found, please install from {x[['repo']]}"))
  }
  getExportedValue(x[["pkg"]], x[["wf"]])
}

#' Read Parquet File Matched By Pattern
#'
#' Test helper: reads the single parquet file in `odir` whose basename (from
#' `lf`) matches `pattern`. Errors on zero or multiple matches unless
#' `first = TRUE`.
#'
#' @param odir (`character(1)`)\cr
#' Directory the files live in.
#' @param lf (`character(n)`)\cr
#' Basenames to match `pattern` against.
#' @param pattern (`character(1)`)\cr
#' Regex passed to `grep()`.
#' @param first (`logical(1)`)\cr
#' If `pattern` matches more than one file, read the first match instead of
#' erroring.
#'
#' @return (`tibble`) Parsed parquet file.
#' @examples
#' odir <- fs::dir_create(tempfile())
#' arrow::write_parquet(data.frame(x = 1L), file.path(odir, "a_1.parquet"))
#' arrow::write_parquet(data.frame(x = 2L), file.path(odir, "a_2.parquet"))
#' lf <- list.files(odir)
#' (x <- read_parquet_grep(odir, lf, "a_1"))
#' (y <- read_parquet_grep(odir, lf, "^a_", first = TRUE))
#' @testexamples
#' expect_equal(x$x, 1L)
#' expect_equal(y$x, 1L)
#' expect_error(read_parquet_grep(odir, lf, "^a_"), "2 files match")
#' expect_error(read_parquet_grep(odir, lf, "nomatch"), "No file matches")
#' expect_error(read_parquet_grep(odir, lf, "nomatch", first = TRUE), "No file matches")
#' @export
read_parquet_grep <- function(odir, lf, pattern, first = FALSE) {
  m <- grep(pattern, lf, value = TRUE)
  if (length(m) == 0) {
    nemo_stop(glue("No file matches '{pattern}'."))
  }
  if (length(m) > 1 && !first) {
    nemo_stop(glue(
      "{length(m)} files match '{pattern}': {glue::glue_collapse(m, sep = ', ')}. ",
      "Tighten the pattern or set first = TRUE."
    ))
  }
  arrow::read_parquet(file.path(odir, m[1]))
}

#' Check if Package is Installed
#'
#' Check if an R package is installed.
#' @param p (`character(1)`)\cr
#' Package name.
#' @return `TRUE` if the package is installed, `FALSE` otherwise.
#' @examples
#' pkg_found("base")
#' pkg_found("somefakepackagename")
#' @testexamples
#' expect_true(pkg_found("base"))
#' expect_false(pkg_found("somefakepackagename"))
#' @export
pkg_found <- function(p) {
  nemo_assert_scalar_chr(p)
  length(find.package(p, quiet = TRUE)) == 1
}
