library(jsonlite)

mango_socket_path <- function() {
  p <- Sys.getenv("MANGO_INSTANCE_SIGNATURE")
  if (nzchar(p)) p else stop("MANGO_INSTANCE_SIGNATURE is not set")
}

mmsg_capture <- function(args) {
  out <- suppressWarnings(system2("mmsg", args = args, stdout = TRUE))
  rc <- attr(out, "status")
  if (!is.null(rc) && rc != 0) {
    stop("mmsg failed: ", paste(args, collapse = " "))
  }
  out
}

parse_reply <- function(text, cmd) {
  reply <- fromJSON(paste(text, collapse = "\n"))
  if ("error" %in% names(reply)) {
    stop(paste0("mango error for ", cmd, ": ", reply$error))
  }
  reply
}

mango_call <- function(cmd) {
  parse_reply(mmsg_capture(strsplit(cmd, " ", fixed = TRUE)[[1]]), cmd)
}

mango_call_argv <- function(args) {
  parse_reply(mmsg_capture(args), paste(args, collapse = " "))
}

mango_retry <- function(cmd, attempts = 50, delay = 0.1) {
  for (i in seq_len(attempts)) {
    ok <- tryCatch({ mango_call(cmd); TRUE }, error = function(e) FALSE)
    if (ok) return(invisible(TRUE))
    Sys.sleep(delay)
  }
  stop("mango not reachable after ", attempts, " attempts: ", cmd)
}

mango_get <- function(spec) mango_call(paste("get", spec))

mango_set_option <- function(key, value) {
  mango_call_argv(c("setoption", key, value))
}

mango_dispatch <- function(function_name, ...) {
  mango_call_argv(c("dispatch", paste(c(function_name, ...), collapse = ",")))
}

mango_unset_bind <- function(mode, mods, keysym, family = "bind") {
  mango_call_argv(c("unset", "bind", mode, mods, keysym, family))
}

mango_unset_rule <- function(kind, spec) {
  mango_call_argv(c("unset", kind, spec))
}

mango_watch <- function(subject, handler = NULL) {
  lines <- mmsg_capture(c("watch", subject))
  for (line in lines) {
    if (identical(trimws(line), "")) next
    event <- parse_reply(line, paste("watch", subject))
    if (is.function(handler)) handler(event) else print(event)
  }
  invisible(TRUE)
}

mango_watch_first <- function(subject) {
  lines <- mmsg_capture(c("watch", subject))
  parse_reply(lines[1], paste("watch", subject))
}

mango_version <- function() mango_get("version")$version
mango_monitors <- function() mango_get("all-monitors")$monitors
mango_clients <- function() mango_get("all-clients")$clients
mango_focused_client <- function() mango_get("focusing-client")
mango_binds <- function() mango_get("binds")$binds
mango_rules <- function() mango_get("rules")$rules
mango_option <- function(key) mango_get(paste("option", key))$value
mango_options <- function() mango_get("options")

mango_bind <- function(mode, mods, keysym, cmd) {
  mango_dispatch("setup_bind", mode, mods, keysym, cmd)
}

mango_rule <- function(match, ...) {
  mango_dispatch("setup_rule", match, ...)
}

mango_rule_for_class <- function(class_name, ...) {
  mango_rule(paste0("class=", class_name), ...)
}

mango_set_layout <- function(name) {
  mango_dispatch("setlayout", name)
}

mango_toggle_layout <- function() {
  count <- get0(".mango_layout_calls", envir = .GlobalEnv, ifnotfound = 0L)
  assign(".mango_layout_calls", count + 1L, envir = .GlobalEnv)
  mango_set_layout(if ((count + 1L) %% 2 == 1L) "tile" else "dwindle")
}

mango_borders <- function(px, color) {
  list(
    mango_set_option("borderpx", as.character(px)),
    mango_set_option("bordercolor", color)
  )
}

mango_gaps <- function(h, v) {
  list(
    mango_set_option("gappih", as.character(h)),
    mango_set_option("gappiv", as.character(v))
  )
}

mango_theme <- function(hex, border_px) {
  list(
    mango_set_option("rootcolor", hex),
    mango_set_option("bordercolor", hex),
    mango_set_option("borderpx", as.character(border_px))
  )
}

mango_watch_until <- function(subject, predicate, timeout = 5.0) {
  deadline <- Sys.time() + timeout
  repeat {
    frame <- mango_watch_first(subject)
    if (isTRUE(predicate(frame))) {
      return(frame)
    }
    if (Sys.time() > deadline) {
      stop("watch_until timeout: watch ", subject)
    }
  }
}

mango_for_each_client <- function(fn) {
  for (client in mango_clients()) {
    fn(client)
  }
  invisible(TRUE)
}

mango_focused <- function(fn) {
  client <- mango_focused_client()
  if (!is.null(client) && !is.null(client$id) && !identical(client$id, NA)) {
    fn(client)
  }
  invisible(TRUE)
}

mango_options_map <- function() {
  raw <- mango_options()
  if (!is.null(raw$options)) {
    vals <- raw$options
    if (is.data.frame(vals)) {
      return(setNames(as.list(vals$value), vals$option))
    }
    return(vals)
  }
  if (!is.null(raw$option)) {
    return(setNames(list(raw$value), raw$option))
  }
  raw
}

mango_info <- function() {
  list(
    version = mango_version(),
    monitors = mango_monitors(),
    options = mango_options()
  )
}

mango_apply_options <- function(pairs) {
  lapply(names(pairs), function(key) mango_set_option(key, as.character(pairs[[key]])))
}