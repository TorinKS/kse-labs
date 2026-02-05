# Platform Comparison: macOS vs Windows

This document outlines the key differences between the macOS and Windows implementations of the Terraform Kubernetes Multipass project.

## Key Differences

### 1. External Program Execution

**macOS:**
```hcl
data "external" "haproxy" {
  program = ["python3", "${path.module}/script/multipass.py"]
  ...
}
```

**Windows:**
```hcl
data "external" "haproxy" {
  program = ["pwsh", "-File", "${path.module}/script/multipass.ps1"]
  ...
}
```

### 2. SSH Key Paths

**macOS:**
- Uses `pathexpand("~/.ssh/id_rsa")`
- Resolves to `/Users/<username>/.ssh/id_rsa`

**Windows:**
- Uses `"${path.root}/.ssh/id_rsa"` or `"$env:USERPROFILE\.ssh\id_rsa"` in PowerShell
- Resolves to `C:\Users\<username>\.ssh\id_rsa`

### 3. Local-Exec Provisioners

**macOS:**
```hcl
provisioner "local-exec" {
  command = <<CMD
echo ${data.external.haproxy.result.ip} haproxy >> /tmp/hosts_ip.txt
CMD
}
```

**Windows:**
```hcl
provisioner "local-exec" {
  command     = "echo ${data.external.haproxy.result.ip} haproxy >> $env:TEMP\\hosts_ip.txt"
  interpreter = ["pwsh", "-Command"]
}
```

### 4. Temporary File Locations

| Platform | Location |
|----------|----------|
| macOS | `/tmp/hosts_ip.txt` |
| Windows | `%TEMP%\hosts_ip.txt` (e.g., `C:\Users\<user>\AppData\Local\Temp\hosts_ip.txt`) |

### 5. Kube Config Setup

**macOS:**
```hcl
provisioner "local-exec" {
  command = <<CMD
mkdir ${pathexpand("~/.kube")}
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${pathexpand("~/.ssh/id_rsa")} root@${data.external.master[0].result.ip}:/etc/kubernetes/admin.conf ${pathexpand("~/.kube/config-multipass")}
CMD
}
```

**Windows:**
```hcl
provisioner "local-exec" {
  command = <<CMD
if (!(Test-Path "$env:USERPROFILE\.kube")) { New-Item -ItemType Directory -Path "$env:USERPROFILE\.kube" -Force }
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -i "$env:USERPROFILE\.ssh\id_rsa" root@${data.external.master[0].result.ip}:/etc/kubernetes/admin.conf "$env:USERPROFILE\.kube\config-multipass"
CMD
  interpreter = ["pwsh", "-Command"]
}
```

### 6. VM Management Scripts

**macOS:**
- `script/multipass.py` - Python 3 script
- Uses subprocess module
- Unix-style path handling

**Windows:**
- `script/multipass.ps1` - PowerShell script
- Uses native PowerShell cmdlets
- Windows-style path handling with `\`

### 7. Reset/Cleanup Scripts

**macOS (`reset-macos.sh`):**
```bash
#!/bin/bash
multipass delete --all
multipass purge
rm multipass/cloud-init-*.yaml
rm multipass/haproxy_*.cfg
rm terraform.tfstate
rm /tmp/hosts_ip.txt
rm ~/.kube/config-multipass
```

**Windows (`reset-windows.ps1`):**
```powershell
multipass delete --all
multipass purge
Remove-Item -Path "cloud-init-*.yaml" -ErrorAction SilentlyContinue
Remove-Item -Path "haproxy_*.cfg" -ErrorAction SilentlyContinue
Remove-Item -Path "terraform.tfstate*" -ErrorAction SilentlyContinue
Remove-Item -Path "$env:TEMP\hosts_ip.txt" -ErrorAction SilentlyContinue
Remove-Item -Path "$env:USERPROFILE\.kube\config-multipass" -ErrorAction SilentlyContinue
```

### 8. DNS Configuration File Transfer

**macOS:**
```hcl
provisioner "file" {
  source      = "/tmp/hosts_ip.txt"
  destination = "/tmp/hosts_ip.txt"
}
```

**Windows:**
```hcl
provisioner "file" {
  source      = "$env:TEMP\\hosts_ip.txt"
  destination = "/tmp/hosts_ip.txt"
}
```

## Common Components

Both platforms share the same:
- Cloud-init YAML files (cloud-init.yaml, cloud-init-haproxy.yaml)
- HAProxy configuration template (haproxy.cfg.tpl)
- Kubernetes initialization script (kube-init.sh) - runs inside Linux VMs
- Terraform variable definitions
- Overall cluster architecture

## Implementation Notes

### macOS Implementation
- More mature Unix-based tooling
- Direct Python integration
- Simpler path handling
- Native bash support

### Windows Implementation
- PowerShell-first approach
- Windows-native path handling
- Requires PowerShell 5.1+
- SSH client must be available (built-in Windows 10+)

## Migration Between Platforms

To switch from one platform to another:

1. Destroy existing infrastructure:
   ```bash
   # On macOS
   cd macos && terraform destroy
   
   # On Windows
   cd windows && terraform destroy
   ```

2. Run the appropriate reset script:
   ```bash
   # macOS
   ./reset-macos.sh
   
   # Windows
   .\reset-windows.ps1
   ```

3. Deploy on the new platform:
   ```bash
   # New platform
   cd <platform> && terraform init && terraform apply
   ```

## Best Practices

1. **Use platform-appropriate paths** - Don't hardcode Unix paths on Windows or vice versa
2. **Test both platforms** - When adding features, ensure compatibility with both
3. **Document platform differences** - Update this file when adding platform-specific features
4. **Use consistent variable names** - Keep variable definitions identical across platforms
5. **Leverage cloud-init** - Most VM configuration is platform-agnostic via cloud-init
