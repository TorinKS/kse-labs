# Network Configuration for Local Kubernetes Cluster

This document describes the network configuration for the local Kubernetes cluster running on Hyper-V via Multipass.

## Overview

The cluster uses a dual-interface network setup:
- **eth0**: Default Switch (DHCP) - required by Multipass, unused for cluster traffic.
- **k8snet**: K8sSwitch (Static IP) - used for all cluster communication. We also in netplan configuration set this name to later get correct ip address for kubeadm configuration.

## Network Topology

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           Windows Host                                   │
│                                                                         │
│  ┌─────────────────┐              ┌─────────────────┐                   │
│  │  Default Switch │              │    K8sSwitch    │                   │
│  │  (Hyper-V)      │              │  (Internal)     │                   │
│  │  DHCP           │              │  192.168.50.1   │                   │
│  └────────┬────────┘              └────────┬────────┘                   │
│           │                                │                            │
│           │                                │ NAT (K8sNAT)               │
│           │                                │ 192.168.50.0/24            │
└───────────┼────────────────────────────────┼────────────────────────────┘
            │                                │
    ┌───────┴────────────────────────────────┴───────┐
    │                                                │
┌───┴───┐  ┌────────┐  ┌────────┐  ┌────────┐  ┌────┴───┐
│haproxy│  │master-0│  │worker-0│  │worker-1│  │   ...  │
│eth0   │  │eth0    │  │eth0    │  │eth0    │  │        │
│k8snet │  │k8snet  │  │k8snet  │  │k8snet  │  │        │
└───────┘  └────────┘  └────────┘  └────────┘  └────────┘
```

## Static IP Allocation

| Node     | Interface | Static IP       | MAC Address        |
|----------|-----------|-----------------|-------------------|
| haproxy  | k8snet    | 192.168.50.10   | 52:54:00:c8:32:0a |
| master-0 | k8snet    | 192.168.50.11   | 52:54:00:c8:32:0b |
| master-1 | k8snet    | 192.168.50.12   | 52:54:00:c8:32:0c |
| master-2 | k8snet    | 192.168.50.13   | 52:54:00:c8:32:0d |
| worker-0 | k8snet    | 192.168.50.21   | 52:54:00:c8:32:15 |
| worker-1 | k8snet    | 192.168.50.22   | 52:54:00:c8:32:16 |
| worker-N | k8snet    | 192.168.50.2N+1 | 52:54:00:c8:32:XX |

## Why Dual Interfaces?

Multipass **always** attaches the Default Switch as the first interface. This is a limitation of Multipass - it cannot be disabled. The `--network` flag adds an additional interface, it doesn't replace the default one.

To work around this, we:
1. Keep eth0 (Default Switch) with DHCP but **disable routes and DNS**
2. Configure k8snet (K8sSwitch) with static IP and **default route**

This ensures all traffic flows through k8snet while eth0 remains inactive for routing purposes.

## One-Time Network Setup

Before creating the cluster, run the setup script as Administrator:

```powershell
.\prepare-local-k8s\scripts\windows\setup-network.ps1
```

This script creates:
1. **K8sSwitch** - Hyper-V Internal Switch
2. **K8sNAT** - NAT for internet access from VMs
3. **Gateway IP** - 192.168.50.1 on the Windows host

### Verification Commands

```powershell
# Check switch exists
Get-VMSwitch K8sSwitch

# Check NAT exists
Get-NetNat K8sNAT

# Check gateway IP on host
Get-NetIPAddress | Where-Object { $_.IPAddress -like "192.168.50.*" }
```

## MAC Address Generation

MAC addresses are deterministically generated based on the IP suffix:

```hcl
# Format: 52:54:00:c8:32:XX where XX is the IP suffix in hex
mac_prefix  = "52:54:00"
haproxy_mac = "${mac_prefix}:c8:32:${format("%02x", var.haproxy_ip_suffix)}"
```

The `52:54:00` prefix is commonly used for virtual NICs (QEMU/KVM convention).

## Netplan Configuration

Each VM has a netplan configuration at `/etc/netplan/99-static.yaml`:

```yaml
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
      dhcp4-overrides:
        use-routes: false    # Don't use eth0 for routing
        use-dns: false       # Don't use eth0's DNS servers
    k8snet:
      match:
        macaddress: "52:54:00:c8:32:0b"  # Match by MAC address
      set-name: k8snet                    # Rename interface to k8snet
      addresses:
        - 192.168.50.11/24
      routes:
        - to: default
          via: 192.168.50.1              # All traffic through K8sSwitch
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
      dhcp4: false
```

### Key Configuration Details

1. **`match: macaddress`** - Identifies the correct interface by MAC address instead of relying on interface name (eth0, eth1) which can vary
2. **`set-name: k8snet`** - Renames the matched interface to `k8snet` for consistency
3. **`dhcp4-overrides`** on eth0 - Prevents Default Switch from adding routes or DNS, ensuring all traffic uses k8snet

## Multipass Launch Command

VMs are launched with the `--network` flag to attach the K8sSwitch:

```powershell
multipass launch --name master-0 \
  --cpus 2 --disk 10G --memory 2G \
  --network name=K8sSwitch,mode=manual,mac=52:54:00:c8:32:0b \
  --cloud-init cloud-init.yaml
```

- `name=K8sSwitch` - Attach to our internal switch
- `mode=manual` - Don't configure the interface automatically (we use netplan)
- `mac=52:54:00:c8:32:0b` - Assign specific MAC address

## Kubernetes Configuration

### API Server Advertisement

The master node's `kube-init.sh` script determines the correct IP:

```bash
export LOCAL_IP=$(ip -4 addr show k8snet 2>/dev/null | \
  grep -oP '(?<=inet\s)192\.168\.50\.\d+' || \
  ip -4 addr show eth1 2>/dev/null | \
  grep -oP '(?<=inet\s)192\.168\.50\.\d+' || \
  hostname -I | awk '{print $1}')
```

This ensures kubeadm uses the static IP for:
- `--apiserver-advertise-address`
- API server certificate SANs

### Control Plane Endpoint

The cluster uses HAProxy as the control plane endpoint:

```bash
kubeadm init \
  --control-plane-endpoint 192.168.50.10:6443 \
  --apiserver-advertise-address 192.168.50.11 \
  ...
```

### Node Internal IPs

All nodes register with their static IPs:

```
NAME       INTERNAL-IP
master-0   192.168.50.11
worker-0   192.168.50.21
worker-1   192.168.50.22
```

## HAProxy Configuration

HAProxy serves as a load balancer for:
1. **Kubernetes API** (port 6443)
2. **Ingress HTTP** (port 80)
3. **Ingress HTTPS** (port 443)

### Initial Configuration (API only)

During cluster bootstrap, HAProxy only routes Kubernetes API traffic:

```
frontend k8s-api
  bind :6443
  mode tcp
  default_backend k8s-api-backend

backend k8s-api-backend
  mode tcp
  server master-0 192.168.50.11:6443 check
```

### Final Configuration (API + Ingress)

After NGINX Ingress is installed, HAProxy is updated to include ingress backends:

```
frontend k8s-api
  bind :6443
  mode tcp
  default_backend k8s-api-backend

backend k8s-api-backend
  mode tcp
  server master-0 192.168.50.11:6443 check

frontend ingress-http
  bind :80
  mode tcp
  default_backend ingress-http-backend

backend ingress-http-backend
  mode tcp
  server worker-0 192.168.50.21:30080 check
  server worker-1 192.168.50.22:30080 check

frontend ingress-https
  bind :443
  mode tcp
  default_backend ingress-https-backend

backend ingress-https-backend
  mode tcp
  server worker-0 192.168.50.21:30443 check
  server worker-1 192.168.50.22:30443 check
```

### HAProxy Stats

Stats page available at: `http://192.168.50.10:8080/stats`
- Username: `hapuser`
- Password: `password!1234`

## NGINX Ingress Controller

### Installation

NGINX Ingress is installed via Terraform Helm provider:

```hcl
resource "helm_release" "nginx_ingress" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true

  set {
    name  = "controller.service.type"
    value = "NodePort"
  }

  set {
    name  = "controller.service.nodePorts.http"
    value = "30080"
  }

  set {
    name  = "controller.service.nodePorts.https"
    value = "30443"
  }
}
```

### Traffic Flow

```
Internet/Client
       │
       ▼
┌──────────────┐
│   HAProxy    │  192.168.50.10
│  :80  :443   │
└──────┬───────┘
       │
       ▼ (NodePort)
┌──────────────────────────────────┐
│     Worker Nodes                 │
│  :30080 (HTTP)  :30443 (HTTPS)   │
└──────┬───────────────────────────┘
       │
       ▼
┌──────────────┐
│ NGINX Ingress│
│  Controller  │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│  Application │
│    Pods      │
└──────────────┘
```

### Using nip.io for DNS

nip.io provides wildcard DNS that resolves to embedded IP addresses:

```
myapp.192.168.50.10.nip.io  →  192.168.50.10
api.192.168.50.10.nip.io    →  192.168.50.10
```

### Example Ingress Resource

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: myapp.192.168.50.10.nip.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-service
            port:
              number: 80
```

### Verify Ingress Installation

```bash
# Check ingress controller pods
kubectl get pods -n ingress-nginx

# Check ingress service (should show NodePort 30080/30443)
kubectl get svc -n ingress-nginx

# Test from Windows host
curl http://192.168.50.10
# Should return 404 (no ingress rules configured yet)
```

## Troubleshooting

### Check Interface Configuration

```bash
# On any VM
ip -4 addr show
ip route show

# Should show:
# - eth0: 172.x.x.x (DHCP, no default route)
# - k8snet: 192.168.50.x (static, default route)
```

### Verify Default Route

```bash
ip route | grep default
# Should show: default via 192.168.50.1 dev k8snet
```

### Test Connectivity

```bash
# From VM to gateway
ping 192.168.50.1

# From VM to internet
ping 8.8.8.8

# From Windows host to VM
ping 192.168.50.10
```

### Check Kubernetes Node IPs

```bash
kubectl get nodes -o wide
# INTERNAL-IP column should show 192.168.50.x addresses
```

### Verify API Server Certificate

```bash
ssh root@192.168.50.11 \
  "openssl x509 -in /etc/kubernetes/pki/apiserver.crt -text -noout | grep -A1 'Subject Alternative Name'"
# Should include 192.168.50.10 (HAProxy IP)
```

## Configuration Variables

In `variables.tf`:

| Variable           | Default       | Description                          |
|--------------------|---------------|--------------------------------------|
| network_switch     | K8sSwitch     | Hyper-V switch name                  |
| network_gateway    | 192.168.50.1  | Gateway IP (Windows host)            |
| network_prefix     | 192.168.50    | First 3 octets of subnet             |
| haproxy_ip_suffix  | 10            | HAProxy IP = prefix.10               |
| master_ip_start    | 11            | Masters start at prefix.11           |
| worker_ip_start    | 21            | Workers start at prefix.21           |

## Files Involved

| File                        | Purpose                                    |
|-----------------------------|--------------------------------------------|
| setup-network.ps1           | One-time Hyper-V switch/NAT setup          |
| variables.tf                | IP/MAC address generation                  |
| versions.tf                 | Provider config (Kubernetes, Helm)         |
| multipass.ps1               | VM launch with --network flag              |
| cloud-init.yaml             | Netplan config for K8s nodes               |
| cloud-init-haproxy.yaml     | Netplan config for HAProxy                 |
| template.tf                 | Passes IPs/MACs to templates               |
| data.tf                     | Passes MACs to multipass.ps1               |
| kube-init.sh                | Determines LOCAL_IP for kubeadm            |
| ingress.tf                  | NGINX Ingress Helm installation            |
| haproxy.cfg.tpl             | HAProxy config (API only)                  |
| haproxy-ingress.cfg.tpl     | HAProxy config (API + Ingress)             |
