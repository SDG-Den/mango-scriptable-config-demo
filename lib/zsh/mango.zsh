mango_socket_path() {
  [ -n "${MANGO_INSTANCE_SIGNATURE:-}" ] || {
    echo "MANGO_INSTANCE_SIGNATURE is not set" >&2
    return 1
  }
  printf '%s' "$MANGO_INSTANCE_SIGNATURE"
}

mango_call() {
  mmsg "$@"
}

mango_retry() {
  local cmd="$1"
  local attempts="${2:-50}"
  local delay="${3:-0.1}"
  local i
  for ((i = 0; i < attempts; i++)); do
    if mango_call $cmd >/dev/null 2>&1; then
      return 0
    fi
    sleep "$delay"
  done
  echo "mango not reachable after $attempts attempts: $cmd" >&2
  return 1
}

mango_get() {
  mmsg get "$@"
}

mango_set_option() {
  mmsg setoption "$1" "$2"
}

mango_dispatch() {
  local function="$1"
  shift
  local joined="$function"
  local arg
  for arg in "$@"; do
    joined="$joined,$arg"
  done
  mmsg dispatch "$joined"
}

mango_unset_bind() {
  mmsg unset bind "$1" "$2" "$3" "${4:-bind}"
}

mango_unset_rule() {
  mmsg unset "$1" "$2"
}

mango_watch() {
  mmsg watch "$1"
}

mango_watch_first() {
  mango_watch "$1"
}

mango_version() {
  mmsg get version
}

mango_monitors() {
  mmsg get all-monitors
}

mango_clients() {
  mmsg get all-clients
}

mango_focused_client() {
  mmsg get focusing-client
}

mango_binds() {
  mmsg get binds
}

mango_rules() {
  mmsg get rules
}

mango_option() {
  mmsg get option "$1"
}

mango_options() {
  mmsg get options
}

mango_bind() {
  mango_dispatch setup_bind "$1" "$2" "$3" "$4"
}

mango_rule() {
  local match="$1"
  shift
  mango_dispatch setup_rule "$match" "$@"
}

mango_rule_for_class() {
  local class="$1"
  shift
  mango_rule "class=$class" "$@"
}

mango_set_layout() {
  mango_dispatch setlayout "$1"
}

MANGO_LAYOUT_CALLS=0
mango_toggle_layout() {
  MANGO_LAYOUT_CALLS=$((MANGO_LAYOUT_CALLS + 1))
  if [ $((MANGO_LAYOUT_CALLS % 2)) -eq 1 ]; then
    mango_set_layout tile
  else
    mango_set_layout dwindle
  fi
}

mango_borders() {
  mango_set_option borderpx "$1"
  mango_set_option bordercolor "$2"
}

mango_gaps() {
  mango_set_option gappih "$1"
  mango_set_option gappiv "$2"
}

mango_theme() {
  mango_set_option rootcolor "$1"
  mango_set_option bordercolor "$1"
  mango_set_option borderpx "$2"
}

mango_watch_until() {
  local subject="$1"
  local predicate="$2"
  local timeout="${3:-5}"
  local deadline=$(( $(date +%s) + timeout ))
  local frame
  while :; do
    frame=$(mango_watch_first "$subject") || return 1
    if $predicate "$frame"; then
      printf '%s\n' "$frame"
      return 0
    fi
    if [ "$(date +%s)" -gt "$deadline" ]; then
      echo "watch_until timeout: watch $subject" >&2
      return 1
    fi
    sleep 0.1
  done
}

mango_for_each_client() {
  local handler="$1"
  local client
  mango_clients | while IFS= read -r client; do
    [ -n "$client" ] || continue
    "$handler" "$client"
  done
}

mango_focused() {
  local handler="$1"
  local reply
  reply=$(mango_focused_client) || return 1
  case "$reply" in
    *'"id":null'*|*'"id": null'*) return 0 ;;
  esac
  "$handler" "$reply"
}

mango_options_map() {
  mango_options
}

mango_info() {
  printf 'version=%s\n' "$(mango_version)"
  printf 'monitors=%s\n' "$(mango_monitors)"
  printf 'options=%s\n' "$(mango_options)"
}

mango_apply_options() {
  local key
  while [ "$#" -gt 0 ]; do
    key="$1"
    shift
    [ "$#" -gt 0 ] || break
    mango_set_option "$key" "$1"
    shift
  done
}