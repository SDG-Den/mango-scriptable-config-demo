program mangoconf
  use mango
  implicit none
  call emit_cmd("get version")
  call emit_cmd("setoption borderpx 0")
  call emit_cmd("setoption gappih 4")
  call emit_cmd("setoption rootcolor 1d1d2b")
  call emit_cmd("setoption animations off")
  call emit_cmd("setoption bind alt,Return,spawn_shell,foot")
  call emit_cmd("dispatch setlayout,tile")
  call emit_cmd("get binds")
  call emit_cmd("watch all-clients")
end program mangoconf