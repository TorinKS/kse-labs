# How It Works

This document provides a detailed explanation of the provisioning process.

## Overview

The infrastructure is provisioned using:
- **Terraform** - Infrastructure as Code (IaC) tool
- **Multipass** - Lightweight VM manager (uses Hyper-V on Windows)
- **cloud-init** - VM initialization and configuration
- **kubeadm** - Kubernetes cluster bootstrapping

## Provisioning Flow

```mermaid
flowchart TD
    subgraph step1["1. Generate Templates"]
        t1["cloud-init-haproxy.yaml"]
        t2["cloud-init-master.yaml"]
        t3["cloud-init-masters.yaml<br/>(for HA)"]
        t4["cloud-init-workers.yaml"]
        t5["haproxy_initial.cfg"]
    end

    subgraph step2["2. Create VMs (via Multipass)"]
        haproxy["haproxy VM"] --> haproxy_init["cloud-init runs"] --> haproxy_done["HAProxy installed"]
        master0["master-0 VM"] --> master0_init["cloud-init runs"] --> master0_done["Docker/kubeadm installed"]
    end

    subgraph step3["3. Initialize Kubernetes"]
        ki1["kubeadm init"]
        ki2["Install Weave Net CNI"]
        ki3["Generate join tokens"]
        ki1 --> ki2 --> ki3
    end

    subgraph step4["4. Create Additional Nodes"]
        masters["master-N VMs"] --> masters_join["kubeadm join<br/>(control-plane)"]
        workers["worker-N VMs"] --> workers_join["kubeadm join<br/>(worker)"]
    end

    subgraph step5["5. Post-Configuration"]
        pc1["Update /etc/hosts<br/>on all nodes"]
        pc2["Update HAProxy config<br/>with all masters"]
        pc3["Copy kubeconfig<br/>to local machine"]
        pc1 --> pc2 --> pc3
    end

    step1 --> step2 --> step3 --> step4 --> step5

    style step1 fill:#ddd,stroke:#333
    style step2 fill:#f96,stroke:#333
    style step3 fill:#6af,stroke:#333
    style step4 fill:#9f6,stroke:#333
    style step5 fill:#ddd,stroke:#333
```

## Detailed Steps

### Step 1: Template Generation

Terraform generates cloud-init YAML files using the `templatefile()` function.

**template.tf** creates:
- Injects SSH public key into cloud-init configs
- Sets Kubernetes version
- Configures HAProxy IP for control plane endpoint

### Step 2: VM Creation

VMs are created using Multipass via PowerShell scripts.

**multipass.ps1** handles:
```powershell
multipass launch --name <vm-name> \
  --cpus <cpu> \
  --memory <mem> \
  --disk <disk> \
  --cloud-init <cloud-init.yaml>
```

The `data.external` resources fetch VM IP addresses using:
```powershell
multipass info <vm-name> --format json | ConvertFrom-Json
```

### Step 3: Cloud-Init Execution

When each VM boots, cloud-init executes the configuration:

```mermaid
flowchart TD
    subgraph cloudinit["Cloud-Init Execution Order"]
        bootcmd["bootcmd<br/>(runs early)"]
        packages["packages<br/>(apt install)"]
        write_files["write_files<br/>(create configs)"]
        runcmd["runcmd<br/>(execute commands)"]

        bootcmd --> packages --> write_files --> runcmd
    end

    subgraph bootcmd_details["bootcmd Details"]
        b1["Configure DNS (8.8.8.8)"]
        b2["Add Docker apt repo"]
        b3["Add Kubernetes apt repo"]
    end

    subgraph packages_details["packages Details"]
        p1["kubeadm, kubelet, kubectl"]
        p2["docker-ce"]
        p3["jq, make, ntp"]
    end

    subgraph write_files_details["write_files Details"]
        w1["/etc/modules-load.d/k8s.conf"]
        w2["/etc/sysctl.d/k8s.conf"]
        w3["/etc/docker/daemon.json"]
    end

    subgraph runcmd_details["runcmd Details"]
        r1["Load kernel modules"]
        r2["Apply sysctl settings"]
        r3["Compile cri-dockerd"]
        r4["Enable cri-docker socket"]
    end

    bootcmd -.-> bootcmd_details
    packages -.-> packages_details
    write_files -.-> write_files_details
    runcmd -.-> runcmd_details

    style cloudinit fill:#6af,stroke:#333
```

**For Kubernetes Nodes (cloud-init.yaml):**

1. **bootcmd** (runs early, before networking):
   - Configure DNS (8.8.8.8)
   - Add Docker and Kubernetes apt repositories

2. **packages** (install via apt):
   - kubeadm, kubelet, kubectl
   - docker-ce
   - Required utilities (jq, make, ntp)

3. **write_files** (create config files):
   - `/etc/modules-load.d/k8s.conf` - Kernel modules
   - `/etc/sysctl.d/k8s.conf` - Sysctl settings
   - `/etc/docker/daemon.json` - Docker configuration

4. **runcmd** (execute commands):
   - Load kernel modules (br_netfilter, overlay, ip_vs, etc.)
   - Apply sysctl settings
   - Download and compile cri-dockerd
   - Enable cri-docker socket

**For HAProxy (cloud-init-haproxy.yaml):**
- Install haproxy package
- Configure root SSH access

### Step 4: Kubernetes Initialization

After cloud-init completes, Terraform runs **kube-init.sh** on master-0:

```mermaid
flowchart TD
    wait["cloud-init status --wait"] --> pull["kubeadm config images pull"]
    pull --> init["kubeadm init<br/>--control-plane-endpoint HAPROXY_IP:6443"]
    init --> kubeconfig["Setup kubeconfig<br/>cp admin.conf ~/.kube/config"]
    kubeconfig --> weave["Install Weave Net CNI"]
    weave --> ready["Wait for node Ready"]
    ready --> tokens["Generate join tokens"]

    style init fill:#6af,stroke:#333
    style weave fill:#9f6,stroke:#333
```

```bash
# 1. Wait for cloud-init
cloud-init status --wait

# 2. Pull container images
kubeadm config images pull --cri-socket unix:///var/run/cri-dockerd.sock

# 3. Initialize cluster
kubeadm init \
  --upload-certs \
  --pod-network-cidr 10.244.0.0/16 \
  --apiserver-advertise-address $LOCAL_IP \
  --control-plane-endpoint $HAPROXY_IP:6443 \
  --cri-socket unix:///var/run/cri-dockerd.sock

# 4. Setup kubeconfig
mkdir -p $HOME/.kube
cp /etc/kubernetes/admin.conf $HOME/.kube/config

# 5. Install Weave Net CNI
kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml

# 6. Generate join tokens
kubeadm token create --print-join-command > /etc/join.json
```

### Step 5: Node Joining

```mermaid
flowchart LR
    subgraph master0["Master-0 (192.168.50.11)"]
        token["Join Token"]
        cert["Certificate Key"]
    end

    subgraph workers["Workers (default: 2)"]
        w0["worker-0<br/>192.168.50.21"]
        w1["worker-1<br/>192.168.50.22"]
    end

    subgraph masters["Additional Masters (HA mode)"]
        m1["master-1"]
        m2["master-2"]
    end

    token --> w0
    token --> w1

    token --> m1
    token --> m2
    cert --> m1
    cert --> m2

    style master0 fill:#6af,stroke:#333
    style workers fill:#9f6,stroke:#333
    style masters fill:#6af,stroke:#333
```

**Workers** join using the token from master-0:
```bash
kubeadm join <haproxy-ip>:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash <hash> \
  --cri-socket unix:///var/run/cri-dockerd.sock
```

**Additional Masters** join with the certificate key:
```bash
kubeadm join <haproxy-ip>:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash <hash> \
  --control-plane \
  --certificate-key <cert-key> \
  --cri-socket unix:///var/run/cri-dockerd.sock
```

### Step 6: DNS Configuration

After all nodes are created, Terraform updates `/etc/hosts` on every node:

```
<haproxy-ip>  haproxy
<master-0-ip> master-0
<master-1-ip> master-1
<worker-0-ip> worker-0
...
```

This allows nodes to resolve each other by hostname.

### Step 7: HAProxy Final Configuration

The HAProxy configuration is updated in two phases:

**Initial config** (during bootstrap): Only Kubernetes API routing
```
frontend k8s-api
  bind :6443
  mode tcp
  default_backend k8s-api-backend

backend k8s-api-backend
  mode tcp
  server master-0 <master-0-ip>:6443 check
  server master-1 <master-1-ip>:6443 check  # if HA mode
  server master-2 <master-2-ip>:6443 check  # if HA mode
```

**Final config** (after NGINX Ingress is installed): Adds HTTP/HTTPS routing to workers
```
frontend ingress-http
  bind :80
  mode tcp
  default_backend ingress-http-backend

backend ingress-http-backend
  mode tcp
  server worker-0 <worker-0-ip>:30080 check
  server worker-1 <worker-1-ip>:30080 check

frontend ingress-https
  bind :443
  mode tcp
  default_backend ingress-https-backend

backend ingress-https-backend
  mode tcp
  server worker-0 <worker-0-ip>:30443 check
  server worker-1 <worker-1-ip>:30443 check
```

### Step 8: Kubeconfig Export

The kubeconfig is copied to the local machine:

```powershell
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL \
  root@<master-0-ip>:/etc/kubernetes/admin.conf ~/.kube/config-multipass
Copy-Item ~/.kube/config-multipass ~/.kube/config
```

The `server:` URL in the kubeconfig points to the HAProxy IP (192.168.50.10:6443).

### Step 9: Helm Releases Installation

After the cluster is ready, Terraform deploys applications via Helm:

```mermaid
flowchart TD
    nfs_server["Install NFS Server<br/>on HAProxy VM"] --> postgresql["Install PostgreSQL<br/>on HAProxy VM"]
    postgresql --> nginx["Deploy NGINX Ingress<br/>(Helm 4.12.0)"]
    nginx --> haproxy_update["Update HAProxy config<br/>(add Ingress routes)"]
    haproxy_update --> argocd["Deploy ArgoCD<br/>(Helm 7.7.10)"]
    argocd --> nfs_provisioner["Deploy NFS Provisioner<br/>(Helm 4.0.18)"]
    nfs_provisioner --> prometheus["Deploy Kube-Prometheus-Stack<br/>(Helm 80.14.0)"]

    style nginx fill:#9f6,stroke:#333
    style argocd fill:#9f6,stroke:#333
    style nfs_provisioner fill:#9f6,stroke:#333
    style prometheus fill:#9f6,stroke:#333
```

**Applications deployed:**
| Application | Helm Chart Version | Namespace |
|-------------|-------------------|-----------|
| NGINX Ingress | 4.12.0 | ingress-nginx |
| ArgoCD | 7.7.10 | argocd |
| NFS Provisioner | 4.0.18 | nfs-provisioner |
| Kube-Prometheus-Stack | 80.14.0 | monitoring |

## Terraform Resources

| Resource Type | Purpose |
|--------------|---------|
| `local_file` | Generate cloud-init and haproxy configs |
| `data.external` | Fetch VM IPs via PowerShell |
| `null_resource` | Execute provisioners (SSH, scripts) |
| `helm_release` | Deploy Kubernetes applications |
| `kubernetes_ingress_v1` | Create Ingress resources for applications |

## Key Files

| File | Purpose |
|------|---------|
| `variables.tf` | Input variables and locals |
| `template.tf` | Template file generation |
| `haproxy.tf` | HAProxy VM provisioning |
| `master.tf` | First master node provisioning |
| `more_masters.tf` | Additional master nodes (HA) |
| `workers.tf` | Worker nodes provisioning |
| `dns.tf` | /etc/hosts configuration |
| `kube_config.tf` | Export kubeconfig locally |
| `data.tf` | External data sources for join tokens |
| `ingress.tf` | NGINX Ingress Controller + HAProxy Ingress config |
| `argocd.tf` | ArgoCD deployment |
| `storage.tf` | NFS server, PostgreSQL, NFS Provisioner |
| `monitoring.tf` | Kube-Prometheus-Stack (Prometheus, Grafana, AlertManager) |

## Timing and Dependencies

```mermaid
flowchart TD
    haproxy["haproxy VM"] --> master0["master-0 VM"]
    master0 --> kubeinit["kube-init<br/>(kubeadm + Weave CNI)"]
    kubeinit --> master_dns["master-dns"]

    master0 --> mastersN["masters-N<br/>(if HA)"]
    mastersN --> masters_dns["masters-dns"]

    master0 --> workersN["workers-N"]
    workersN --> workers_dns["workers-dns"]

    master_dns --> haproxy_dns["haproxy-dns"]
    masters_dns --> haproxy_dns
    workers_dns --> haproxy_dns

    haproxy_dns --> kubeconfig["kubeconfig"]

    kubeconfig --> nfs_server["nfs_server<br/>(on HAProxy VM)"]
    nfs_server --> postgresql["postgresql<br/>(on HAProxy VM)"]
    postgresql --> nginx_ingress["nginx_ingress<br/>(Helm)"]
    nginx_ingress --> haproxy_ingress["haproxy_ingress<br/>(update config)"]
    haproxy_ingress --> argocd["argocd<br/>(Helm)"]
    argocd --> nfs_provisioner["nfs_provisioner<br/>(Helm)"]
    nfs_provisioner --> prometheus["kube_prometheus_stack<br/>(Helm)"]

    style haproxy fill:#f96,stroke:#333
    style master0 fill:#6af,stroke:#333
    style mastersN fill:#6af,stroke:#333
    style workersN fill:#9f6,stroke:#333
    style kubeconfig fill:#ddd,stroke:#333
    style nginx_ingress fill:#9f6,stroke:#333
    style argocd fill:#9f6,stroke:#333
    style nfs_provisioner fill:#9f6,stroke:#333
    style prometheus fill:#9f6,stroke:#333
```

The `depends_on` relationships ensure proper ordering during provisioning.
