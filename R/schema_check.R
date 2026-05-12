#' Validate a tool's schema.yaml against nemo conventions
#'
#' @description
#' Checks schema structure and prints a pass/fail summary: required fields,
#' valid `ftype`/`type` values, snake_case `tidy` names, non-empty `versions`
#' arrays.
#'
#' @param tool (`character(1)`)\cr Tool name, e.g. `"tool1"`.
#' @param pkg (`character(1)`)\cr Package owning the tool config.
#'
#' @return Invisibly returns a tibble of issues (zero rows means all pass).
#'
#' @examples
#' nemo_schema_check("tool1", pkg = "nemo")
#' # invalid schema example: bad ftype, non-snake_case tidy, invalid type
#' bad_cfg <- list(tables = list(
#'   mytable = list(
#'     description = "x", pattern = "\\.tsv$", ftype = "bad_ftype",
#'     columns = list(list(
#'       raw = "Col1", tidy = "BadTidy", type = "str",
#'       description = "col1", versions = list("latest")
#'     ))
#'   )
#' ))
#' @testexamples
#' res <- nemo_schema_check("tool1", pkg = "nemo")
#' expect_s3_class(res, "tbl_df")
#' expect_equal(nrow(res), 0L)
#' #.schema_check_structure(bad_cfg)
#' @export
nemo_schema_check <- function(tool, pkg = "nemo") {
  tool <- tolower(tool)
  schema_path <- system.file("config/tools", tool, "schema.yaml", package = pkg)
  assertthat::assert_that(
    nzchar(schema_path),
    msg = glue("schema.yaml not found for {tool} in package {pkg}")
  )
  cfg <- yaml::read_yaml(schema_path)
  writeLines(c("", glue("=== nemo_schema_check: {pkg}::{tool} ==="), ""))

  issues <- .schema_check_structure(cfg)
  n <- nrow(issues)
  if (n == 0L) {
    writeLines("[PASS] Schema structure")
  } else {
    writeLines(glue("[FAIL] Schema structure ({n} issue(s))"))
    for (i in seq_len(n)) {
      writeLines(glue("  - {issues$location[i]}: {issues$issue[i]}"))
    }
  }
  writeLines("")
  invisible(issues)
}

.schema_check_structure <- function(cfg) {
  valid_ftypes <- c("txt", "csv", "txt-nohead", "txt-keyvalue", "csv-nohead-long")
  valid_types <- c("char", "int", "float")
  req_tab_fields <- c("description", "pattern", "ftype", "columns")
  req_col_fields <- c("raw", "tidy", "type", "description", "versions")

  issues <- list()
  add <- function(loc, msg) {
    issues[[length(issues) + 1L]] <<- tibble::tibble(location = loc, issue = msg)
  }

  if (!"tables" %in% names(cfg)) {
    add("top-level", "Missing 'tables' key")
    return(dplyr::bind_rows(issues))
  }
  tables <- cfg[["tables"]]
  if (!is.list(tables) || is.null(names(tables))) {
    add("tables", "'tables' must be a named map, not a list")
    return(dplyr::bind_rows(issues))
  }

  for (tname in names(tables)) {
    tab <- tables[[tname]]
    missing_tf <- setdiff(req_tab_fields, names(tab))
    if (length(missing_tf) > 0L) {
      add(tname, glue("Missing table field(s): {paste(missing_tf, collapse = ', ')}"))
    }
    if ("ftype" %in% names(tab) && !tab$ftype %in% valid_ftypes) {
      add(
        tname,
        glue(
          "Invalid ftype '{tab$ftype}'. Valid: {paste(valid_ftypes, collapse = ', ')}"
        )
      )
    }
    if ("columns" %in% names(tab)) {
      for (i in seq_along(tab$columns)) {
        col <- tab$columns[[i]]
        clabel <- if (!is.null(col$raw)) col$raw else glue("col[{i}]")
        loc <- glue("{tname}/{clabel}")
        missing_cf <- setdiff(req_col_fields, names(col))
        if (length(missing_cf) > 0L) {
          add(loc, glue("Missing column field(s): {paste(missing_cf, collapse = ', ')}"))
        }
        if ("type" %in% names(col) && !col$type %in% valid_types) {
          add(
            loc,
            glue(
              "Invalid type '{col$type}'. Valid: {paste(valid_types, collapse = ', ')}"
            )
          )
        }
        if ("tidy" %in% names(col) && !grepl("^[a-z][a-z0-9_]*$", col$tidy)) {
          add(loc, glue("tidy '{col$tidy}' is not snake_case"))
        }
        if ("versions" %in% names(col) && length(col$versions) == 0L) {
          add(loc, "versions array is empty")
        }
      }
    }
  }

  if (length(issues) == 0L) {
    tibble::tibble(location = character(), issue = character())
  } else {
    dplyr::bind_rows(issues)
  }
}
