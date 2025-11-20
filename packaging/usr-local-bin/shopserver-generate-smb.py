#!/usr/bin/env python3
import os, yaml, sys
CONFIG="/etc/shopserver/config.yaml"
SMB_DIR="/etc/samba/smb.d"
REM_FILE=os.path.join(SMB_DIR,"removable.conf")
REM_FILE_SMB1=os.path.join(SMB_DIR,"removable-smb1.conf")
if not os.path.exists(CONFIG):
    print("Config not found", CONFIG); sys.exit(1)
with open(CONFIG) as f:
    cfg = yaml.safe_load(f)
rb = cfg.get("removable_base","/srv/shopserver/removable")
data_user = cfg.get("data_user","pi")

shares=[]
if os.path.isdir(rb):
    idx=1
    for d in sorted(os.listdir(rb)):
        path=os.path.join(rb,d)
        if os.path.ismount(path):
            name = "removable" if idx==1 else f"removable{idx}"
            shares.append((name,path))
            idx+=1

with open(REM_FILE,"w") as fh, open(REM_FILE_SMB1,"w") as fh_smb1:
    if not shares:
        fh.write("# no removable shares currently mounted\n")
        fh_smb1.write("# no removable SMB1 shares currently mounted\n")
    for name,path in shares:
        fh.write(f"""[{name}]
   path = {path}
   read only = no
   browsable = yes
   guest ok = yes
   force user = {data_user}
   create mask = 0775
   directory mask = 2775

""")
        fh_smb1.write(f"""[{name}-smb1]
   path = {path}
   read only = no
   browsable = yes
   guest ok = yes
   force user = {data_user}
   create mask = 0775
   directory mask = 2775
   server min protocol = NT1
   server max protocol = NT1
   lanman auth = yes
   ntlm auth = yes

""")

print(f"Wrote {len(shares)} removable share(s) to {REM_FILE} and {REM_FILE_SMB1}")
