# Log a message with a specified level

Log a message with a specified level

## Usage

``` r
nemo_log(level, msg, ...)
```

## Arguments

- level:

  The log level ("DEBUG", "INFO", "WARN", "ERROR", "FATAL").

- msg:

  The message to log. Use [sprintf](https://rdrr.io/r/base/sprintf.html)
  formatting.

- ...:

  Values to format into the message. See
  [sprintf](https://rdrr.io/r/base/sprintf.html) for details.
