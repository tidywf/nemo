#' Generate UML diagram for nemo R6 classes
#'
#' @description
#' Uses `R6toPlant` to generate a PlantUML file from a set of R6 classes,
#' then calls `plantuml` to render it as an SVG.
#'
#' @param classes (`character(n)`)\cr
#' Names of R6 classes to include in the diagram.
#' @param out_dir (`character(1)`)\cr
#' Output directory for the `.uml` and `.svg` files.
#' @param pkg (`character(1)`)\cr
#' Package namespace to look up class objects from.
#'
#' @examples
#' \dontrun{
#' nemo_uml(
#'   classes = c("Config", "Tool", "Tool1", "Workflow", "Workflow1"),
#'   out_dir = here::here("vignettes", "fig", "uml")
#' )
#' }
#' @export
nemo_uml <- function(classes, out_dir, pkg = "nemo") {
  rlang::check_installed("R6toPlant")
  ns <- asNamespace(pkg)
  x_as_fun <- purrr::map(classes, get, envir = ns)
  out_uml <- file.path(out_dir, paste0(pkg, ".uml"))
  fs::dir_create(out_dir)
  R6toPlant::make_plant(classes = x_as_fun, output = out_uml)
  system2("plantuml", args = c("-tsvg", out_uml))
  invisible(out_uml)
}
