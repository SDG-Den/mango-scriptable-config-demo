module mango
  implicit none
  private
  integer :: layout_calls = 0
  public :: emit_cmd, mango_get, mango_set_option, mango_dispatch, &
            mango_unset_bind, mango_unset_rule, mango_watch, mango_watch_first, &
            mango_retry, mango_bind, mango_call_rule, mango_call_rule_for_class, &
            mango_set_layout, mango_toggle_layout, mango_borders, mango_gaps, &
            mango_theme, mango_info

contains

  subroutine emit_cmd(cmd)
    character(len=*), intent(in) :: cmd
    write(*, '(a)') trim(cmd)
  end subroutine emit_cmd

  subroutine mango_call_bin(cmd)
    character(len=*), intent(in) :: cmd
    call emit_cmd(cmd)
  end subroutine mango_call_bin

  subroutine mango_get(key)
    character(len=*), intent(in) :: key
    call emit_cmd("get " // trim(key))
  end subroutine mango_get

  subroutine mango_set_option(key, value)
    character(len=*), intent(in) :: key, value
    call emit_cmd("setoption " // trim(key) // " " // trim(value))
  end subroutine mango_set_option

  subroutine mango_dispatch(arg)
    character(len=*), intent(in) :: arg
    call emit_cmd("dispatch " // trim(arg))
  end subroutine mango_dispatch

  subroutine mango_unset_bind(mode, mods, keysym)
    character(len=*), intent(in) :: mode, mods, keysym
    call emit_cmd("unset bind " // trim(mode) // " " // trim(mods) // " " // &
                  trim(keysym) // " bind")
  end subroutine mango_unset_bind

  subroutine mango_unset_rule(rule_key, rule_val)
    character(len=*), intent(in) :: rule_key, rule_val
    call emit_cmd("unset " // trim(rule_key) // " " // trim(rule_val))
  end subroutine mango_unset_rule

  subroutine mango_watch(subject)
    character(len=*), intent(in) :: subject
    call emit_cmd("watch " // trim(subject))
  end subroutine mango_watch

  subroutine mango_watch_first(subject)
    character(len=*), intent(in) :: subject
    call mango_watch(subject)
  end subroutine mango_watch_first

  subroutine mango_retry(cmd)
    character(len=*), intent(in) :: cmd
    call emit_cmd(cmd)
  end subroutine mango_retry

  subroutine mango_bind(mode, mods, keysym, cmd)
    character(len=*), intent(in) :: mode, mods, keysym, cmd
    call emit_cmd("dispatch setup_bind," // trim(mode) // "," // trim(mods) // "," // &
                  trim(keysym) // "," // trim(cmd))
  end subroutine mango_bind

  subroutine mango_call_rule(match, props)
    character(len=*), intent(in) :: match, props
    call emit_cmd("dispatch setup_rule," // trim(match) // "," // trim(props))
  end subroutine mango_call_rule

  subroutine mango_call_rule_for_class(class_name, props)
    character(len=*), intent(in) :: class_name, props
    call emit_cmd("dispatch setup_rule,class=" // trim(class_name) // "," // trim(props))
  end subroutine mango_call_rule_for_class

  subroutine mango_set_layout(name)
    character(len=*), intent(in) :: name
    call emit_cmd("dispatch setlayout," // trim(name))
  end subroutine mango_set_layout

  subroutine mango_toggle_layout()
    layout_calls = layout_calls + 1
    if (mod(layout_calls, 2) == 1) then
      call mango_set_layout("tile")
    else
      call mango_set_layout("dwindle")
    end if
  end subroutine mango_toggle_layout

  subroutine mango_borders(px, color)
    integer, intent(in) :: px
    character(len=*), intent(in) :: color
    call emit_cmd("setoption borderpx " // itoa(px))
    call emit_cmd("setoption bordercolor " // trim(color))
  end subroutine mango_borders

  subroutine mango_gaps(h, v)
    integer, intent(in) :: h, v
    call emit_cmd("setoption gappih " // itoa(h))
    call emit_cmd("setoption gappiv " // itoa(v))
  end subroutine mango_gaps

  subroutine mango_theme(hex, border_px)
    character(len=*), intent(in) :: hex
    integer, intent(in) :: border_px
    call emit_cmd("setoption rootcolor " // trim(hex))
    call emit_cmd("setoption bordercolor " // trim(hex))
    call emit_cmd("setoption borderpx " // itoa(border_px))
  end subroutine mango_theme

  subroutine mango_info()
    call emit_cmd("get version")
    call emit_cmd("get all-monitors")
    call emit_cmd("get options")
  end subroutine mango_info

  function itoa(n) result(s)
    integer, intent(in) :: n
    character(len=16) :: s
    write(s, '(i0)') n
  end function itoa

end module mango