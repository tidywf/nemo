#' List Files
#'
#' Lists files inside a given directory.
#'
#' @param d (`character(n)`)\cr
#' Character vector of one or more paths.
#' @param max_files (`integer(1)`)\cr
#' Max files returned.
#' @param type (`character(n)`)\cr
#' File type(s) to return (e.g. any, file, directory, symlink). See `fs::dir_info`.
#'
#' @return A tibble with file basename, size, last modification timestamp
#' and full path.
#' @examples
#' d <- system.file("R", package = "nemo")
#' x <- list_files_dir(d)
#' @testexamples
#' expect_equal(names(x), c("bname", "size", "lastmodified", "path"))
#' @export
list_files_dir <- function(d, max_files = NULL, type = "file") {
  d <- fs::dir_info(path = d, recurse = TRUE, type = type) |>
    dplyr::mutate(
      path = normalizePath(.data$path),
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
#' @param x (`character(1)`)\cr
#' Name of the attribute to retrieve.
#' @examples
#' path <- system.file("extdata/tool1", package = "nemo")
#' path2 <- file.path(path, "v1.2.3", "sampleA.tool1.table1.tsv")
#' x <- Tool1$new(path)$tidy(keep_raw = TRUE)
#' ind <- which(x$tbls$path == path2)
#' stopifnot(length(ind) == 1)
#' (v <- get_tbl_version_attr(x$tbls$raw[[ind]]))
#'
#' @testexamples
#' expect_equal(v, "v1.2.3")
#' @export
get_tbl_version_attr <- function(tbl, x = "file_version") {
  assertthat::assert_that(
    assertthat::has_attr(tbl, x),
    msg = paste("The table does not have the required attribute:", x)
  )
  attr(tbl, x)
}

#' Set Table Version Attribute
#'
#' Set the version attribute from a table.
#' @param tbl (`tibble()`)\cr
#' Table with a version attribute.
#' @param v (`character(1)`)\cr
#' Version string to set.
#' @param x (`character(1)`)\cr
#' Name of the attribute to retrieve.
#' @examples
#' d <- tibble::tibble(a = 1:3, b = letters[1:3])
#' v <- "v1.2.3"
#' d <- set_tbl_version_attr(d, v)
#' (a <- attr(d, "file_version"))
#'
#' @testexamples
#' expect_equal(a, v)
#' @export
set_tbl_version_attr <- function(tbl, v, x = "file_version") {
  attr(tbl, x) <- v
  tbl
}

#' Create Empty Tibble
#'
#' From https://stackoverflow.com/a/62535671/2169986. Useful for handling
#' edge cases with empty data. e.g. virusbreakend.vcf.summary.tsv
#'
#' @param ctypes (`character(n)`)\cr
#' Character vector of column types corresponding to `cnames`.
#' @param cnames (`character(n)`)\cr
#' Character vector of column names to use.
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

is_files_tbl <- function(x) {
  assertthat::assert_that(
    tibble::is_tibble(x),
    identical(colnames(x), c("bname", "size", "lastmodified", "path"))
  )
}

schema_type_remap <- function(x) {
  type_map <- c(char = "c", float = "d", int = "i")
  assertthat::assert_that(x %in% names(type_map))
  unname(type_map[x])
}


#' Enframe Data
#'
#' @return Enframed data with column name "data".
#' @param x (`list()`)\cr
#' List to enframe.
#' @export
enframe_data <- function(x) {
  tibble::enframe(x, name = "name", value = "data")
}

#' Get Python Binary
#'
#' Get the path to the Python binary in the system PATH.
#' @return Path to the Python binary.
#' @export
get_python <- function() {
  py <- Sys.which("python")
  stopifnot("Cannot find Python in PATH." = nchar(py) > 0)
  py
}

#' Nemoverse Workflow Dispatcher
#'
#' Dispatches the nemoverse workflow class based on the chosen workflow.
#'
#' @param wf Workflow name.
#' @return The nemo workflow class to initiate.
#' @examples
#' wf <- "basemean"
#' (fun <- nemoverse_wf_dispatch(wf))
#' @testexamples
#' expect_equal(fun, base::mean)
#' expect_error(nemoverse_wf_dispatch("foo"))
#' expect_error(nemoverse_wf_dispatch("dummy1"))
#' @export
nemoverse_wf_dispatch <- function(wf = NULL) {
  stopifnot(!is.null(wf))
  wfs <- list(
    wigits = list(pkg = "tidywigits", wf = "Wigits", repo = "https://github.com/umccr/tidywigits"),
    basemean = list(pkg = "base", wf = "mean", repo = "CRAN"),
    dummy1 = list(pkg = "dummy1", wf = "bar", repo = "BAZ")
    # dragen = list(pkg = "dracarys", wf = "Dragen"),
    # cttso = list(pkg = "cttsor", wf = "Tso")
  )
  all_wfs <- names(wfs)
  # check if wf available
  if (!wf %in% all_wfs) {
    all_wfs_glued <- glue::glue_collapse(all_wfs, sep = ", ", last = " or ")
    msg <- glue("Workflow '{wf}' not found. Available: {all_wfs_glued}")
    stop(msg)
  }
  x <- wfs[[wf]]
  if (pkg_found(x[["pkg"]])) {
    pkgfun <- getExportedValue(x[["pkg"]], x[["wf"]])
  } else {
    msg <- glue("Package {x[['pkg']]} not found, please install from {x[['repo']]}")
    stop(msg)
  }
  return(pkgfun)
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
  stopifnot(is.character(p), length(p) == 1)
  length(find.package(p, quiet = TRUE)) == 1
}
