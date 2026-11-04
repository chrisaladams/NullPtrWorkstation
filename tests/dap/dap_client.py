#!/usr/bin/env python3
"""Minimal Debug Adapter Protocol client used by the nullptr test-suite.

Drives a DAP adapter (stdio or TCP) through: initialize -> launch -> setBreakpoints
-> configurationDone -> wait for 'stopped' -> stackTrace -> scopes -> variables
-> next (step) -> stackTrace -> continue -> disconnect, and prints a JSON report.

  dap_client.py --stdio "gdb --interpreter=dap" --program BIN --source SRC --line N --var NAME
  dap_client.py --tcp 127.0.0.1:58870 --program ROM --source SRC --line N --var NAME [--launch-extra JSON]
"""
import argparse, json, socket, subprocess, sys, time, shlex

class Conn:
    def __init__(self, r, w): self.r, self.w, self.seq, self.events = r, w, 1, []
    def send(self, command, arguments=None):
        msg = {"seq": self.seq, "type": "request", "command": command}
        if arguments is not None: msg["arguments"] = arguments
        self.seq += 1
        data = json.dumps(msg).encode()
        self.w(b"Content-Length: %d\r\n\r\n" % len(data) + data)
        return msg["seq"]
    def read(self, timeout):
        hdr = b""
        while not hdr.endswith(b"\r\n\r\n"):
            c = self.r(1, timeout)
            if not c: raise TimeoutError("adapter closed")
            hdr += c
        n = int([l for l in hdr.decode().split("\r\n") if l.lower().startswith("content-length")][0].split(":")[1])
        body = b""
        while len(body) < n: body += self.r(n - len(body), timeout)
        return json.loads(body)
    def request(self, command, arguments=None, timeout=30):
        seq = self.send(command, arguments)
        end = time.time() + timeout
        while time.time() < end:
            m = self.read(timeout)
            if m["type"] == "response" and m["request_seq"] == seq: return m
            if m["type"] == "event": self.events.append(m)
            if m["type"] == "request":  # reverse requests (runInTerminal) are not supported
                self.w_resp(m)
        raise TimeoutError(command)
    def w_resp(self, req):
        data = json.dumps({"seq": self.seq, "type": "response", "request_seq": req["seq"], "command": req["command"], "success": False}).encode()
        self.seq += 1; self.w(b"Content-Length: %d\r\n\r\n" % len(data) + data)
    def wait_event(self, name, timeout=60):
        end = time.time() + timeout
        for e in list(self.events):
            if e["event"] == name: self.events.remove(e); return e
        while time.time() < end:
            m = self.read(timeout)
            if m["type"] == "event" and m["event"] == name: return m
            if m["type"] == "event": self.events.append(m)
        raise TimeoutError("event " + name)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--stdio"); ap.add_argument("--tcp")
    ap.add_argument("--program", required=True); ap.add_argument("--source", required=True)
    ap.add_argument("--line", type=int, required=True); ap.add_argument("--var", required=True)
    ap.add_argument("--adapter-id", default="nullptr-test")
    ap.add_argument("--launch-extra", default="{}")
    ap.add_argument("--timeout", type=int, default=60)
    a = ap.parse_args()
    report = {"adapter": a.stdio or a.tcp, "program": a.program, "breakpoint": f"{a.source}:{a.line}"}
    if a.stdio:
        p = subprocess.Popen(shlex.split(a.stdio), stdin=subprocess.PIPE, stdout=subprocess.PIPE, bufsize=0)
        import select, os
        fd = p.stdout.fileno()
        def r(n, t):
            if not select.select([fd], [], [], t)[0]: raise TimeoutError("read")
            return os.read(fd, n)
        def w(b): p.stdin.write(b); p.stdin.flush()
    else:
        host, port = a.tcp.rsplit(":", 1)
        end = time.time() + a.timeout
        while True:
            try: s = socket.create_connection((host, int(port)), timeout=5); break
            except OSError:
                if time.time() > end: raise
                time.sleep(0.5)
        def r(n, t): s.settimeout(t); return s.recv(n)
        def w(b): s.sendall(b)
    c = Conn(r, w)
    init = c.request("initialize", {"adapterID": a.adapter_id, "clientID": "nullptr-test", "linesStartAt1": True,
                                    "columnsStartAt1": True, "pathFormat": "path", "supportsVariableType": True})
    report["initialize"] = init["success"]
    launch_args = {"program": a.program, "stopOnEntry": False}
    launch_args.update(json.loads(a.launch_extra))
    seq = c.send("launch", launch_args)
    try: c.wait_event("initialized", a.timeout)
    except TimeoutError: pass
    bp = c.request("setBreakpoints", {"source": {"path": a.source}, "breakpoints": [{"line": a.line}]})
    report["setBreakpoints"] = bp.get("body", {}).get("breakpoints")
    c.request("configurationDone", {})
    stopped = c.wait_event("stopped", a.timeout)
    report["stopped_reason"] = stopped["body"].get("reason")
    tid = stopped["body"].get("threadId", 1)
    st = c.request("stackTrace", {"threadId": tid, "levels": 20})["body"]["stackFrames"]
    report["stop_location"] = {"name": st[0].get("name"), "line": st[0].get("line"), "source": (st[0].get("source") or {}).get("path") or (st[0].get("source") or {}).get("name")}
    report["call_stack"] = [f.get("name") for f in st[:6]]
    scopes = c.request("scopes", {"frameId": st[0]["id"]})["body"]["scopes"]
    found = {}
    for sc in scopes:
        vs = c.request("variables", {"variablesReference": sc["variablesReference"]})["body"]["variables"]
        for v in vs:
            if v["name"] == a.var: found = {"scope": sc["name"], "value": v["value"], "type": v.get("type")}
    report["variable"] = {a.var: found or "NOT FOUND"}
    c.request("next", {"threadId": tid})
    s2 = c.wait_event("stopped", a.timeout)
    st2 = c.request("stackTrace", {"threadId": s2["body"].get("threadId", tid), "levels": 1})["body"]["stackFrames"]
    report["after_step_line"] = st2[0].get("line")
    c.request("continue", {"threadId": tid})
    try:
        s3 = c.wait_event("stopped", 15)
        st3 = c.request("stackTrace", {"threadId": s3["body"].get("threadId", tid), "levels": 1})["body"]["stackFrames"]
        report["after_continue_stopped_again_at_line"] = st3[0].get("line")
    except TimeoutError:
        report["after_continue_stopped_again_at_line"] = None
    try: c.request("disconnect", {"terminateDebuggee": True}, timeout=10)
    except Exception: pass
    report["PASS"] = (report["stop_location"]["line"] == a.line and found != {})
    print(json.dumps(report, indent=2))
    sys.exit(0 if report["PASS"] else 1)

if __name__ == "__main__":
    main()
