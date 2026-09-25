(defn mango-call [& args]
  (def argv (array; args))
  (array/insert argv 0 "mmsg")
  (os/execute argv :p))

(defn mango-get [& spec]
  (mango-call "get" ;spec))

(defn mango-set-option [key value]
  (mango-call "setoption" key value))

(defn mango-dispatch [function & args]
  (def parts (array; args))
  (array/insert parts 0 function)
  (mango-call "dispatch" (string/join parts ",")))

(defn mango-unset-bind [mode mods keysym &opt family]
  (mango-call "unset" "bind" mode mods keysym (or family "bind")))

(defn mango-unset-rule [kind spec]
  (mango-call "unset" kind spec))

(defn mango-watch [subject]
  (mango-call "watch" subject))

(defn mango-watch-first [subject]
  (mango-watch subject))

(defn mango-retry [cmd &opt attempts delay]
  (def n (or attempts 50))
  (def d (or delay 0.1))
  (var i 0)
  (var rc 1)
  (while (and (< i n) (not= rc 0))
    (set rc (mango-call ;(string/split " " cmd)))
    (if (not= rc 0) (os/sleep d))
    (set i (+ i 1)))
  (if (not= rc 0)
    (error (string "mango not reachable after " n " attempts: " cmd)))
  rc)

(defn mango-version []
  (mango-call "get" "version"))

(defn mango-monitors []
  (mango-call "get" "all-monitors"))

(defn mango-clients []
  (mango-call "get" "all-clients"))

(defn mango-focused-client []
  (mango-call "get" "focusing-client"))

(defn mango-binds []
  (mango-call "get" "binds"))

(defn mango-rules []
  (mango-call "get" "rules"))

(defn mango-option [key]
  (mango-call "get" "option" key))

(defn mango-options []
  (mango-call "get" "options"))

(defn mango-capture [& args]
  (def tmp (file/temp "mango-capture-XXXXXX"))
  (def cmd (string/join (array/insert (array ;args) 0 "mmsg") " "))
  (def rc (os/execute ["sh" "-c" (string cmd " > " tmp "; printf '\\n' >> " tmp)] :p))
  (def out (slurp tmp))
  (os/rm tmp)
  (if (not= rc 0) (error (string "mmsg failed: " cmd)))
  out)

(def mango-json-ws-b @{32 1 9 1 10 1 13 1})
(def mango-json-num-b @{48 1 49 1 50 1 51 1 52 1 53 1 54 1 55 1 56 1 57 1 46 1 69 1 101 1 43 1 45 1})
(def mango-json-digit-b @{48 1 49 1 50 1 51 1 52 1 53 1 54 1 55 1 56 1 57 1 45 1})

(defn- mango-json-skip [text pos]
  (var i pos)
  (while (and (< i (length text)) (get mango-json-ws-b (get text i)))
    (set i (+ i 1)))
  i)

(defn- mango-json-string [text pos]
  (var i (+ pos 1))
  (def buf @"")
  (while (and (< i (length text)) (not= (get text i) 34))
    (if (= (get text i) 92)
      (do
        (set i (+ i 1))
        (def esc (get text i))
        (cond
          (= esc 110) (buffer/push buf 10)
          (= esc 116) (buffer/push buf 9)
          (= esc 114) (buffer/push buf 13)
          (= esc 92) (buffer/push buf 92)
          (= esc 34) (buffer/push buf 34)
          (= esc 47) (buffer/push buf 47)
          (= esc 117)
          (do
            (def hex (string/slice text (+ i 1) (+ i 5)))
            (def cp (scan-number (string "0x" hex)))
            (when cp (buffer/push buf (band cp 255)))
            (set i (+ i 4)))
          (buffer/push buf esc)))
      (buffer/push buf (get text i)))
    (set i (+ i 1)))
  [ (+ i 1) (string buf) ])

(defn- mango-json-number [text pos]
  (var i pos)
  (while (and (< i (length text)) (get mango-json-num-b (get text i)))
    (set i (+ i 1)))
  [ i (or (scan-number (string/slice text pos i)) 0) ])

(defn- mango-json-word [text pos word value]
  (if (= (string/slice text pos (+ pos (length word))) word)
    [ (+ pos (length word)) value ]
    nil))

(var mango-json-parse nil)

(defn- mango-json-array [text pos]
  (var i pos)
  (def out @[])
  (set i (mango-json-skip text (+ i 1)))
  (if (and (< i (length text)) (= (get text i) 93))
    [ (+ i 1) out ]
    (do
      (def next (mango-json-parse text i))
      (array/push out (next 1))
      (set i (next 0))
      (while (and (< i (length text)) (= (get text i) 44))
        (set i (mango-json-skip text (+ i 1)))
        (def elem (mango-json-parse text i))
        (array/push out (elem 1))
        (set i (elem 0)))
      (set i (mango-json-skip text i))
      [ (+ i 1) out ])))

(set mango-json-parse (fn [text pos]
  (def i (mango-json-skip text pos))
  (def c (get text i))
  (cond
    (= c 34) (mango-json-string text i)
    (= c 123)
    (do
      (var j (+ i 1))
      (def tbl @{})
      (set j (mango-json-skip text j))
      (if (and (< j (length text)) (= (get text j) 125))
        [ (+ j 1) tbl ]
        (do
          (while true
            (set j (mango-json-skip text j))
            (def key (mango-json-string text j))
            (set j (mango-json-skip text (key 0)))
            (set j (+ j 1))
            (def val (mango-json-parse text j))
            (put tbl (key 1) (val 1))
            (set j (mango-json-skip text (val 0)))
            (if (and (< j (length text)) (= (get text j) 44))
              (set j (+ j 1))
              (break)))
          [ (+ j 1) tbl ])))
    (= c 91) (mango-json-array text i)
    (= c 116) (mango-json-word text i "true" true)
    (= c 102) (mango-json-word text i "false" false)
    (= c 110) (mango-json-word text i "null" nil)
    (get mango-json-digit-b c) (mango-json-number text i)
    (error (string "mango-json: unexpected char " c)))))

(defn mango-parse [text]
  ((mango-json-parse (string/trim text) 0) 1))

(defn mango-bind [mode mods keysym cmd]
  (mango-dispatch "setup_bind" mode mods keysym cmd))

(defn mango-rule [match & props]
  (def parts (array; props))
  (array/insert parts 0 match)
  (mango-dispatch "setup_rule" ;parts))

(defn mango-rule-for-class [class & props]
  (def parts (array; props))
  (array/insert parts 0 (string "class=" class))
  (mango-dispatch "setup_rule" ;parts))

(defn mango-set-layout [name]
  (mango-dispatch "setlayout" name))

(var mango-layout-calls 0)
(defn mango-toggle-layout []
  (set mango-layout-calls (+ mango-layout-calls 1))
  (if (odd? mango-layout-calls)
    (mango-set-layout "tile")
    (mango-set-layout "dwindle")))

(defn mango-borders [px color]
  (mango-set-option "borderpx" (string px))
  (mango-set-option "bordercolor" color))

(defn mango-gaps [h v]
  (mango-set-option "gappih" (string h))
  (mango-set-option "gappiv" (string v)))

(defn mango-theme [hex border-px]
  (mango-set-option "rootcolor" hex)
  (mango-set-option "bordercolor" hex)
  (mango-set-option "borderpx" (string border-px)))

(defn mango-watch-until [subject predicate &opt timeout]
  (def deadline (+ (os/time) (or timeout 5)))
  (while true
    (def frame (mango-parse (mango-capture "watch" subject)))
    (if (predicate frame) (break frame))
    (if (> (os/time) deadline) (error (string "watch_until timeout: watch " subject)))
    (os/sleep 0.1)))

(defn mango-for-each-client [handler]
  (def clients (get (mango-parse (mango-capture "get" "all-clients")) "clients"))
  (each client clients (handler client)))

(defn mango-focused [handler]
  (def client (mango-parse (mango-capture "get" "focusing-client")))
  (if (not= (get client "id") nil) (handler client)))

(defn mango-options-map []
  (def raw (mango-parse (mango-capture "get" "options")))
  (if (get raw "options")
    (get raw "options")
    (if (get raw "option")
      {(get raw "option") (get raw "value")}
      raw)))

(defn mango-info []
  {"version" (mango-parse (mango-capture "get" "version"))
   "monitors" (mango-parse (mango-capture "get" "all-monitors"))
   "options" (mango-parse (mango-capture "get" "options"))})

(defn mango-apply-options [pairs]
  (each [k v] pairs
    (mango-set-option k (string v))))