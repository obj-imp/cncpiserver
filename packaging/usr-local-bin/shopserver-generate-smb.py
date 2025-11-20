#!/usr/bin/env python3
import os, yaml, glob, sys
CONFIG="/etc/shopserver/config.yaml"
SMB_DIR="/etc/samba/smb.d"
if not os.path.exists(CONFIG):
    print("Config not found", CONFIG); sys.exit(1)
with open(CONFIG) as f:
    cfg = yaml.safe_load(f)
rb = cfg.get("removable_base","/srv/shopserver/removable")
# clean old removable*.conf
for f in glob.glob(os.path.join(SMB_DIR,"removable*.conf")):
    try:
        os.remove(f)
    except:
        pass
# build new ones
idx=1
for d in sorted(os.listdir(rb) if os.path.isdir(rb) else []):
    path=os.path.join(rb,d)
    if os.path.ismount(path):
        name = "removable" if idx==1 else f"removable{idx}"
        conf=os.path.join(SMB_DIR,f"{name}.conf")
        with open(conf,"w") as fh:
            fh.write(f"""[{name}]
   path = {path}
   read only = no
   browsable = yes
   guest ok = yes
   force user = pi
   create mask = 0775
   directory mask = 2775
""")
        idx+=1
print("Wrote", idx-1, "removable share(s)")
