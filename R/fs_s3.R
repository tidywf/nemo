#' List Objects in AWS S3 Directory
#'
#' Returns some or all (up to 1,000) of the objects in an S3 directory.
#'
#' @param s3dir S3 directory.
#' @param max_objects Maximum objects returned.
#'
#'
#' @return A tibble with object basename, size, last modified timestamp, and
#' full S3 path.
#' @examples
#' \dontrun{
#' p1 <- "s3://project-data-889522050439-ap-southeast-2/byob-icav2"
#' p2 <- "project-wgs-accreditation/analysis/oncoanalyser-wgts-dna"
#' p3 <- "20250910013ce65a/L2100216__L2100215"
#' s3dir <- file.path(p1, p2, p3)
#' s3_list_files_dir(s3dir, max_objects = 15)
#' }
#' @export
s3_list_files_dir <- function(s3dir, max_objects = 1000) {
  stopifnot(grepl("^s3://", s3dir))
  bucket <- sub("s3://(.*?)/.*", "\\1", s3dir)
  prefix <- sub("s3://(.*?)/(.*)", "\\2", s3dir)
  s3 <- paws.storage::s3()
  l <- s3$list_objects_v2(
    Bucket = bucket,
    Prefix = prefix,
    MaxKeys = max_objects
  )
  stopifnot(all(c("Contents", "KeyCount") %in% names(l)))
  cols_sel <- c("bname", "size", "lastmodified", "path")
  # handle no results
  if (l[["KeyCount"]] == 0) {
    return(empty_tbl(cnames = cols_sel, ctypes = "cccc"))
  }
  d <- l[["Contents"]] |>
    purrr::map(
      \(x) {
        tibble::tibble(
          Key = x[["Key"]],
          Size = x[["Size"]],
          lastmodified = as.character(x[["LastModified"]])
        )
      }
    ) |>
    dplyr::bind_rows() |>
    dplyr::mutate(
      path = paste0("s3://", bucket, "/", .data$Key),
      bname = basename(.data$path),
      size = fs::as_fs_bytes(.data$Size)
    ) |>
    dplyr::select(dplyr::all_of(cols_sel))
  return(d)
}

#' S3 Generate Presigned URL
#'
#' @param client S3 client. Make sure you use `signature_version = "s3v4"` (see example).
#' @param s3path Full path to S3 object.
#' @param expiry_seconds Number of seconds the presigned URL is valid for (3600 = 1 hour).
#'
#' @return An S3 presigned URL.
#' @examples
#' \dontrun{
#' client <- paws.storage::s3(paws.storage::config(signature_version = "s3v4"))
#' s3path <- "s3://bucket1/path/to/file.tsv"
#' s3_file_presignedurl(client, s3path)
#' }
#'
#' @export
s3_file_presignedurl <- function(client, s3path, expiry_seconds = 604800) {
  bucket <- sub("s3://(.*?)/.*", "\\1", s3path)
  prefix <- sub("s3://(.*?)/(.*)", "\\2", s3path)
  client$generate_presigned_url(
    client_method = "get_object",
    params = list(Bucket = bucket, Key = prefix),
    expires_in = expiry_seconds
  )
}
