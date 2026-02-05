# Configuration Guide

This document explains how to configure the local Kubernetes cluster.

## Prerequisites

Before running Terraform, ensure you have:

1. **Multipass** installed from https://multipass.run/install
2. **Terraform** installed from https://developer.hashicorp.com/terraform/install
3. **SSH keys** generated (see below)

## SSH Key Setup

Generate SSH keys in the standard Windows location:

```powershell
ssh-keygen -t rsa -b 4096 -f "$env:USERPROFILE\.ssh\kse_ci_cd_sec_id_rsa" -N ""
```

Verify the keys exist:
```powershell
Get-ChildItem $env:USERPROFILE\.ssh
```

You should see:
- `kse_ci_cd_sec_id_rsa` (private key)
- `kse_ci_cd_sec_id_rsa.pub` (public key)

## Configuration Variables

All variables can be customized when running `terraform apply`:

### VM Resources

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `cpu` | number | 2 | Number of CPU cores per VM |
| `mem` | string | "2G" | Memory per VM (e.g., "2G", "4G") |
| `disk` | string | "10G" | Disk size per VM (e.g., "10G", "20G") |

### Cluster Size

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `masters` | number | 1 | Number of control plane nodes (1 or 3+) |
| `workers` | number | 3 | Number of worker nodes |

### Kubernetes Version

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `kube_version` | string | "1.32.11-1.1" | Kubernetes version (apt package version) |
| `kube_minor_version` | string | "1.32" | Kubernetes minor version for apt repository |

### SSH Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `ssh_key_name` | string | "kse_ci_cd_sec_id_rsa" | SSH key name (without extension) |

## Usage Examples

### Basic Cluster (Default)

```bash
cd prepare-local-k8s/scripts/windows
terraform init
terraform apply
```

Creates: 1 master + 3 workers + 1 HAProxy

### High Availability Cluster

```bash
terraform apply -var="masters=3"
```

Creates: 3 masters + 3 workers + 1 HAProxy

### Custom Resources

```bash
terraform apply -var="cpu=4" -var="mem=4G" -var="disk=20G"
```

### Minimal Cluster (for limited resources)

```bash
terraform apply -var="workers=1" -var="mem=2G"
```

Creates: 1 master + 1 worker + 1 HAProxy

### Using Different SSH Keys

```bash
terraform apply -var="ssh_key_name=my_custom_key"
```

Uses `~/.ssh/my_custom_key` and `~/.ssh/my_custom_key.pub`

### All Custom Values

```bash
terraform apply \
  -var="masters=3" \
  -var="workers=5" \
  -var="cpu=4" \
  -var="mem=8G" \
  -var="disk=50G" \
  -var="kube_version=1.32.11-1.1"
```

## Accessing the Cluster

After successful provisioning, the kubeconfig is saved to:
```
$env:USERPROFILE\.kube\config-multipass
```

Set the KUBECONFIG environment variable:
```powershell
$env:KUBECONFIG = "$env:USERPROFILE\.kube\config-multipass"
```

Or use it with kubectl directly:
```powershell
kubectl --kubeconfig="$env:USERPROFILE\.kube\config-multipass" get nodes
```

## SSH Access to VMs

List all VMs:
```powershell
multipass list
```

SSH to HAProxy:
```powershell
ssh -i "$env:USERPROFILE\.ssh\kse_ci_cd_sec_id_rsa" root@<haproxy-ip>
```

SSH to a master node:
```powershell
ssh -i "$env:USERPROFILE\.ssh\kse_ci_cd_sec_id_rsa" root@<master-0-ip>
```

## HAProxy Stats

Access HAProxy statistics dashboard:
```
http://<haproxy-ip>/stats
```

Credentials:
- Username: `hapuser`
- Password: `password!1234`

## Cleanup

To destroy the cluster and all VMs:

```powershell
cd prepare-local-k8s/scripts/windows
.\reset.ps1
```

This will:
1. Run `terraform destroy`
2. Remove any orphaned Multipass VMs
3. Clean up local state files

## Troubleshooting

### VM Creation Fails

Check Multipass status:
```powershell
multipass list
```

Check Hyper-V is enabled:
```powershell
Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V
```

### SSH Connection Refused

1. Wait for cloud-init to complete (can take 5-10 minutes)
2. Verify SSH key permissions
3. Check VM is running: `multipass info <vm-name>`

### Kubernetes Init Fails

Check cloud-init logs on the master:
```bash
ssh root@<master-ip> 'cat /var/log/cloud-init-output.log'
```

Check kubeadm logs:
```bash
ssh root@<master-ip> 'cat /tmp/kubeadm.log'
```

### Nodes Not Ready

Check Calico pods:
```bash
kubectl get pods -n calico-system
```

Check node conditions:
```bash
kubectl describe node <node-name>
```
