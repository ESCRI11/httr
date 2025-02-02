#' Create a webserver to listen for OAuth callback.
#'
#' This opens a web browser pointing to `request_url`, and opens a
#' webserver on port 1410 to listen to the reponse.  The redirect url should
#' either be set previously (during the OAuth authentication dance) or
#' supplied as a parameter to the url.  See [oauth1.0_token()] and
#' [oauth2.0_token()] for examples of both techniques.
#'
#' This function should not normally be called directly by the user.
#'
#' @param request_url the url to send the browser to
#' @param is_interactive DEPRECATED
#' @export
#' @keywords internal
oauth_listener <- function(request_url, is_interactive = interactive()) {
  if (!is_installed("httpuv")) {
    stop("httpuv package required to capture OAuth credentials.")
  }

  info <- NULL
  listen <- function(env) {
    if (!identical(env$PATH_INFO, "/")) {
      return(list(
        status = 404L,
        headers = list("Content-Type" = "text/plain"),
        body = "Not found"
      ))
    }

    query <- env$QUERY_STRING
    if (!is.character(query) || identical(query, "")) {
      info <<- NA
    } else {
      info <<- parse_query(gsub("^\\?", "", query))
    }

    html_response <- '<html><head><script type="text/javascript">window.onload = function() { window.close(); }</script></head><body>Authentication complete. You can close this window if it does not close automatically.</body></html>'

    list(
      status = 200L,
      headers = list("Content-Type" = "text/html"),
      body = html_response
    )
  }
  use <- listener_endpoint()
  server <- httpuv::startServer(use$host, use$port, list(call = listen))
  on.exit(httpuv::stopServer(server))

  message("Waiting for authentication in browser...")
  message("Press Esc/Ctrl + C to abort")
  browseURL(request_url)
  while (is.null(info)) {
    httpuv::service()
    Sys.sleep(0.001)
  }
  httpuv::service() # to send text back to browser

  if (identical(info, NA)) {
    stop("Authentication failed.", call. = FALSE)
  }

  message("Authentication complete.")
  info
}

#' The oauth callback url.
#'
#' The url that [oauth_listener()] expects that the client be
#' referred to.
#'
#' @keywords internal
#' @export
oauth_callback <- function() {
  paste0(
    "http://",
    Sys.getenv("HTTR_SERVER", "localhost"),
    ":",
    Sys.getenv("HTTR_SERVER_PORT", "1410"),
    "/"
  )
}

listener_endpoint <- function() {
  list(
    host = Sys.getenv("HTTR_LOCALHOST", "127.0.0.1"),
    port = as.integer(Sys.getenv("HTTR_PORT", "1410"))
  )
}
