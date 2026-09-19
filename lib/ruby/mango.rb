require "socket"
require "json"

module Mango
  module_function

  def socket_path
    sig = ENV["MANGO_INSTANCE_SIGNATURE"]
    return sig if sig

    raise "MANGO_INSTANCE_SIGNATURE is not set"
  end

  def call(cmd)
    sock = UNIXSocket.new(socket_path)
    sock.puts(cmd)
    line = sock.gets
    sock.close
    raise "connection closed without reply: #{cmd}" unless line

    JSON.parse(line)
  end

  def ensure_ok(reply)
    raise reply["error"] if reply["error"]

    reply
  end

  def retry(cmd, attempts = 50, delay = 0.1)
    attempts.times do
      begin
        return ensure_ok(call(cmd))
      rescue SystemCallError
        sleep delay
      end
    end
    raise "mango not reachable after #{attempts} attempts: #{cmd}"
  end

  def get(*spec)
    ensure_ok(call("get #{spec.join(" ")}"))
  end

  def set_option(key, value)
    ensure_ok(call("setoption #{key} #{value}"))
  end

  def dispatch(function, *args)
    ensure_ok(call("dispatch #{([function] + args).join(",")}"))
  end

  def unset_bind(mode, mods, keysym, family = "bind")
    ensure_ok(call("unset bind #{mode} #{mods} #{keysym} #{family}"))
  end

  def unset_rule(kind, spec)
    ensure_ok(call("unset #{kind} #{spec}"))
  end

  def watch(subject)
    sock = UNIXSocket.new(socket_path)
    sock.puts("watch #{subject}")
    while (line = sock.gets)
      next if line.strip.empty?

      event = JSON.parse(line)
      ensure_ok(event)
      yield event
    end
  ensure
    sock&.close
  end
end