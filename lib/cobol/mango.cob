emit-cmd.
           display function trim(ws-cmd)
           move spaces to ws-cmd
           .

mango-get.
           string "get " delimited by size
                  ws-opt-key delimited by size
                  into ws-cmd
           perform emit-cmd
           .

mango-set-option.
           string "setoption " delimited by size
                  ws-opt-key delimited by size " "
                  ws-opt-val delimited by size
                  into ws-cmd
           perform emit-cmd
           .

mango-dispatch.
           string "dispatch " delimited by size
                  ws-disp-arg delimited by size
                  into ws-cmd
           perform emit-cmd
           .

mango-unset-bind.
           string "unset bind " delimited by size
                  ws-mode delimited by size " "
                  ws-mods delimited by size " "
                  ws-keysym delimited by size " bind"
                  into ws-cmd
           perform emit-cmd
           .

mango-unset-rule.
           string "unset " delimited by size
                  ws-match delimited by size " "
                  ws-prop delimited by size
                  into ws-cmd
           perform emit-cmd
           .

mango-watch.
           string "watch " delimited by size
                  ws-subject delimited by size
                  into ws-cmd
           perform emit-cmd
           .

mango-watch-first.
           perform mango-watch
           .

mango-retry.
           perform emit-cmd
           .

mango-bind.
           string "dispatch setup_bind," delimited by size
                  ws-mode delimited by size ","
                  ws-mods delimited by size ","
                  ws-keysym delimited by size ","
                  ws-cmd-arg delimited by size
                  into ws-cmd
           perform emit-cmd
           .

mango-rule.
           string "dispatch setup_rule," delimited by size
                  ws-match delimited by size ","
                  ws-prop delimited by size
                  into ws-cmd
           perform emit-cmd
           .

mango-rule-for-class.
           string "dispatch setup_rule,class=" delimited by size
                  ws-match delimited by size ","
                  ws-prop delimited by size
                  into ws-cmd
           perform emit-cmd
           .

mango-set-layout.
           string "dispatch setlayout," delimited by size
                  ws-layout delimited by size
                  into ws-cmd
           perform emit-cmd
           .

mango-toggle-layout.
           add 1 to ws-num
           if function mod(ws-num 2) = 1
               move "dispatch setlayout,tile" to ws-cmd
           else
               move "dispatch setlayout,dwindle" to ws-cmd
           end-if
           perform emit-cmd
           .

mango-borders.
           string "setoption borderpx " delimited by size
                  ws-cmd-arg delimited by size
                  into ws-cmd
           perform emit-cmd
           string "setoption bordercolor " delimited by size
                  ws-opt-val delimited by size
                  into ws-cmd
           perform emit-cmd
           .

mango-gaps.
           string "setoption gappih " delimited by size
                  ws-cmd-arg delimited by size
                  into ws-cmd
           perform emit-cmd
           string "setoption gappiv " delimited by size
                  ws-opt-val delimited by size
                  into ws-cmd
           perform emit-cmd
           .

mango-theme.
           string "setoption rootcolor " delimited by size
                  ws-opt-key delimited by size
                  into ws-cmd
           perform emit-cmd
           string "setoption bordercolor " delimited by size
                  ws-opt-key delimited by size
                  into ws-cmd
           perform emit-cmd
           string "setoption borderpx " delimited by size
                  ws-cmd-arg delimited by size
                  into ws-cmd
           perform emit-cmd
           .

mango-info.
           move "get version" to ws-cmd
           perform emit-cmd
           move "get all-monitors" to ws-cmd
           perform emit-cmd
           move "get options" to ws-cmd
           perform emit-cmd
           .
