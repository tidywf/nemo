#' Generate Mermaid ER Diagram from a LinkML Schema
#'
#' Reads a LinkML `schema.yaml` file and returns a Mermaid ER diagram string
#' that can be embedded in a Quarto document via a `{mermaid}` fenced block.
#' When `version` is `NULL`, all schema versions are merged into a single view.
#' When `version` is specified, only attributes belonging to that version are shown.
#'
#' @param path (`character(1)`)\cr
#' Path to a LinkML `schema.yaml` file.
#' @param version (`character(1)` or `NULL`)\cr
#' Version subset name (e.g. `"v4.0"`, `"latest"`). When `NULL`, all attributes
#' are included regardless of version.
#'
#' @return A single character string containing a Mermaid `erDiagram` block.
#'
#' @examples
#' p <- system.file("config/tools/tool1/schema.yaml", package = "nemo")
#' cat(schema_to_mermaid(p))
#'
#' @export
schema_to_mermaid <- function(path, version = NULL) {
  schema <- yaml::read_yaml(path)
  classes <- schema$classes
  default_range <- schema$default_range %||% "string"

  lines <- "erDiagram"
  for (cls_name in names(classes)) {
    cls <- classes[[cls_name]]
    attrs <- if (!is.null(version)) {
      linkml_slots_for_version(cls, version)
    } else {
      cls$attributes %||% list()
    }
    if (length(attrs) == 0) {
      next
    }
    lines <- c(lines, paste0(cls_name, " {"))
    for (attr_name in names(attrs)) {
      range <- attrs[[attr_name]]$range %||% default_range
      # sanitise field names
      attr_clean <- gsub("[^[:alnum:]_]", "_", attr_name)
      lines <- c(lines, paste0("    ", range, " ", attr_clean))
    }
    lines <- c(lines, "}")
  }
  paste(lines, collapse = "\n")
}

#' Get Version Subsets from a LinkML Schema
#'
#' Reads a LinkML `schema.yaml` file and returns the names of version subsets,
#' i.e. all subsets excluding the `raw` and `tidy` meta-subsets.
#'
#' @param path (`character(1)`)\cr
#' Path to LinkML `schema.yaml` file.
#'
#' @return Character vector of version subset names, or `character(0)` if none.
#'
#' @examples
#' p <- system.file("config/tools/tool1/schema.yaml", package = "nemo")
#' schema_versions(p)
#'
#' @export
schema_versions <- function(path) {
  schema <- yaml::read_yaml(path)
  all_subsets <- names(schema$subsets %||% list())
  all_subsets[!all_subsets %in% c("raw", "tidy")]
}
