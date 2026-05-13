.onLoad <- function(libname, pkgname) {
  if (Sys.getenv("NEMO_LOG_ENABLE", "TRUE") == "TRUE") {
    level <- Sys.getenv("NEMO_LOG_LEVEL", "INFO")
    assign(
      "logger",
      log4r::logger(
        threshold = level,
        appenders = log4r::console_appender(nemo_log_layout)
      ),
      envir = parent.env(environment())
    )
  }
}

#' Log a message with a specified level
#' @param level The log level ("DEBUG", "INFO", "WARN", "ERROR", "FATAL").
#' @param msg The message to log. Use [sprintf] formatting.
#' @param ... Values to format into the message. See [sprintf] for details.
#' @export
nemo_log <- function(level, msg, ...) {
  if (
    Sys.getenv("NEMO_LOG_ENABLE", "TRUE") == "TRUE" &&
      exists("logger", envir = parent.env(environment()))
  ) {
    logger <- get("logger", envir = parent.env(environment()))
    log4r::levellog(logger, level, sprintf(msg, ...))
  }
}

nemo_log_layout <- function(level, ...) {
  paste0(nemo_log_date(), " nemo ", level, ": ", ..., "\n", collapse = "")
}

#' Print current timestamp for logging
#'
#' @return Current timestamp as character.
#' @export
nemo_log_date <- function() {
  paste0('[', format(Sys.time(), "%Y-%m-%dT%H:%M:%S%Z"), ']')
}
