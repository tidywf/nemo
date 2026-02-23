#' Generate Mermaid ER Diagram from a LinkML Schema
#'
#' Reads a LinkML `schema.yaml` file and returns a Mermaid ER diagram string
#' that can be embedded in a Quarto document via a `{mermaid}` fenced block.
#' All schema versions are merged into a single view, where version-specific fields
#' are not distinguished.
#'
#' @param path (`character(1)`)\cr
#' Path to a LinkML `schema.yaml` file.
#'
#' @return A single character string containing a Mermaid `erDiagram` block.
#'
#' @examples
#' p <- system.file("config/tools/tool1/schema.yaml", package = "nemo")
#' cat(schema_to_mermaid(p))
#'
#' @export
schema_to_mermaid <- function(path) {
  schema <- yaml::read_yaml(path)
  classes <- schema$classes
  default_range <- schema$default_range %||% "string"

  lines <- "erDiagram"
  for (cls_name in names(classes)) {
    cls <- classes[[cls_name]]
    attrs <- cls$attributes %||% list()
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
