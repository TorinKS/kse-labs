# Quick Start Guide

This guide will help you quickly set up a Kubernetes cluster using Multipass on either macOS or Windows.

## Prerequisites

### All Platforms
1. Install [Multipass](https://multipass.run/)
2. Install [Terraform](https://developer.hashicorp.com/terraform/downloads)
3. Generate SSH keys (if you don't have them):

**macOS/Linux:**
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
```

**Windows:**
```powershell
ssh-keygen -t rsa -b 4096 -f "$env:USERPROFILE\.ssh\id_rsa" -N '""'
```

## macOS / Linux Setup

1. **Navigate to the macOS directory:**
```bash
cd macos
```

2. **Initialize Terraform:**
```bash
terraform init
```

3. **Review the plan:**
```bash
terraform plan
```

4. **Apply the configuration:**
```bash
terraform apply
```

5. **Set up kubectl:**
```bash
export KUBECONFIG=~/.kube/config-multipass
kubectl get nodes
```

6. **Verify the cluster:**
```bash
kubectl get nodes
kubectl get pods -A
```

## Windows Setup

1. **Navigate to the Windows directory:**
```powershell
cd windows
```

2. **Initialize Terraform:**
```powershell
terraform init
```

3. **Review the plan:**
```powershell
terraform plan
```

4. **Apply the configuration:**
```powershell
terraform apply
```

5. **Set up kubectl:**
```powershell
$env:KUBECONFIG = "$env:USERPROFILE\.kube\config-multipass"
kubectl get nodes
```

6. **Verify the cluster:**
```powershell
kubectl get nodes
kubectl get pods -A
```

## Customization

You can customize the cluster by creating a `terraform.tfvars` file in the platform directory:

```hcl
# terraform.tfvars
masters = 3          # Number of master nodes (1 or 3)
workers = 5          # Number of worker nodes
cpu     = 4          # CPU cores per VM
mem     = "4G"       # Memory per VM
disk    = "20G"      # Disk size per VM
kube_version = "1.28.2-1.1"  # Kubernetes version
```

## Accessing the Cluster

### View Cluster Info
```bash
kubectl cluster-info
```

### View All Nodes
```bash
kubectl get nodes -o wide
```

### View All Pods
```bash
kubectl get pods -A
```

### Deploy a Test Application
```bash
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=NodePort
kubectl get services
```

## Troubleshooting

### Check Multipass VMs
**macOS/Linux:**
```bash
multipass list
multipass info <vm-name>
```

**Windows:**
```powershell
multipass list
multipass info <vm-name>
```

### Access a VM
```bash
# macOS/Linux
multipass shell <vm-name>

# Windows
multipass shell <vm-name>
```

### Check Terraform State
```bash
# macOS/Linux
terraform show

# Windows
terraform show
```

### View Logs
**macOS:**
```bash
cat multipass/multipass.log
```

**Windows:**
```powershell
Get-Content windows\multipass.log
```

## Cleanup

### Destroy Infrastructure

**macOS/Linux:**
```bash
cd macos
terraform destroy
cd ..
./reset-macos.sh
```

**Windows:**
```powershell
cd windows
terraform destroy
cd ..
.\reset-windows.ps1
```

## Common Issues

### Issue: SSH Connection Failures
**Solution:** Ensure SSH keys are in the correct location:
- macOS: `~/.ssh/id_rsa` and `~/.ssh/id_rsa.pub`
- Windows: `%USERPROFILE%\.ssh\id_rsa` and `%USERPROFILE%\.ssh\id_rsa.pub`

### Issue: Multipass VM Creation Timeout
**Solution:** Increase timeout or check your system resources. VMs require sufficient CPU, memory, and disk space.

### Issue: Terraform External Program Error
**Solution:** 
- **macOS:** Ensure Python 3 is installed (`python3 --version`)
- **Windows:** Ensure PowerShell is available (`pwsh --version`)

### Issue: kubectl Cannot Connect
**Solution:** Verify KUBECONFIG is set:
```bash
# macOS/Linux
echo $KUBECONFIG

# Windows
echo $env:KUBECONFIG
```

## Next Steps

- [Deploy applications to your cluster](https://kubernetes.io/docs/tutorials/)
- [Install Helm](https://helm.sh/docs/intro/install/)
- [Set up Ingress Controller](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [Configure Persistent Storage](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)

## Support

For issues specific to:
- **Multipass:** https://github.com/canonical/multipass/issues
- **Terraform:** https://github.com/hashicorp/terraform/issues
- **Kubernetes:** https://kubernetes.io/docs/tasks/debug/
