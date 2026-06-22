#' Prepare config schema from raw file
#'
#' @description
#' Scaffolds a schema tibble from a raw file. The `tidy` column is a
#' best-effort snake_case conversion — edit the YAML after writing.
#'
#' @param path (`character(1)`)\cr
#' File path.
#' @param v (`character(1)`)\cr
#' Version string to assign to all columns (default `"latest"`).
#' @param ... Passed on to `readr::read_delim`.
#' @returns A tibble with columns `raw`, `tidy`, `type`, `description`,
#' and `versions` (list-col of `list(v)`).
#' @examples
#' path <- system.file("extdata", "tool1/latest/sampleA.tool1.table1.tsv", package = "nemo")
#' (x <- config_prep_raw_schema(path = path, delim = "\t"))
#' @testexamples
#' expect_named(x, c("raw", "tidy", "type", "description", "versions"))
#' expect_equal(nrow(x), 6L)
#' expect_equal(x[1, "raw",  drop = TRUE], "SampleID")
#' expect_equal(x[1, "tidy", drop = TRUE], "sample_id")
#' expect_equal(x[1, "type", drop = TRUE], "char")
#' expect_equal(unlist(x[[1, "versions"]]), "latest")
#' @export
config_prep_raw_schema <- function(path, v = "latest", ...) {
  type_map <- c(
    "character" = "char",
    "integer" = "int",
    "numeric" = "float",
    "logical" = "char"
  )
  .to_snake <- function(s) {
    gsub(
      "^_+|_+$",
      "",
      gsub("[^a-z0-9]+", "_", tolower(gsub("([[:lower:]])([[:upper:]])", "\\1_\\2", s)))
    )
  }
  raw_types <- path |>
    readr::read_delim(n_max = 100, show_col_types = FALSE, ...) |>
    purrr::map_chr(\(x) class(x)[1])
  unknown <- setdiff(unique(raw_types), names(type_map))
  if (length(unknown) > 0) {
    warning(glue("Column types not in type_map will produce NA: {paste(unknown, collapse = ', ')}"))
  }
  raw_types |>
    tibble::enframe(name = "raw", value = "type") |>
    dplyr::mutate(
      tidy = .to_snake(.data$raw),
      type = unname(type_map[.data$type]),
      description = "",
      versions = purrr::map(.data$raw, \(.) list(v))
    ) |>
    dplyr::select("raw", "tidy", "type", "description", "versions")
}

#' Prepare config from raw file
#'
#' @description
#' Scaffolds a single-table config entry from a raw file. Part of the
#' `config_prep_*` family for bootstrapping a new `schema.yaml`.
#'
#' @param path (`character(1)`)\cr
#' File path.
#' @param name (`character(1)`)\cr
#' Table name (key in `tables:`).
#' @param descr (`character(1)`)\cr
#' Table description.
#' @param pat (`character(1)`)\cr
#' File pattern (regex).
#' @param type (`character(1)`)\cr
#' File type (`ftype`).
#' @param v (`character(1)`)\cr
#' Version string to assign to all columns (default `"latest"`).
#' @param ... Passed on to `readr::read_delim`.
#' @returns A named list matching the `tables:` entry format for `schema.yaml`.
#' @examples
#' path <- system.file("extdata", "tool1/latest/sampleA.tool1.table1.tsv", package = "nemo")
#' name <- "table1"
#' descr <- "Table1 from Tool1."
#' pat <- "\\.tool1\\.table1\\.tsv$"
#' l <- config_prep_raw(path, name, descr, pat)
#' @testexamples
#' expect_equal(names(l[[1]]), c("description", "pattern", "ftype", "columns"))
#' expect_equal(length(l[[1]][["columns"]]), 6L)
#' col1 <- l[[1]][["columns"]][[1]]
#' expect_named(col1, c("raw", "tidy", "type", "description", "versions"))
#' expect_equal(col1[["raw"]], "SampleID")
#' expect_equal(col1[["tidy"]], "sample_id")
#' @export
config_prep_raw <- function(path, name, descr, pat, type = "txt", v = "latest", ...) {
  schema <- config_prep_raw_schema(path = path, v = v, ...)
  columns <- purrr::pmap(schema, list)
  entry <- list(description = descr, pattern = pat, ftype = type, columns = columns)
  rlang::set_names(list(entry), name)
}

#' Prepare config for multiple raw files
#'
#' @param x (`tibble()`)\cr
#' Tibble with columns `name`, `descr`, `pat`, `type`, and `path`.
#'
#' @returns A list `list(tables = ...)` ready to write with `config_prep_write()`.
#'
#' @examples
#' dir1 <-  "extdata/tool1/latest"
#' path1 <- system.file(dir1, "sampleA.tool1.table1.tsv", package = "nemo")
#' path2 <- system.file(dir1, "sampleA.tool1.table2.tsv", package = "nemo")
#' x <- tibble::tibble(
#'   name = c("table1", "table2"),
#'   descr = c("Table1 from Tool1.", "Table2 from Tool1."),
#'   pat = c("\\.tool1\\.table1\\.tsv$", "\\.tool1\\.table2\\.tsv$"),
#'   type = c("txt", "txt"),
#'   path = c(path1, path2)
#' )
#' config <- config_prep_multi(x)
#' @testexamples
#' expect_equal(names(config), "tables")
#' expect_equal(names(config[["tables"]]), c("table1", "table2"))
#' tbl1 <- config[["tables"]][["table1"]]
#' expect_equal(names(tbl1), c("description", "pattern", "ftype", "columns"))
#' expect_equal(length(tbl1[["columns"]]), 6L)
#' expect_named(tbl1[["columns"]][[1]], c("raw", "tidy", "type", "description", "versions"))
#' @export
config_prep_multi <- function(x) {
  if (!tibble::is_tibble(x)) {
    nemo_stop("'x' must be a tibble.")
  }
  if (!all(c("name", "descr", "pat", "type", "path") %in% colnames(x))) {
    nemo_stop("'x' must have columns: name, descr, pat, type, path.")
  }
  if (nrow(x) == 0) {
    nemo_stop("'x' must have at least one row.")
  }
  tables <- purrr::pmap(
    dplyr::select(x, "name", "descr", "pat", "type", "path"),
    \(name, descr, pat, type, path) {
      config_prep_raw(path = path, name = name, descr = descr, pat = pat, type = type)
    }
  ) |>
    purrr::list_flatten()
  list(tables = tables)
}

#' Write config to YAML file
#'
#' @param x (`list()`)\cr
#' Config list, generated by `config_prep_multi()`.
#' @param out (`character(1)`)\cr
#' Output file path.
#'
#' @returns Nothing, called for side effects.
#'
#' @examples
#' dir1 <- "extdata/tool1/latest"
#' path1 <- system.file(dir1, "sampleA.tool1.table1.tsv", package = "nemo")
#' path2 <- system.file(dir1, "sampleA.tool1.table2.tsv", package = "nemo")
#' x <- tibble::tibble(
#'   name = c("table1", "table2"),
#'   descr = c("Table1 from Tool1.", "Table2 from Tool1."),
#'   pat = c("\\.tool1\\.table1\\.tsv$", "\\.tool1\\.table2\\.tsv$"),
#'   type = c("txt", "txt"),
#'   path = c(path1, path2)
#' )
#' config <- config_prep_multi(x)
#' out <- tempfile(fileext = ".yaml")
#' config_prep_write(config, out)
#' @testexamples
#' parsed <- yaml::read_yaml(out)
#' expect_equal(names(parsed), "tables")
#' expect_equal(names(parsed[["tables"]]), c("table1", "table2"))
#' tbl1 <- parsed[["tables"]][["table1"]]
#' expect_equal(names(tbl1), c("description", "pattern", "ftype", "columns"))
#' col1 <- tbl1[["columns"]][[1]]
#' expect_named(col1, c("raw", "tidy", "type", "description", "versions"))
#' expect_equal(col1[["raw"]], "SampleID")
#' expect_equal(col1[["versions"]][[1]], "latest")
#' @export
config_prep_write <- function(x, out) {
  yaml::write_yaml(x, out, column.major = FALSE)
}
