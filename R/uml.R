#' Generate UML diagram for nemo R6 classes
#'
#' @description
#' Uses `R6toPlant` to generate a PlantUML file from a set of R6 classes,
#' then calls `plantuml` to render it as an SVG.
#'
#' When `out_dir` is `NULL` (default), the SVG is piped from `plantuml` to
#' stdout and returned as a character string — suitable for inline rendering
#' in a vignette chunk with `output: asis`. When `out_dir` is provided, the
#' `.uml` and `.svg` files are written to that directory instead.
#'
#' @param classes (`character(n)`)\cr
#' Names of R6 classes to include in the diagram.
#' @param out_dir (`character(1)` or `NULL`)\cr
#' Output directory for the `.uml` and `.svg` files. If `NULL`, returns the
#' SVG as a string.
#' @param pkg (`character(1)`)\cr
#' Package namespace to look up class objects from.
#'
#' @return When `out_dir` is `NULL`, a character string containing the SVG.
#' Otherwise, the path to the `.uml` file (invisibly).
#'
#' @examples
#' \dontrun{
#' # inline SVG for vignette use
#' svg <- nemo_uml(c("Config", "Tool", "Tool1", "Workflow", "Workflow1"))
#'
#' # write files to disk
#' nemo_uml(
#'   classes = c("Config", "Tool", "Tool1", "Workflow", "Workflow1"),
#'   out_dir = here::here("vignettes", "fig", "uml")
#' )
#' }
#' @export
nemo_uml <- function(classes, out_dir = NULL, pkg = "nemo") {
  stopifnot(pkg_found("R6toPlant"))
  ns <- asNamespace(pkg)
  classes_as_fun <- classes |> purrr::map(\(x) get(x, envir = ns))
  tmp_uml <- tempfile(fileext = ".uml")
  R6toPlant::make_plant(classes = classes_as_fun, output = tmp_uml)
  if (is.null(out_dir)) {
    svg1 <- system2("plantuml", args = c("-tsvg", "-pipe"), stdin = tmp_uml, stdout = TRUE)
    return(paste(svg1, collapse = "\n"))
  }
  fs::dir_create(out_dir)
  out_uml <- file.path(out_dir, paste0(pkg, ".uml"))
  file.copy(tmp_uml, out_uml, overwrite = TRUE)
  system2("plantuml", args = c("-tsvg", out_uml))
  invisible(out_uml)
}
