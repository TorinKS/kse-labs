import os
import sys
import json
import subprocess
import tempfile
import time
import random

def log(msg):
    with open("multipass.log", "a") as f:
        f.write("%s\n" % msg)

def find_vm(name):
    cmd = ["multipass", "list", "--format=json"]
    out = subprocess.check_output(cmd)
    vms = json.loads(out)
    for vm in vms["list"]:
        if vm["name"] == name:
            return {
                "name": name,
                "ip": vm["ipv4"][0],
                "release": vm["release"],
                "state": vm["state"]
            }
    return None

def create_vm(name, cpu, mem, disk, data, image):
    temp = tempfile.NamedTemporaryFile(delete=False)
    with open(temp.name, "w") as f:
        f.write(data)
    cmd = ["multipass", "launch",
            "--name", name,
            "--cpus", cpu,
            "--disk", disk,
            "--memory", mem,
            "--timeout", "1800",
            "--cloud-init", temp.name,
            image]
    res = subprocess.check_output(cmd)
    log("%s: %s" %(cmd, res))
    os.remove(temp.name)
    return find_vm(name)

inp = json.loads(sys.stdin.read())
name = inp["name"]
mem = inp["mem"]
disk = inp["disk"]
cpu = inp["cpu"]
data = inp["init"]
image = inp.get("image", "22.04")  # Default to Ubuntu 22.04
res = find_vm(name)
if not res:
    time.sleep(random.randrange(1, 10))
    res = create_vm(name, cpu, mem, disk, data, image)

print(json.dumps(res))
