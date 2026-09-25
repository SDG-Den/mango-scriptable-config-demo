def mango-socket-path [] {
    let sig = $env.MANGO_INSTANCE_SIGNATURE?
    if $sig == null { error make { msg: "MANGO_INSTANCE_SIGNATURE is not set" } }
    $sig
}

def mango-call [...cmd] {
    ^mmsg ...$cmd
}

def mango-retry [cmd: string, attempts: int = 50, delay: duration = 100ms] {
    for i in 0..$attempts {
        try {
            mango-call $cmd | ignore
            return 0
        } catch {
            if $i < ($attempts - 1) { sleep $delay }
        }
    }
    error make { msg: $"mango not reachable after ($attempts) attempts: ($cmd)" }
}

def mango-get [...spec] {
    mango-call get ...$spec
}

def mango-set-option [key: string, value: string] {
    mango-call setoption $key $value
}

def mango-dispatch [function: string, ...args: string] {
    let joined = ([$function ...$args] | str join ',')
    mango-call dispatch $joined
}

def mango-unset-bind [mode: string, mods: string, keysym: string, family: string = "bind"] {
    mango-call unset bind $mode $mods $keysym $family
}

def mango-unset-rule [kind: string, spec: string] {
    mango-call unset $kind $spec
}

def mango-watch [subject: string] {
    mango-call watch $subject
}

def mango-watch-first [subject: string] {
    mango-watch $subject
}

def mango-version [] { mango-call get version }
def mango-monitors [] { mango-call get all-monitors }
def mango-clients [] { mango-call get all-clients }
def mango-focused-client [] { mango-call get focusing-client }
def mango-binds [] { mango-call get binds }
def mango-rules [] { mango-call get rules }
def mango-option [key: string] { mango-call get option $key }
def mango-options [] { mango-call get options }

def mango-bind [mode: string, mods: string, keysym: string, cmd: string] {
    mango-dispatch setup_bind $mode $mods $keysym $cmd
}

def mango-rule [match: string, ...props: string] {
    mango-dispatch setup_rule $match ...$props
}

def mango-rule-for-class [class: string, ...props: string] {
    mango-rule $"class=($class)" ...$props
}

def mango-set-layout [name: string] {
    mango-dispatch setlayout $name
}

def --env mango-toggle-layout [] {
    let tick = (($env.MANGO_LAYOUT_TICK? | default 0) + 1)
    $env.MANGO_LAYOUT_TICK = $tick
    if (($tick mod 2) == 1) { mango-set-layout tile } else { mango-set-layout dwindle }
}

def mango-borders [px: int, color: string] {
    [ (mango-set-option borderpx ($px | into string)) (mango-set-option bordercolor $color) ]
}

def mango-gaps [h: int, v: int] {
    [ (mango-set-option gappih ($h | into string)) (mango-set-option gappiv ($v | into string)) ]
}

def mango-theme [hex: string, border_px: int] {
    [ (mango-set-option rootcolor $hex)
      (mango-set-option bordercolor $hex)
      (mango-set-option borderpx ($border_px | into string)) ]
}

def mango-watch-until [subject: string, predicate: closure, timeout: duration = 5sec] {
    let deadline = ((date now) + $timeout)
    loop {
        let frame = (mango-watch-first $subject)
        if (do $predicate $frame) { return $frame }
        if ((date now) > $deadline) {
            error make { msg: $"watch_until timeout: watch ($subject)" }
        }
    }
}

def mango-for-each-client [action: closure] {
    mango-clients
    | get clients
    | each { |c| do $action $c }
}

def mango-focused [action: closure] {
    let client = (mango-focused-client)
    if $client.id != null { do $action $client }
}

def mango-options-map [] {
    let raw = (mango-options)
    if (not ($raw | get -i options | is-empty)) {
        $raw.options | into record
    } else if (not ($raw | get -i value | is-empty)) {
        { option: ($raw | get -i option?), value: ($raw | get -i value) }
    } else {
        $raw
    }
}

def mango-info [] {
    { version: (mango-version | get version)
      monitors: (mango-monitors | get monitors)
      options: (mango-options) }
}

def mango-apply-options [pairs: record] {
    $pairs | columns | each { |k| mango-set-option $k ($pairs | get $k | into string) }
}