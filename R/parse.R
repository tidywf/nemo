#' @keywords internal
count_file_cols <- function(fpath, delim, ...) {
  readr::read_delim(
    file = fpath,
    delim = delim,
    col_names = FALSE,
    col_types = readr::cols(.default = "c"),
    n_max = 1L,
    ...
  ) |>
    ncol()
}

#' Parse file
#'
#' @description
#' Parses files.
#'
#' @param fpath (`character(1)`)\cr
#' File path.
#' @param pname (`character(1)`)\cr
#' Parser name (e.g. "breakends" - see docs).
#' @param schemas_all (`tibble()`)\cr
#' Tibble with name, version and schema list-col.
#' @param delim (`character(1)`)\cr
#' File delimiter.
#' @param ... Passed on to `readr::read_delim`.
#'
#' @examples
#' path <- system.file("extdata/tool1", package = "nemo")
#' x <- Tool$new("tool1", pkg = "nemo", path)
#' schemas_all <- x$config$get_schemas_raw()
#' f <- function(ver, tbl) file.path(path, ver, paste0("sampleA.tool1.", tbl, ".tsv"))
#' # table1: three versions with different column sets
#' (d1_v123 <- parse_file(f("v1.2.3", "table1"), "table1", schemas_all))
#' (d1_v456 <- parse_file(f("v4.5.6", "table1"), "table1", schemas_all))
#' (d1_lat  <- parse_file(f("latest", "table1"), "table1", schemas_all))
#' # table2: two versions (v1.0.0 drops metricB)
#' (d2_v1  <- parse_file(f("v1.0.0", "table2"), "table2", schemas_all))
#' (d2_lat <- parse_file(f("latest", "table2"), "table2", schemas_all))
#'
#' @testexamples
#' # table1 version detection
#' expect_equal(attr(d1_v123, "file_version"), "v1.2.3")
#' expect_equal(attr(d1_v456, "file_version"), "v4.5.6")
#' expect_equal(attr(d1_lat,  "file_version"), "latest")
#' expect_equal(names(d1_v123), c("SampleID", "Chromosome", "Start", "End", "metricX"))
#' expect_equal(names(d1_v456), c("SampleID", "Chromosome", "Start", "End"))
#' expect_equal(names(d1_lat),  c("SampleID", "Chromosome", "Start", "End", "metricY", "metricZ"))
#' # table2 version detection
#' expect_equal(attr(d2_v1,  "file_version"), "v1.0.0")
#' expect_equal(attr(d2_lat, "file_version"), "latest")
#' expect_equal(names(d2_v1),  c("SampleID", "metricA"))
#' expect_equal(names(d2_lat), c("SampleID", "metricA", "metricB"))
#' @export
parse_file <- function(fpath, pname, schemas_all, delim = "\t", ...) {
  cnames <- file_hdr(fpath, delim = delim, ...)
  schema_tbl <- schema_guess(
    pname = pname,
    cnames = cnames,
    schemas_all = schemas_all
  )
  ctypes <- rlang::exec(readr::cols, !!!tibble::deframe(schema_tbl[["schema"]]))
  d <- readr::read_delim(
    file = fpath,
    delim = delim,
    col_types = ctypes,
    ...
  )
  attr(d, "file_version") <- schema_tbl[["version"]]
  d[]
}

#' Parse headless file
#'
#' @description
#' Parses files with no column names. Selects the schema version whose column
#' count matches the file.
#'
#' @param fpath (`character(1)`)\cr
#' File path.
#' @param pname (`character(1)`)\cr
#' Parser name (e.g. "table4" - see docs).
#' @param schemas_all (`tibble()`)\cr
#' Tibble with name, version and schema list-col.
#' @param delim (`character(1)`)\cr
#' File delimiter.
#' @param ... Passed on to `readr::read_delim`.
#'
#' @examples
#' path <- system.file("extdata/tool1", package = "nemo")
#' x <- Tool$new("tool1", pkg = "nemo", path)
#' schemas_all <- x$config$get_schemas_raw()
#' pname <- "table4"
#' fpath_latest <- file.path(path, "latest", "sampleA.tool1.table4.tsv")
#' fpath_v1 <- file.path(path, "v1.0.0", "sampleA.tool1.table4.tsv")
#' (d_latest <- parse_file_nohead(fpath_latest, pname, schemas_all))
#' (d_v1 <- parse_file_nohead(fpath_v1, pname, schemas_all))
#'
#' @testexamples
#' expect_equal(ncol(d_latest), 5)
#' expect_equal(ncol(d_v1), 3)
#' expect_equal(names(d_latest), c("X1", "X2", "X3", "X4", "X5"))
#' expect_equal(names(d_v1), c("X1", "X2", "X3"))
#' expect_equal(attr(d_latest, "file_version"), "latest")
#' expect_equal(attr(d_v1, "file_version"), "v1.0.0")
#' @export
parse_file_nohead <- function(fpath, pname, schemas_all, delim = "\t", ...) {
  # count_file_cols reads with col_names = FALSE so the first data row is treated
  # as data, not a header — file_hdr() would be semantically wrong here.
  ncols <- count_file_cols(fpath, delim, ...)
  schema <- schemas_all |>
    dplyr::filter(.data$name == pname) |>
    dplyr::select("version", "schema") |>
    dplyr::filter(purrr::map_int(.data$schema, nrow) == ncols)
  if (nrow(schema) != 1) {
    nemo_stop(glue(
      "Expected exactly one schema version matching {ncols} columns ",
      "for '{pname}', found {nrow(schema)}."
    ))
  }
  version <- schema[["version"]]
  schema_deframed <- tibble::deframe(schema[["schema"]][[1]])
  ctypes <- rlang::exec(readr::cols, !!!schema_deframed)
  d <- readr::read_delim(
    file = fpath,
    col_names = names(schema_deframed),
    col_types = ctypes,
    delim = delim,
    ...
  )
  attr(d, "file_version") <- version
  d[]
}

#' Get file header
#'
#' @description
#' Returns the column names of a file without reading the entire file.
#'
#' @param fpath (`character(1)`)\cr
#' File path.
#' @param delim (`character(1)`)\cr
#' File delimiter.
#' @param n_max (`integer(1)`)\cr
#' Maximum number of lines to read.
#' @param ... Passed on to `readr::read_delim`.
#'
#' @examples
#' dir1 <- system.file("extdata/tool1", package = "nemo")
#' fpath <- file.path(dir1, "latest", "sampleA.tool1.table1.tsv")
#' (hdr <- file_hdr(fpath))
#'
#' @testexamples
#' expect_equal(hdr[1:2], c("SampleID", "Chromosome"))
#' @export
file_hdr <- function(fpath, delim = "\t", n_max = 0, ...) {
  readr::read_delim(
    fpath,
    delim = delim,
    col_types = readr::cols(.default = "c"),
    n_max = n_max,
    ...
  ) |>
    colnames()
}

#' Guess Schema
#'
#' @description
#' Given a tibble of available schemas, filters to the one
#' matching the given column names. Errors out if unsuccessful.
#'
#' @param pname (`character(1)`)\cr
#' Parser name.
#' @param cnames (`character(n)`)\cr
#' Column names.
#' @param schemas_all (`tibble()`)\cr
#' Tibble with name, version and schema list-col.
#'
#' @examples
#' dir1 <- system.file("extdata/tool1", package = "nemo")
#' fpath1 <- file.path(dir1, "latest", "sampleA.tool1.table1.tsv")
#' fpath2 <- file.path(dir1, "v1.2.3", "sampleA.tool1.table1.tsv")
#' pname <- "table1"
#' cnames1 <- file_hdr(fpath1)
#' cnames2 <- file_hdr(fpath2)
#' conf <- Config$new("tool1", pkg = "nemo")
#' schemas_all <- conf$get_schemas_raw()
#' (s1 <- schema_guess(pname, cnames1, schemas_all))
#' (s2 <- schema_guess(pname, cnames2, schemas_all))
#'
#' @testexamples
#' expect_equal(length(s1), 2)
#' expect_equal(s1[["version"]], "latest")
#' expect_equal(s2[["version"]], "v1.2.3")
#' @export
schema_guess <- function(pname, cnames, schemas_all) {
  if (!rlang::is_bare_character(cnames)) {
    nemo_stop("'cnames' must be a bare character vector.")
  }
  if (!tibble::is_tibble(schemas_all)) {
    nemo_stop("'schemas_all' must be a tibble.")
  }
  if (!all(c("name", "version", "schema") %in% colnames(schemas_all))) {
    nemo_stop("'schemas_all' must have columns: name, version, schema.")
  }
  if (!pname %in% schemas_all[["name"]]) {
    nemo_stop(glue("'{pname}' not found in schemas_all$name."))
  }
  s <- schemas_all |>
    dplyr::filter(.data$name == pname) |>
    dplyr::select("version", "schema") |>
    dplyr::filter(purrr::map_lgl(.data$schema, \(sch) identical(cnames, sch[["field"]])))
  if (nrow(s) != 1) {
    nemo_stop(glue(
      "Expected 1 matching schema for '{pname}', found {nrow(s)}. ",
      "Column names seen: {glue::glue_collapse(cnames, sep = ', ')}."
    ))
  }
  version <- s$version
  schema <- s |>
    dplyr::select("schema") |>
    tidyr::unnest("schema")
  list(schema = schema, version = version)
}

#' Parse Key-Value file
#'
#' @description
#' Parses files with no header and two columns representing key-value pairs.
#'
#' @param fpath (`character(1)`)\cr
#' File path.
#' @param pname (`character(1)`)\cr
#' Parser name.
#' @param schemas_all (`tibble()`)\cr
#' Tibble with name, version and schema list-col.
#' @param delim (`character(1)`)\cr
#' File delimiter.
#' @param ... Passed on to `readr::read_delim`.
#'
#' @examples
#' path <- system.file("extdata/tool1", package = "nemo")
#' x <- Tool1$new(path)
#' schemas_all <- x$config$get_schemas_raw()
#' pname <- "table3"
#' f <- function(ver) file.path(path, ver, "sampleA.tool1.table3.tsv")
#' # v1.0.0: 3 key-value pairs (SampleID, QCStatus, TotalReads)
#' (d3_v1  <- parse_file_keyvalue(f("v1.0.0"), pname, schemas_all))
#' # latest: 5 key-value pairs
#' (d3_lat <- parse_file_keyvalue(f("latest"), pname, schemas_all))
#'
#' @testexamples
#' expect_equal(attr(d3_v1,  "file_version"), "v1.0.0")
#' expect_equal(attr(d3_lat, "file_version"), "latest")
#' expect_equal(names(d3_v1),  c("SampleID", "QCStatus", "TotalReads"))
#' expect_equal(names(d3_lat), c("SampleID", "QCStatus", "TotalReads", "MappedReads", "UnmappedReads"))
#' @export
parse_file_keyvalue <- function(fpath, pname, schemas_all, delim = "\t", ...) {
  ncols <- count_file_cols(fpath, delim, ...)
  if (ncols != 2) {
    nemo_stop(glue("Expected 2 columns, but found {ncols} in '{fpath}'."))
  }
  d <- readr::read_delim(
    file = fpath,
    col_names = c("key", "value"),
    col_types = "cc",
    delim = delim,
    ...
  )
  d_wide <- d |>
    tidyr::pivot_wider(names_from = "key", values_from = "value")
  schema <- schema_guess(
    pname = pname,
    cnames = colnames(d_wide),
    schemas_all = schemas_all
  )
  # schema is used only for version detection; column types are not applied because
  # key-value files are inherently all-character after the pivot.
  attr(d_wide, "file_version") <- schema[["version"]]
  d_wide[]
}
