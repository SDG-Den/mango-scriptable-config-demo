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
  "alt,q,killclient",
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

def brick_slots(count, mon)
  goh, gov, gih, giv = 10, 10, 6, 6
  fulls = 3
  per_row = fulls + 1
  rows = (count.to_f / per_row).ceil
  aw = mon["width"] - 2 * goh
  ah = mon["height"] - 2 * gov
  bw = (aw - fulls * gih) / (fulls + 0.5)
  bh = (ah - (rows - 1) * giv) / rows
  half = bw / 2
  count.times.map do |i|
    r = i / per_row
    c = i % per_row
    if r.even?
      x = mon["x"] + goh + c * (bw + gih)
      w = (c == per_row - 1) ? half : bw
    else
      x = mon["x"] + goh + ((c == 0) ? 0 : half + (c - 1) * (bw + gih) + gih)
      w = (c == 0) ? half : bw
    end
    y = mon["y"] + gov + r * (bh + giv)
    [x.round, y.round, w.round - 1, bh.round - 1]
  end
end

Mango.watch("all-clients") do |_event|
  mons = data(Mango.get("all-monitors"))["monitors"]
  clients = (data(Mango.get("all-clients"))["clients"] || []).reject { |c| c["is_swallowing"] }.sort_by { |c| c["id"] }
  next if mons.empty? || clients.empty?

  mon = mons.first
  clients.zip(brick_slots(clients.size, mon)).each do |c, (x, y, w, h)|
    next if c["x"] == x && c["y"] == y && c["width"] == w && c["height"] == h

    Mango.dispatch("movewin", "#{x},#{y}", "client,#{c['id']}")
    Mango.dispatch("resizewin", "#{w},#{h}", "client,#{c['id']}")
  end
end