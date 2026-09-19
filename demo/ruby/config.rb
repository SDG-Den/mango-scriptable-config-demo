require "json"
require "mango"

def data(reply)
  reply["result"] || reply
end

def count(reply)
  d = data(reply)
  return d.size unless d.is_a?(Hash)

  d.values.sum { |v| v.is_a?(Array) ? v.size : 0 }
end

def on_focus(event)
  d = data(event)
  appid = d["appid"] || d["app_id"] || "-"
  title = d["title"] || "-"
  puts "focus -> #{appid} | #{title}"
  $stdout.flush
end

puts "mango #{JSON.generate(data(Mango.retry("get version")))}"

{
  "borderpx" => "3",
  "gappih" => "6",
  "gappiv" => "6",
  "rootcolor" => "2e3440ff",
  "focused_opacity" => "0.95",
  "unfocused_opacity" => "0.80",
}.each { |key, value| Mango.set_option(key, value) }

[
  "alt,Return,spawn_shell,foot",
  "alt,space,setlayout,tile",
  "alt+Shift,space,setlayout,scroller",
  "alt,Tab,focusstack,next",
  "alt+Shift,Tab,focusstack,prev",
  "Ctrl,1,view,1",
  "Ctrl,2,view,2",
  "Ctrl,3,view,3",
  "Ctrl,4,view,4",
  "alt+Shift,q,quit",
  "alt,f,togglefullscreen",
].each { |bind| Mango.set_option("bind", bind) }

Mango.set_option("mousebind", "alt,btn_left,moveresize,curmove")
Mango.set_option("tagrule", "id:1,layout_name:tile")
Mango.set_option("tagrule", "id:2,layout_name:scroller")
Mango.set_option("windowrule", "title:foot,isfloating:1")
Mango.set_option("windowrule", "appid:firefox,isfullscreen:1,tags:2")
Mango.set_option("layerrule", "layer_name:waybar,noanim:1,noshadow:1")

puts "binds: #{count(Mango.get("binds"))}"
puts "rules: #{count(Mango.get("rules"))}"

Mango.dispatch("setlayout", "tile")
puts "dispatch setlayout tile -> ok"

puts "watching all-clients (layout engine)"

def staircase_slots(count, mon)
  cx = mon["x"] + mon["width"] / 2
  cy = mon["y"] + mon["height"] / 2
  count.times.map do |i|
    w = [560 - i * 24, 240].max
    h = [360 - i * 20, 160].max
    [cx - w / 2 + i * 60, cy - h / 2 + i * 60, w, h]
  end
end

Mango.watch("all-clients") do |_event|
  mons = data(Mango.get("all-monitors"))["monitors"]
  clients = (data(Mango.get("all-clients"))["clients"] || []).reject { |c| c["is_swallowing"] }.sort_by { |c| c["id"] }
  next if mons.empty? || clients.empty?

  mon = mons.first
  clients.zip(staircase_slots(clients.size, mon)).each do |c, (x, y, w, h)|
    next if c["x"] == x && c["y"] == y && c["width"] == w && c["height"] == h

    Mango.dispatch("movewin", "#{x},#{y}", "client,#{c['id']}")
    Mango.dispatch("resizewin", "#{w},#{h}", "client,#{c['id']}")
  end
end