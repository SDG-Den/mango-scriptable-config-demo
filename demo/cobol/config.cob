identification division.
       program-id. mangoconf.
       data division.
       working-storage section.
       copy mango-ws.
       procedure division.
           move "get version" to ws-cmd
           perform emit-cmd
           move "setoption borderpx 0" to ws-cmd
           perform emit-cmd
           move "setoption gappih 4" to ws-cmd
           perform emit-cmd
           move "setoption rootcolor 1d1d2b" to ws-cmd
           perform emit-cmd
           move "setoption animations off" to ws-cmd
           perform emit-cmd
           move "dispatch setlayout,tile" to ws-cmd
           perform emit-cmd
           move "get binds" to ws-cmd
           perform emit-cmd
           move "watch all-clients" to ws-cmd
           perform emit-cmd
           stop run.
           copy mango.
