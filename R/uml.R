#' Generate UML diagram for nemo R6 classes
#'
#' @description
#' Uses `R6toPlant` to generate a PlantUML file from a set of R6 classes,
#' then calls `plantuml` to render it as an SVG.
#'
#' When `output_dir` is `NULL` (default), the SVG is piped from `plantuml` to
#' stdout and returned as a character string — suitable for inline rendering
#' in a vignette chunk with `output: asis`. When `output_dir` is provided, the
#' `.uml` and `.svg` files are written to that directory instead.
#'
#' @param classes (`character(n)`)\cr
#' Names of R6 classes to include in the diagram.
#' @param output_dir (`character(1)` or `NULL`)\cr
#' Output directory for the `.uml` and `.svg` files. If `NULL`, returns the
#' SVG as a string.
#' @param pkg (`character(1)`)\cr
#' Package namespace to look up class objects from.
#'
#' @return When `output_dir` is `NULL`, a character string containing the SVG.
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
#'   output_dir = here::here("vignettes", "fig", "uml")
#' )
#' }
#' @export
nemo_uml <- function(classes, output_dir = NULL, pkg = "nemo") {
  if (!pkg_found("R6toPlant")) {
    stop("Install R6toPlant from gitlab::b-rowlingson/R6toPlant", call. = FALSE)
  }
  if (!nzchar(Sys.which("plantuml"))) {
    stop("plantuml binary not found. Install it via conda: 'conda install conda-forge::plantuml'.")
  }
  ns <- asNamespace(pkg)
  classes_as_fun <- classes |> purrr::map(\(x) get(x, envir = ns))
  tmp_uml <- tempfile(fileext = ".uml")
  R6toPlant::make_plant(classes = classes_as_fun, output = tmp_uml)
  if (is.null(output_dir)) {
    svg1 <- system2(
      "plantuml",
      args = c("-tsvg", "-pipe"),
      stdin = tmp_uml,
      stdout = TRUE,
      stderr = TRUE
    )
    if (!is.null(attr(svg1, "status")) && attr(svg1, "status") != 0L) {
      stop("plantuml failed (exit ", attr(svg1, "status"), "):\n", paste(svg1, collapse = "\n"))
    }
    return(paste(svg1, collapse = "\n"))
  }
  fs::dir_create(output_dir)
  out_uml <- file.path(output_dir, paste0(pkg, ".uml"))
  file.copy(tmp_uml, out_uml, overwrite = TRUE)
  status <- system2("plantuml", args = c("-tsvg", out_uml))
  if (status != 0L) {
    stop("plantuml failed (exit ", status, ").")
  }
  invisible(out_uml)
}
