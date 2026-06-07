#' Render a reactable schema table
#'
#' @description
#' Renders an interactive [reactable::reactable()] displaying per-table schemas
#' with expandable version buttons. The input data frame must contain columns
#' `n`, `tool`, `tbl`, `description`, `row_id`, and a nested list-column
#' `schema_version` (with sub-columns `version` and `schema`).
#'
#' This is a low-level function; most callers should use [nemo_schema_reactable()]
#' instead.
#'
#' @param dat data frame as produced by [nemo_schema_reactable()] internals.
#' @param ... additional arguments passed to [reactable::reactable()].
#' @return An htmlwidget.
#' @examples
#' \dontrun{
#' d <- nemo_schemavis_data("tool1", pkg = "nemo")
#' reactable_schema(d)
#' }
#' @export
reactable_schema <- function(dat, ...) {
  rlang::check_installed(c("reactable", "htmltools"))
  js_code <- "
  function toggleSchema(rowId, versionIndex) {
    var schemaId = 'schema_' + rowId + '_' + versionIndex;
    var buttonId = 'btn_' + rowId + '_' + versionIndex;
    var schemaDiv = document.getElementById(schemaId);
    var button = document.getElementById(buttonId);

    if (schemaDiv && button) {
      if (schemaDiv.style.display === 'none' || schemaDiv.style.display === '') {
        schemaDiv.style.display = 'block';
        button.style.backgroundColor = '#1565c0';
        button.style.color = 'white';
        button.style.borderColor = '#0d47a1';
        button.style.transform = 'scale(0.98)';
      } else {
        schemaDiv.style.display = 'none';
        button.style.backgroundColor = '#e3f2fd';
        button.style.color = '#1565c0';
        button.style.borderColor = '#90caf9';
        button.style.transform = 'scale(1)';
      }
    }
  }
  "

  htmltools::tags$div(
    htmltools::tags$script(htmltools::HTML(js_code)),
    reactable::reactable(
      dat,
      sortable = TRUE,
      searchable = TRUE,
      pagination = FALSE,
      filterable = TRUE,
      striped = TRUE,
      highlight = TRUE,
      bordered = TRUE,
      theme = reactable::reactableTheme(
        borderColor = "#dfe2e5",
        stripedColor = "#f8f9fa",
        highlightColor = "#f0f5ff",
        cellPadding = "12px 15px"
      ),
      columns = list(
        n = reactable::colDef(maxWidth = 70),
        row_id = reactable::colDef(show = FALSE),
        schema_version = reactable::colDef(
          minWidth = 130,
          name = "schema",
          html = TRUE,
          cell = function(value, index) {
            row_id <- dat$row_id[[index]]
            versions <- value$version

            version_buttons <- purrr::map_chr(
              seq_along(versions),
              function(i) {
                v <- versions[[i]]
                button_id <- glue("btn_{row_id}_{i - 1}")
                paste0(
                  glue('<button id="{button_id}" onclick="toggleSchema({row_id}, {i - 1})" '),
                  'style="',
                  'background-color: #e3f2fd; ',
                  'border: 1px solid #90caf9; ',
                  'border-radius: 16px; ',
                  'padding: 6px 14px; ',
                  'margin: 3px; ',
                  'font-size: 12px; ',
                  'cursor: pointer; ',
                  'color: #1565c0; ',
                  'font-weight: 500; ',
                  'transition: all 0.2s ease;',
                  'user-select: none;',
                  '" onmouseover="if(this.style.backgroundColor !== \'rgb(21, 101, 192)\') this.style.backgroundColor=\'#bbdefb\'" ',
                  'onmouseout="if(this.style.backgroundColor !== \'rgb(21, 101, 192)\') this.style.backgroundColor=\'#e3f2fd\'">',
                  v,
                  '</button>'
                )
              }
            )

            schema_divs <- purrr::map_chr(seq_along(versions), function(i) {
              schema_data <- value$schema[[i]]
              schema_id <- glue("schema_{row_id}_{i - 1}")

              if (is.data.frame(schema_data)) {
                schema_html <- paste0(
                  '<div style="margin-top: 10px; padding: 10px; border: 1px solid #ddd; border-radius: 6px; background-color: #fafafa;">',
                  '<div style="font-weight: 600; margin-bottom: 8px; color: #333;">Version: ',
                  versions[[i]],
                  '</div>',
                  '<div style="font-size: 12px; color: #666; margin-bottom: 10px;">',
                  nrow(schema_data),
                  ' rows \u00d7 ',
                  ncol(schema_data),
                  ' columns</div>',
                  '<div style="overflow-x: auto; max-height: 300px;">',
                  '<table style="width: 100%; border-collapse: collapse; font-size: 12px;">',
                  '<thead>',
                  paste0(
                    '<th style="border: 1px solid #ddd; padding: 6px; background-color: #f5f5f5; text-align: left;">',
                    names(schema_data),
                    '</th>',
                    collapse = ""
                  ),
                  '</thead>',
                  '<tbody>',
                  paste(
                    apply(schema_data, 1, function(row) {
                      paste0(
                        '<tr>',
                        paste0(
                          '<td style="border: 1px solid #ddd; padding: 6px;">',
                          as.character(row),
                          '</td>',
                          collapse = ""
                        ),
                        '</tr>'
                      )
                    }),
                    collapse = ""
                  ),
                  '</tbody>',
                  '</table>',
                  '</div>',
                  '</div>'
                )
              } else {
                schema_html <- paste0(
                  '<div style="margin-top: 10px; padding: 10px; border: 1px solid #ddd; border-radius: 6px;">',
                  '<div style="font-weight: 600; margin-bottom: 8px;">Version: ',
                  versions[[i]],
                  '</div>',
                  '<div style="color: #999; font-style: italic;">No schema available</div>',
                  '</div>'
                )
              }
              glue('<div id="{schema_id}" style="display: none;">{schema_html}</div>')
            })

            htmltools::HTML(
              paste0(
                '<div>',
                paste(version_buttons, collapse = ""),
                paste(schema_divs, collapse = ""),
                '</div>'
              )
            )
          }
        )
      ),
      ...
    )
  )
}

#' Build schema data for reactable_schema
#'
#' @description
#' Internal helper: builds the nested data frame expected by [reactable_schema()]
#' for one or more tools from a given package.
#'
#' @param tools character vector of tool names.
#' @param pkg package name that owns the tool configs. Defaults to `"nemo"`.
#' @return A tibble with columns `n`, `tool`, `tbl`, `schema_version`,
#'   `description`, `row_id`.
#' @keywords internal
#' @testexamples
#' expect_s3_class(nemo_schemavis_data("tool1", pkg = "nemo"), "tbl_df")
#' expect_true(all(c("n", "tool", "tbl", "schema_version", "description") %in%
#'   names(nemo_schemavis_data("tool1", pkg = "nemo"))))
nemo_schemavis_data <- function(tools, pkg = "nemo") {
  get_one <- function(tool) {
    conf <- Config$new(tool, pkg = pkg)
    conf$get_schemas_both() |>
      dplyr::select(tbl = "name", description = "tbl_description", "version", "schema") |>
      tidyr::nest(schema_version = c("version", "schema")) |>
      dplyr::mutate(tool = toupper(tool))
  }
  purrr::map(tools, get_one) |>
    dplyr::bind_rows() |>
    dplyr::mutate(row_id = dplyr::row_number(), n = .data$row_id) |>
    dplyr::relocate("n") |>
    dplyr::relocate("tool", .after = "n") |>
    dplyr::relocate("schema_version", .after = "tbl")
}

#' Render an interactive schema explorer
#'
#' @description
#' Builds schema data for one or more tools and renders it as an interactive
#' [reactable::reactable()] table with expandable per-version column details.
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
