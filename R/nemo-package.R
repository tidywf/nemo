#' @importFrom glue glue
#' @importFrom rlang .data !!! %||%
#' @importFrom R6 R6Class
#' @keywords internal
"_PACKAGE"

#' @noRd
dummy1 <- function() {
  # Solves R CMD check: Namespaces in Imports field not imported from
  arrow::write_parquet
  ulid::ulid
}
