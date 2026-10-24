nemo_log_enabled <- function() {
  Sys.getenv("NEMO_LOG_ENABLE", "TRUE") == "TRUE"
}

.nemo_env <- new.env(parent = emptyenv())

nemo_log_levels <- c("DEBUG", "INFO", "WARN", "ERROR", "FATAL")

# NEMO_LOG_LEVEL, case-insensitive; falls back to INFO (with a warning) rather
# than letting log4r error on an unknown level.
nemo_log_level <- function() {
  level <- toupper(Sys.getenv("NEMO_LOG_LEVEL", "INFO"))
  if (!level %in% nemo_log_levels) {
    # warn once per bad value, not on every log call
    if (!identical(.nemo_env$warned_level, level)) {
      warning(
        glue(
          "Invalid NEMO_LOG_LEVEL '{level}', using INFO. ",
          "Valid: {glue::glue_collapse(nemo_log_levels, sep = ', ')}."
        ),
        call. = FALSE
      )
      .nemo_env$warned_level <- level
    }
    level <- "INFO"
  }
  level
}

# Created lazily and rebuilt when NEMO_LOG_LEVEL changes, so env vars set after
# the package is loaded still take effect.
nemo_logger <- function() {
  level <- nemo_log_level()
  if (is.null(.nemo_env$logger) || !identical(.nemo_env$level, level)) {
    .nemo_env$logger <- log4r::logger(
      threshold = level,
      appenders = log4r::console_appender(nemo_log_layout)
    )
    .nemo_env$level <- level
  }
  .nemo_env$logger
}

#' Log a message with a specified level
#'
#' Controlled by env vars `NEMO_LOG_ENABLE` (`"FALSE"` disables) and
#' `NEMO_LOG_LEVEL` (`DEBUG`, `INFO` (default), `WARN`, `ERROR`, `FATAL`;
#' case-insensitive), both read at call time.
#' @param level The log level ("DEBUG", "INFO", "WARN", "ERROR", "FATAL").
#' @param msg The message to log. Use [sprintf] formatting.
#' @param ... Values to format into the message. See [sprintf] for details.
#' @examples
#' nemo_log("INFO", "Tidying %s", "dir1")
#' @testexamples
#' withr::with_envvar(c(NEMO_LOG_ENABLE = "TRUE", NEMO_LOG_LEVEL = "debug"), {
#'   expect_output(nemo_log("DEBUG", "hi %d", 1L), "nemo DEBUG: hi 1")
#' })
#' withr::with_envvar(c(NEMO_LOG_ENABLE = "TRUE", NEMO_LOG_LEVEL = "WARN"), {
#'   expect_silent(nemo_log("INFO", "hidden"))
#' })
#' withr::with_envvar(c(NEMO_LOG_ENABLE = "TRUE", NEMO_LOG_LEVEL = "bogus"), {
#'   expect_warning(nemo_log("INFO", "x"), "Invalid NEMO_LOG_LEVEL")
#'   expect_no_warning(nemo_log("INFO", "x"))
#' })
#' withr::with_envvar(c(NEMO_LOG_ENABLE = "FALSE"), {
#'   expect_silent(nemo_log("INFO", "hidden"))
#' })
#' @export
nemo_log <- function(level, msg, ...) {
  if (nemo_log_enabled()) {
    log4r::levellog(nemo_logger(), level, sprintf(msg, ...))
  }
}

#' @keywords internal
nemo_log_layout <- function(level, ...) {
  paste0(nemo_log_date(), " nemo ", level, ": ", ..., "\n")
}

#' Print current timestamp for logging
#'
#' @return Current timestamp as character.
#' @export
nemo_log_date <- function() {
  paste0('[', format(Sys.time(), "%Y-%m-%dT%H:%M:%S%Z"), ']')
}
