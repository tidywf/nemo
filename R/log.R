nemo_log_enabled <- function() {
  Sys.getenv("NEMO_LOG_ENABLE", "TRUE") == "TRUE"
}

.nemo_env <- new.env(parent = emptyenv())

.onLoad <- function(libname, pkgname) {
  if (nemo_log_enabled()) {
    level <- Sys.getenv("NEMO_LOG_LEVEL", "INFO")
    .nemo_env$logger <- log4r::logger(
      threshold = level,
      appenders = log4r::console_appender(nemo_log_layout)
    )
  }
}

#' Log a message with a specified level
#' @param level The log level ("DEBUG", "INFO", "WARN", "ERROR", "FATAL").
#' @param msg The message to log. Use [sprintf] formatting.
#' @param ... Values to format into the message. See [sprintf] for details.
#' @export
nemo_log <- function(level, msg, ...) {
  if (nemo_log_enabled() && !is.null(.nemo_env$logger)) {
    log4r::levellog(.nemo_env$logger, level, sprintf(msg, ...))
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
