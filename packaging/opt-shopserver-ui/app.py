from flask import Flask, render_template, send_from_directory
import yaml, os, subprocess, time

app = Flask(__name__, template_folder="templates", static_folder="static")

CONFIG="/etc/shopserver/config.yaml"

def load_config():
    with open(CONFIG) as f:
        return yaml.safe_load(f)

def list_removable():
    rb = load_config().get("removable_base", "/srv/shopserver/removable")
    ret=[]
    if os.path.isdir(rb):
        for d in sorted(os.listdir(rb)):
            p=os.path.join(rb,d)
            if os.path.ismount(p):
                try:
                    stat = os.statvfs(p)
                    free = (stat.f_bavail*stat.f_frsize)//1024
                except:
                    free=0
                ret.append({"name":d,"path":p,"free_kb":free})
    return ret

@app.route("/")
def index():
    cfg = load_config()
    main = {"path":cfg.get("main_path","/srv/shopserver/shopserver")}
    rem = list_removable()
    logtail = []
    try:
        with open("/var/log/shopserver-access.log") as f:
            lines = f.readlines()[-200:]
            logtail = lines[::-1]
    except:
        logtail=[]
    return render_template("index.html", cfg=cfg, main=main, rem=rem, logtail=logtail)

@app.route("/static/<path:p>")
def staticp(p):
    return send_from_directory("static",p)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
