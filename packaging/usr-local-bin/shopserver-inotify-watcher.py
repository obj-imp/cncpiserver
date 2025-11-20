#!/usr/bin/env python3
import subprocess, time, os, sys
WATCH_DIR="/srv/shopserver"
LOG="/var/log/shopserver-access.log"
cmd = ["inotifywait","-m","-r","-e","open,close_write,create,delete,modify", WATCH_DIR]
p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
with open(LOG,"a") as fh:
    while True:
        line = p.stdout.readline()
        if not line:
            time.sleep(0.1); continue
        ts = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        fh.write(f"{ts} {line}")
        fh.flush()
