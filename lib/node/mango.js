const net = require("net");

const socketPath = () => {
  const sig = process.env.MANGO_INSTANCE_SIGNATURE;
  if (sig) return sig;
  throw new Error("MANGO_INSTANCE_SIGNATURE is not set");
};

const call = (cmd) =>
  new Promise((resolve, reject) => {
    const sock = net.createConnection(socketPath());
    let buf = "";
    let done = false;
    const finish = (err, value) => {
      if (done) return;
      done = true;
      sock.destroy();
      if (err) reject(err);
      else resolve(value);
    };
    sock.on("error", (e) => finish(e));
    sock.on("connect", () => sock.write(cmd + "\n"));
    sock.on("data", (chunk) => {
      buf += chunk.toString();
      const nl = buf.indexOf("\n");
      if (nl === -1) return;
      try {
        finish(null, JSON.parse(buf.slice(0, nl)));
      } catch (e) {
        finish(e);
      }
    });
    sock.on("end", () => {
      if (!done) finish(new Error("connection closed without reply: " + cmd));
    });
  });

const ensure = (reply) => {
  if (reply.error) throw new Error(reply.error);
  return reply;
};

const retry = async (cmd, attempts = 50, delay = 100) => {
  for (let i = 0; ; i++) {
    try {
      return ensure(await call(cmd));
    } catch (e) {
      if (i === attempts - 1) throw e;
      await new Promise((r) => setTimeout(r, delay));
    }
  }
};

const get = async (...spec) => ensure(await call("get " + spec.join(" ")));

const setOption = async (key, value) =>
  ensure(await call("setoption " + key + " " + value));

const dispatch = async (fn, ...args) =>
  ensure(await call("dispatch " + [fn, ...args].join(",")));

const unsetBind = async (mode, mods, keysym, family = "bind") =>
  ensure(await call(`unset bind ${mode} ${mods} ${keysym} ${family}`));

const unsetRule = async (kind, spec) =>
  ensure(await call(`unset ${kind} ${spec}`));

const watch = async (subject, onEvent) => {
  const sock = net.createConnection(socketPath(), () => {
    if (sock.destroyed) return;
    sock.write("watch " + subject + "\n");
  });
  sock.setEncoding("utf8");
  let buf = "";
  for await (const chunk of sock) {
    buf += chunk;
    let nl;
    while ((nl = buf.indexOf("\n")) !== -1) {
      const line = buf.slice(0, nl);
      buf = buf.slice(nl + 1);
      if (line) onEvent(ensure(JSON.parse(line)));
    }
  }
};

module.exports = {
  socketPath,
  call,
  retry,
  get,
  setOption,
  dispatch,
  unsetBind,
  unsetRule,
  watch,
};