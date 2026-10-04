#' Render a reactable schema table
#'
#' @description
#' Renders an interactive [reactable::reactable()] with one row per table.
#' Global search also matches ftypes and raw/tidy column names (via hidden
#' searchable columns). Click a row to expand it and see the table's ftype and
#' its columns, with one column per schema version marking where each column
#' is present.
#'
#' The widget carries its own CSS: on a pkgdown/Quarto page it hides the
#' sidebar and breaks out of the content column to (almost) the full viewport
#' width, so child packages get the same layout without extra SCSS.
#'
#' This is a low-level function; most callers should use [nemo_schema_reactable()]
#' instead.
#'
#' @param dat data frame as produced by [nemo_schemavis_data()].
#' @param tool_colours named character vector of CSS colours, keyed by tool
#'   name, used for the tool pills (child packages supply their own, e.g.
#'   `tidywigits::WIGITS_TOOL_COLOURS`). Tools not listed, or all tools when
#'   `NULL`, fall back to grey.
#' @param ... additional arguments passed to [reactable::reactable()].
#' @return An htmlwidget.
#' @examples
#' \dontrun{
#' dat <- nemo_schemavis_data("tool1", pkg = "nemo")
#' reactable_schema(dat)
#' reactable_schema(dat, tool_colours = c(tool1 = "tomato"))
#' }
#' @export
reactable_schema <- function(dat, tool_colours = NULL, ...) {
  rlang::check_installed(c("reactable", "htmltools", "htmlwidgets"))
  colDef <- reactable::colDef
  cols <- c(
    "tool",
    "tbl",
    "description",
    "glob",
    "n_cols",
    "version_str",
    "ftype",
    "col_names"
  )
  tools <- unique(dat$tool)
  if (is.null(tool_colours)) {
    tool_colours <- character()
  }
  tool_cols <- rlang::set_names(as.character(tool_colours[tools]), tools)
  tool_cols[is.na(tool_cols)] <- "#868e96"
  w <- reactable::reactable(
    dplyr::select(dat, dplyr::all_of(cols)),
    class = "nemo-schema",
    searchable = TRUE,
    filterable = TRUE,
    pagination = FALSE,
    highlight = TRUE,
    striped = TRUE,
    onClick = "expand",
    rowStyle = list(cursor = "pointer"),
    # inherit page colours so it works in light and dark themes
    theme = reactable::reactableTheme(
      color = "inherit",
      backgroundColor = "transparent",
      borderColor = "rgba(127, 127, 127, 0.25)",
      stripedColor = "rgba(127, 127, 127, 0.06)",
      highlightColor = "rgba(52, 89, 230, 0.10)",
      headerStyle = list(
        backgroundColor = "rgba(52, 89, 230, 0.10)",
        borderBottom = "2px solid rgba(52, 89, 230, 0.6)"
      ),
      inputStyle = list(backgroundColor = "transparent", color = "inherit")
    ),
    details = function(i) {
      schema_columns_detail(dat$columns[[i]], dat$versions[[i]], dat$ftype[[i]])
    },
    columns = list(
      .details = colDef(name = "", width = 36),
      tool = colDef(
        name = "Tool",
        width = schema_col_width(tools, extra = 40),
        cell = function(value) {
          schema_pill(value, colour = tool_cols[[value]], weight = 500)
        }
      ),
      tbl = colDef(
        name = "Table",
        width = schema_col_width(dat$tbl, extra = 24),
        style = list(fontWeight = 600, fontFamily = schema_mono())
      ),
      description = colDef(name = "Description", minWidth = 260),
      glob = colDef(
        name = "Glob",
        minWidth = 200,
        cell = function(value) htmltools::code(value)
      ),
      n_cols = colDef(
        name = "Cols (latest)",
        maxWidth = 100,
        align = "right",
        filterable = FALSE
      ),
      version_str = colDef(
        name = "Versions",
        minWidth = 140,
        cell = function(value) {
          vs <- strsplit(value, ", ", fixed = TRUE)[[1]]
          htmltools::tagList(purrr::map(vs, schema_version_pill))
        }
      ),
      # shown in the expanded row; hidden here to keep the table narrow
      ftype = colDef(show = FALSE, searchable = TRUE),
      col_names = colDef(show = FALSE, searchable = TRUE)
    ),
    ...
  )
  htmlwidgets::prependContent(w, htmltools::tags$style(schema_css()))
}

#' Column-level detail for one schema table
#'
#' @description
#' Internal helper for [reactable_schema()]: ftype line plus a nested reactable
#' of the table's columns, with one `●` presence column per schema version.
#'
#' @param x tibble of columns (`raw`, `tidy`, `type`, `description`, and
#'   list-column `versions`).
#' @param versions character vector of sorted schema versions for the table.
#' @param ftype ftype string for the table.
#' @return An htmltools tag.
#' @keywords internal
schema_columns_detail <- function(x, versions, ftype) {
  colDef <- reactable::colDef
  pres <- purrr::map(versions, \(v) {
    ifelse(purrr::map_lgl(x[["versions"]], \(vs) v %in% vs), "●", "")
  }) |>
    rlang::set_names(versions) |>
    tibble::as_tibble()
  d <- dplyr::bind_cols(dplyr::select(x, -"versions"), pres)
  vcols <- purrr::map(versions, \(v) {
    colDef(
      header = schema_version_pill(v),
      align = "center",
      minWidth = 70,
      style = list(color = schema_version_colour(v))
    )
  }) |>
    rlang::set_names(versions)
  mono <- list(fontFamily = schema_mono())
  htmltools::div(
    style = paste(
      "padding: 8px 16px 16px 40px;",
      "border-left: 3px solid rgba(52, 89, 230, 0.6);",
      "background: rgba(52, 89, 230, 0.03);"
    ),
    htmltools::div(
      style = "margin-bottom: 8px; font-size: 0.9em;",
      htmltools::strong("ftype: "),
      htmltools::code(ftype)
    ),
    reactable::reactable(
      d,
      pagination = FALSE,
      compact = TRUE,
      bordered = TRUE,
      sortable = TRUE,
      theme = reactable::reactableTheme(
        color = "inherit",
        backgroundColor = "transparent",
        borderColor = "rgba(127, 127, 127, 0.25)",
        headerStyle = list(backgroundColor = "rgba(127, 127, 127, 0.10)")
      ),
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

#' Pill-shaped label
#'
#' @param x label text.
#' @param colour CSS colour: used as-is for the border, at 30% opacity for the
#'   background.
#' @param weight font weight.
#' @return An htmltools span.
#' @keywords internal
schema_pill <- function(x, colour, weight = 400) {
  htmltools::span(
    style = sprintf(
      paste(
        "display: inline-block; padding: 0 8px; margin: 1px 2px;",
        "border-radius: 10px; white-space: nowrap;",
        "border: 1px solid %s;",
        "background: color-mix(in srgb, %s 30%%, transparent);",
        "font-weight: %s;"
      ),
      colour,
      colour,
      weight
    ),
    x
  )
}

#' Version pill: `latest` green, others grey
#'
#' @param v version string.
#' @return An htmltools span.
#' @keywords internal
schema_version_pill <- function(v) {
  schema_pill(v, colour = schema_version_colour(v))
}

#' Version colour
#'
#' @param v version string.
#' @return A CSS colour string.
#' @keywords internal
schema_version_colour <- function(v) {
  if (v == "latest") {
    return("#198754")
  }
  "#868e96"
}

#' Column width from its longest value
#'
#' @param x character vector of cell values.
#' @param extra extra pixels for padding and decoration.
#' @return Width in pixels (13px font, ~8px per character).
#' @keywords internal
schema_col_width <- function(x, extra = 0) {
  max(nchar(x), 4) * 8 + extra
}

#' CSS shipped with the schema widget
#'
#' @description
#' Hides the pkgdown sidebar on the page and lets the table break out of the
#' content column to the viewport width (minus a gutter), centred.
#'
#' @return CSS string.
#' @keywords internal
schema_css <- function() {
  paste0(
    "
main:has(.nemo-schema) { flex: 0 0 100%; max-width: 100%; }
main:has(.nemo-schema) ~ aside { display: none; }
.nemo-schema {
  width: calc(100vw - 64px);
  position: relative;
  left: 50%;
  transform: translateX(-50%);
  font-size: 13px;
}
.nemo-schema .rt-expander:after { border-top-color: #3459e6; }
.nemo-schema code { font-family: ",
    schema_mono(),
    "; }
"
  )
}

#' Monospace font stack for identifiers in the schema widget
#'
#' @return CSS font-family string.
#' @keywords internal
schema_mono <- function() {
  "ui-monospace, SFMono-Regular, Menlo, Consolas, 'Liberation Mono', monospace"
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
#' @param ... additional arguments passed to [reactable_schema()] (e.g.
#'   `tool_colours`) and on to [reactable::reactable()].
#' @return An htmlwidget.
#' @examples
#' \dontrun{
#' nemo_schema_reactable("tool1", pkg = "nemo")
#' }
#' @export
nemo_schema_reactable <- function(tools, pkg = "nemo", ...) {
  reactable_schema(nemo_schemavis_data(tools, pkg = pkg), ...)
}
