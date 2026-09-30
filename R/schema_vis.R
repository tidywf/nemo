#' Render a reactable schema table
#'
#' @description
#' Renders an interactive [reactable::reactable()] with one row per table.
#' Global search also matches raw/tidy column names and globs (via hidden
#' searchable columns). Expanding a row shows the table's glob and its columns,
#' with one column per schema version marking where each column is present.
#'
#' This is a low-level function; most callers should use [nemo_schema_reactable()]
#' instead.
#'
#' @param dat data frame as produced by [nemo_schemavis_data()].
#' @param ... additional arguments passed to [reactable::reactable()].
#' @return An htmlwidget.
#' @examples
#' \dontrun{
#' dat <- nemo_schemavis_data("tool1", pkg = "nemo")
#' reactable_schema(dat)
#' }
#' @export
reactable_schema <- function(dat, ...) {
  rlang::check_installed(c("reactable", "htmltools"))
  colDef <- reactable::colDef
  cols <- c(
    "tool",
    "tbl",
    "description",
    "ftype",
    "n_cols",
    "version_str",
    "glob",
    "col_names"
  )
  reactable::reactable(
    dplyr::select(dat, dplyr::all_of(cols)),
    searchable = TRUE,
    filterable = TRUE,
    pagination = FALSE,
    highlight = TRUE,
    striped = TRUE,
    # inherit page colours so it works in light and dark themes
    theme = reactable::reactableTheme(
      color = "inherit",
      backgroundColor = "transparent",
      stripedColor = "rgba(127, 127, 127, 0.06)",
      highlightColor = "rgba(127, 127, 127, 0.12)",
      inputStyle = list(backgroundColor = "transparent", color = "inherit")
    ),
    details = function(i) {
      schema_columns_detail(dat$columns[[i]], dat$versions[[i]], dat$glob[[i]])
    },
    columns = list(
      tool = colDef(name = "Tool", maxWidth = 100),
      tbl = colDef(name = "Table", maxWidth = 120, style = list(fontWeight = 600)),
      description = colDef(name = "Description", minWidth = 220),
      ftype = colDef(name = "ftype", maxWidth = 120),
      n_cols = colDef(
        name = "Cols (latest)",
        maxWidth = 90,
        align = "right",
        filterable = FALSE
      ),
      version_str = colDef(name = "Versions", minWidth = 120),
      # shown in the expanded row; hidden here to keep the table narrow
      glob = colDef(show = FALSE, searchable = TRUE),
      col_names = colDef(show = FALSE, searchable = TRUE)
    ),
    ...
  )
}

#' Column-level detail for one schema table
#'
#' @description
#' Internal helper for [reactable_schema()]: glob line plus a nested reactable
#' of the table's columns, with one `●` presence column per schema version.
#'
#' @param x tibble of columns (`raw`, `tidy`, `type`, `description`, and
#'   list-column `versions`).
#' @param versions character vector of sorted schema versions for the table.
#' @param glob glob string for the table.
#' @return An htmltools tag.
#' @keywords internal
schema_columns_detail <- function(x, versions, glob) {
  colDef <- reactable::colDef
  pres <- purrr::map(versions, \(v) {
    ifelse(purrr::map_lgl(x[["versions"]], \(vs) v %in% vs), "●", "")
  }) |>
    rlang::set_names(versions) |>
    tibble::as_tibble()
  d <- dplyr::bind_cols(dplyr::select(x, -"versions"), pres)
  vcols <- purrr::map(versions, \(v) colDef(align = "center", minWidth = 60)) |>
    rlang::set_names(versions)
  mono <- list(fontFamily = "monospace")
  htmltools::div(
    style = "padding: 8px 16px 16px 40px;",
    htmltools::div(
      style = "margin-bottom: 8px; font-size: 0.9em;",
      htmltools::strong("Glob: "),
      htmltools::code(glob)
    ),
    reactable::reactable(
      d,
      pagination = FALSE,
      compact = TRUE,
      bordered = TRUE,
      sortable = TRUE,
      columns = c(
        list(
          raw = colDef(minWidth = 110, style = mono),
          tidy = colDef(minWidth = 110, style = mono),
          type = colDef(maxWidth = 60),
          description = colDef(minWidth = 130)
        ),
        vcols
      )
    )
  )
}

#' Build schema data for reactable_schema
#'
#' @description
#' Internal helper: builds the nested data frame expected by [reactable_schema()]
#' for one or more tools from a given package, read straight from each tool's
#' `schema.yaml` tables.
#'
#' @param tools character vector of tool names.
#' @param pkg package name that owns the tool configs. Defaults to `"nemo"`.
#' @return A tibble with one row per (tool, table) and columns `tool`, `tbl`,
#'   `description`, `ftype`, `glob`, `columns` (nested tibble of `raw`, `tidy`,
#'   `type`, `description`, list-column `versions`), `versions` (sorted
#'   character vector), `n_cols` (columns in `latest`), `version_str` and
#'   `col_names` (space-separated raw + tidy names, for search).
#' @keywords internal
#' @testexamples
#' d <- nemo_schemavis_data("tool1", pkg = "nemo")
#' expect_s3_class(d, "tbl_df")
#' expect_true(all(c("tool", "tbl", "description", "ftype", "glob", "columns",
#'   "versions", "n_cols", "col_names") %in% names(d)))
#' expect_equal(d$n_cols[d$tbl == "table1"], 6L)
#' expect_true(grepl("sample_id", d$col_names[d$tbl == "table1"]))
nemo_schemavis_data <- function(tools, pkg = "nemo") {
  get_one <- function(tool) {
    tabs <- Config$new(tool, pkg = pkg)$get_tables()
    purrr::imap(tabs, \(tab, tbl) {
      columns <- purrr::map(tab[["columns"]], \(col) {
        tibble::tibble(
          raw = col[["raw"]],
          tidy = col[["tidy"]],
          type = col[["type"]],
          description = col[["description"]],
          versions = list(col[["versions"]])
        )
      }) |>
        dplyr::bind_rows()
      tibble::tibble(
        tool = tool,
        tbl = tbl,
        description = tab[["description"]],
        ftype = tab[["ftype"]],
        glob = paste(tab[["glob"]], collapse = ", "),
        columns = list(columns)
      )
    }) |>
      dplyr::bind_rows()
  }
  purrr::map(tools, get_one) |>
    dplyr::bind_rows() |>
    dplyr::mutate(
      versions = purrr::map(.data$columns, \(x) {
        config_sort_versions(unique(unlist(x[["versions"]])))
      }),
      n_cols = purrr::map_int(.data$columns, \(x) {
        sum(purrr::map_lgl(x[["versions"]], \(v) "latest" %in% v))
      }),
      version_str = purrr::map_chr(.data$versions, \(v) paste(v, collapse = ", ")),
      col_names = purrr::map_chr(.data$columns, \(x) {
        paste(unique(c(x[["raw"]], x[["tidy"]])), collapse = " ")
      })
    )
}

#' Render an interactive schema explorer
#'
#' @description
#' Builds schema data for one or more tools and renders it as an interactive
#' [reactable::reactable()] table with expandable per-table column details.
#'
#' @param tools character vector of tool names.
#' @param pkg package name that owns the tool configs. Defaults to `"nemo"`.
#' @param ... additional arguments passed to [reactable::reactable()].
#' @return An htmlwidget.
#' @examples
#' \dontrun{
#' nemo_schema_reactable("tool1", pkg = "nemo")
#' }
#' @export
nemo_schema_reactable <- function(tools, pkg = "nemo", ...) {
  reactable_schema(nemo_schemavis_data(tools, pkg = pkg), ...)
}
