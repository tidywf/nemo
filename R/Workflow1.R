#' @title Workflow1 Object
#'
#' @description
#' Pre-configured `Workflow` bundling `Tool1`.
#'
#' @examples
#' path <- system.file("extdata/tool1", package = "nemo")
#' wf <- Workflow1$new(path)
#' (lf_all <- wf$list_files())
#' dir1 <- tempdir()
#' wf$nemofy(diro = dir1, format = "parquet", input_id = "run1")
#' (lf <- list.files(dir1, pattern = "tool1.*parquet", full.names = TRUE))
#' @testexamples
#' # initialize
#' expect_equal(length(wf$tools), 1)
#' expect_equal(wf$tools[[1]]$name, "tool1")
#' # list_files
#' expect_equal(nrow(lf_all), 6)
#' # nemofy
#' expect_equal(length(lf), 6)
#' @export
Workflow1 <- R6::R6Class(
  "Workflow1",
  inherit = Workflow,
  public = list(
    #' @description Create a new Workflow1 object.
    #' @param path (`character(n)`)\cr
    #' Path(s) to Workflow1 results.
    #' @return (`R6::R6Class()`)\cr
    #' R6 object.
    initialize = function(path = NULL) {
      tools <- list(
        tool1 = Tool1
      )
      super$initialize(name = "Workflow1", path = path, tools = tools)
    }
  ) # public end
)
