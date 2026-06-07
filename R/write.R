#' Write data
#'
#' Writes tabular data in the given format.
#'
#' @param d (`data.frame()`)\cr
#' A data.frame (or tibble) with tidy data.
#' @param fpfix (`character(1)`)\cr
#' File prefix. The file extension is generated automatically via the `format`
#' argument. For a format of db, this is inserted into the `nemo_pfix` column.
#' @param format (`character(1)`)\cr
#' Output format. One of tsv, csv, parquet, rds, or db.
#' @param dbconn (`DBIConnection(1)`)\cr
#' Database connection object (see `DBI::dbConnect`). Used only when format is db.
#' @param dbtab (`character(1)`)\cr
#' Database table name (see `DBI::dbWriteTable`). Used only when format is db.
#' @return (`character(1)`)\cr
#' The output file path (invisibly). `NA_character_` when format is `"db"`.
#'
#' @examples
#' d <- tibble::tibble(name = "foo", data = 123)
#' fpfix <- file.path(tempdir(), "data_test1")
#' format <- "csv"
#' nemo_write(d = d, fpfix = fpfix, format = format)
#' (res <- readr::read_csv(glue::glue("{fpfix}.csv.gz"), show_col_types = FALSE))
#' \dontrun{
#' # for database writing — supply a DBI driver from e.g. RPostgres or duckdb
#' con <- DBI::dbConnect(RPostgres::Postgres(), dbname = "mydb", user = "me")
#' tbl_nm <- "awesome_tbl"
#' nemo_write(d = d, fpfix = basename(fpfix), format = "db", dbconn = con, dbtab = tbl_nm)
#' DBI::dbListTables(con)
#' DBI::dbReadTable(con, tbl_nm)
#' DBI::dbDisconnect(con)
#' }
#' @testexamples
#' expect_equal(nrow(res), 1)
#' @export
nemo_write <- function(d, fpfix = NULL, format = "tsv", dbconn = NULL, dbtab = NULL) {
  stopifnot(is.data.frame(d))
  if (format == "db") {
    nemo_assert_not_null(dbconn)
    nemo_assert_not_null(dbtab)
    DBI::dbWriteTable(
      conn = dbconn,
      name = dbtab,
      value = d,
      append = TRUE,
      overwrite = FALSE
    )
  } else {
    nemo_assert_not_null(fpfix)
    fpfix <- as.character(fpfix)
    osfx <- nemo_osfx(fpfix, format)
    fs::dir_create(dirname(fpfix))
    w <- list(
      tsv = list(fun = "write_tsv", pkg = "readr"),
      csv = list(fun = "write_csv", pkg = "readr"),
      parquet = list(fun = "write_parquet", pkg = "arrow"),
      rds = list(fun = "write_rds", pkg = "readr")
    )
    x <- w[[format]]
    fun <- getExportedValue(x[["pkg"]], x[["fun"]])
    fun(d, osfx)
  }
  invisible(if (format == "db") NA_character_ else osfx)
}

#' Output Format is Valid
#'
#' Checks that the specified output format is valid.
#' @param x Output format.
#' @param choices Available choices for valid output formats.
#' @examples
#' valid_out_fmt("tsv")
#' @testexamples
#' expect_true(valid_out_fmt("tsv"))
#' expect_error(valid_out_fmt("foo"))
#' expect_error(valid_out_fmt(c("tsv", "csv")))
#' @export
valid_out_fmt <- function(x, choices = nemo_out_formats()) {
  y <- glue::glue_collapse(choices, sep = ", ", last = " or ")
  if (!rlang::is_scalar_character(x) || !x %in% choices) {
    stop(glue("Output format should be _one_ of {y}."), call. = FALSE)
  }
  invisible(TRUE)
}

#' Output Formats Supported
#'
#' @return Character vector of supported output formats.
#' @export
nemo_out_formats <- function() {
  c("parquet", "db", "tsv", "csv", "rds")
}

#' Construct Output File Paths with Format Suffix
#'
#' @param fpfix (`character(n)`)\cr
#' Vector of one or more file prefixes e.g. /path/to/foo
#' @param format (`character(1)`)\cr
#' Output format. One of tsv, csv, parquet, rds, or db.
#' @return Character vector of output file paths
#'
#' @examples
#' fpfix <- "path/to/foo"
#' format <- "tsv"
#' (o <- nemo_osfx(fpfix, format))
#' @testexamples
#' expect_equal(o, glue("{fpfix}.tsv.gz"))
#'
#' @export
nemo_osfx <- function(fpfix, format) {
  valid_out_fmt(format)
  fpfix <- as.character(fpfix)
  sfx <- c(tsv = "tsv.gz", csv = "csv.gz", parquet = "parquet", rds = "rds")
  paste0(fpfix, ".", sfx[format])
}
