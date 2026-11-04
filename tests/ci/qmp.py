#!/usr/bin/env python3
"""Tiny QMP client for the CI VM: type text on the guest keyboard, press key combos, take
screenshots.

  qmp.py SOCKET type "text\\n"          (\\n = Enter; US keyboard layout)
  qmp.py SOCKET key ctrl-alt-f2        (one combo, qcodes joined by '-')
  qmp.py SOCKET shot out.png
  qmp.py SOCKET quit
"""
import json, socket, sys, time

SHIFTED = {'_': 'minus', '>': 'dot', '<': 'comma', '|': 'backslash', '&': '7', ':': 'semicolon',
           '$': '4', '"': 'apostrophe', '~': 'grave_accent', '*': '8', '(': '9', ')': '0',
           '+': 'equal', '!': '1', '@': '2', '#': '3', '%': '5', '^': '6', '{': 'bracket_left',
           '}': 'bracket_right', '?': 'slash'}
PLAIN = {'-': 'minus', '/': 'slash', '.': 'dot', ' ': 'spc', ';': 'semicolon', '=': 'equal',
         "'": 'apostrophe', ',': 'comma', '[': 'bracket_left', ']': 'bracket_right',
         '\\': 'backslash', '`': 'grave_accent', '\n': 'ret', '\t': 'tab'}


class QMP:
    def __init__(self, path):
        self.s = socket.socket(socket.AF_UNIX)
        self.s.connect(path)
        self.f = self.s.makefile('rw')
        json.loads(self.f.readline())  # greeting
        self.cmd('qmp_capabilities')

    def cmd(self, name, **args):
        self.f.write(json.dumps({'execute': name, 'arguments': args} if args else {'execute': name}) + '\n')
        self.f.flush()
        while True:
            r = json.loads(self.f.readline())
            if 'return' in r or 'error' in r:
                if 'error' in r:
                    raise RuntimeError(r['error'])
                return r['return']

    def keys(self, qcodes, hold_ms=60):
        self.cmd('send-key', keys=[{'type': 'qcode', 'data': q} for q in qcodes], **{'hold-time': hold_ms})
        time.sleep(0.04)

    def type(self, text):
        for ch in text:
            if 'a' <= ch <= 'z' or '0' <= ch <= '9':
                self.keys([ch])
            elif 'A' <= ch <= 'Z':
                self.keys(['shift', ch.lower()])
            elif ch in PLAIN:
                self.keys([PLAIN[ch]])
            elif ch in SHIFTED:
                self.keys(['shift', SHIFTED[ch]])
            else:
                raise ValueError('cannot type %r' % ch)


def main():
    q = QMP(sys.argv[1])
    op = sys.argv[2]
    if op == 'type':
        q.type(sys.argv[3].encode().decode('unicode_escape'))
    elif op == 'key':
        q.keys(sys.argv[3].split('-'))
    elif op == 'shot':
        q.cmd('screendump', filename=sys.argv[3], format='png')
    elif op == 'quit':
        q.cmd('quit')
    else:
        sys.exit('unknown op ' + op)


if __name__ == '__main__':
    main()
