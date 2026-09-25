function mango_socket_path
    if not set -q MANGO_INSTANCE_SIGNATURE
        echo "MANGO_INSTANCE_SIGNATURE is not set" >&2
        return 1
    end
    echo -n $MANGO_INSTANCE_SIGNATURE
end

function mango_call
    mmsg $argv
end

function mango_retry
    set -l attempts 50
    set -l delay 0.1
    if test (count $argv) -ge 2
        set attempts $argv[2]
    end
    if test (count $argv) -ge 3
        set delay $argv[3]
    end
    for i in (seq 1 $attempts)
        if mango_call $argv[1] >/dev/null 2>&1
            return 0
        end
        sleep $delay
    end
    echo "mango not reachable after $attempts attempts: $argv[1]" >&2
    return 1
end

function mango_get
    mmsg get $argv
end

function mango_set_option
    mmsg setoption $argv[1] $argv[2]
end

function mango_dispatch
    set -l parts $argv
    mmsg dispatch (string join , $parts)
end

function mango_unset_bind
    if test (count $argv) -ge 4
        mmsg unset bind $argv[1] $argv[2] $argv[3] $argv[4]
    else
        mmsg unset bind $argv[1] $argv[2] $argv[3] bind
    end
end

function mango_unset_rule
    mmsg unset $argv[1] $argv[2]
end

function mango_watch
    mmsg watch $argv[1]
end

function mango_watch_first
    mango_watch $argv[1]
end

function mango_version
    mmsg get version
end

function mango_monitors
    mmsg get all-monitors
end

function mango_clients
    mmsg get all-clients
end

function mango_focused_client
    mmsg get focusing-client
end

function mango_binds
    mmsg get binds
end

function mango_rules
    mmsg get rules
end

function mango_option
    mmsg get option $argv[1]
end

function mango_options
    mmsg get options
end

function mango_bind
    mango_dispatch setup_bind $argv[1] $argv[2] $argv[3] $argv[4]
end

function mango_rule
    set -l match $argv[1]
    set -e argv[1]
    mango_dispatch setup_rule $match $argv
end

function mango_rule_for_class
    set -l class $argv[1]
    set -e argv[1]
    mango_rule "class=$class" $argv
end

function mango_set_layout
    mango_dispatch setlayout $argv[1]
end

set -g MANGO_LAYOUT_CALLS 0
function mango_toggle_layout
    set -g MANGO_LAYOUT_CALLS (math $MANGO_LAYOUT_CALLS + 1)
    if test (math "$MANGO_LAYOUT_CALLS % 2") -eq 1
        mango_set_layout tile
    else
        mango_set_layout dwindle
    end
end

function mango_borders
    mango_set_option borderpx $argv[1]
    mango_set_option bordercolor $argv[2]
end

function mango_gaps
    mango_set_option gappih $argv[1]
    mango_set_option gappiv $argv[2]
end

function mango_theme
    mango_set_option rootcolor $argv[1]
    mango_set_option bordercolor $argv[1]
    mango_set_option borderpx $argv[2]
end

function mango_watch_until
    set -l subject $argv[1]
    set -l predicate $argv[2]
    set -l timeout 0
    if test (count $argv) -ge 3
        set timeout $argv[3]
    end
    set -l deadline (math (date +%s) + $timeout)
    while true
        set -l frame (mango_watch_first $subject)
        if $predicate $frame
            echo $frame
            return 0
        end
        if test (date +%s) -gt $deadline
            echo "watch_until timeout: watch $subject" >&2
            return 1
        end
        sleep 0.1
    end
end

function mango_for_each_client
    set -l handler $argv[1]
    for client in (mango_clients | string split \n)
        if test -n "$client"
            $handler $client
        end
    end
end

function mango_focused
    set -l handler $argv[1]
    set -l reply (mango_focused_client)
    if string match -rq '"id":\s*null' -- $reply
        return 0
    end
    $handler $reply
end

function mango_options_map
    mango_options
end

function mango_info
    printf 'version=%s\n' (mango_version)
    printf 'monitors=%s\n' (mango_monitors)
    printf 'options=%s\n' (mango_options)
end

function mango_apply_options
    while test (count $argv) -ge 2
        set -l key $argv[1]
        set -e argv[1]
        mango_set_option $key $argv[1]
        set -e argv[1]
    end
end