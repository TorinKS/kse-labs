variable "disk" {
  default     = "10G"
  type        = string
  description = "Disk size assigned to vms"
}
variable "worker_disk" {
  default     = "15G"
  type        = string
  description = "Disk size assigned to worker nodes"
}
variable "haproxy_disk" {
  default     = "30G"
  type        = string
  description = "Disk size assigned to HAProxy VM (includes NFS storage)"
}
variable "mem" {
  default     = "2G"
  type        = string
  description = "Memory assigned to vms"
}
variable "master_mem" {
  default     = "4G"
  type        = string
  description = "Memory assigned to master nodes"
}
variable "haproxy_mem" {
  default     = "4G"
  type        = string
  description = "Memory assigned to HAProxy VM"
}
variable "worker_mem" {
  default     = "3G"
  type        = string
  description = "Memory assigned to worker nodes"
}
variable "cpu" {
  default     = 2
  type        = number
  description = "Number of CPU assigned to vms"
}
variable "worker_cpu" {
  default     = 3
  type        = number
  description = "Number of CPU assigned to worker nodes"
}
variable "masters" {
  default     = 1
  type        = number
  description = "Number of control plane nodes"
}
variable "workers" {
  default     = 2
  type        = number
  description = "Number of worker nodes"
}
variable "kube_version" {
  default     = "1.32.11-1.1"
  type        = string
  description = "Version of Kubernetes to use"
}

variable "kube_minor_version" {
  default     = "1.32"
  type        = string
  description = "Kubernetes minor version for apt repository (e.g., 1.32)"
}

variable "ssh_key_name" {
  default     = "id_rsa"
  type        = string
  description = "Name of SSH key files (without extension) in ~/.ssh directory"
}

variable "ubuntu_image" {
  default     = "22.04"
  type        = string
  description = "Ubuntu image version for VMs (e.g., 22.04, 24.04). Run 'multipass find' to see available images."
}

locals {
  ssh_dir         = pathexpand("~/.ssh")
  ssh_private_key = "${local.ssh_dir}/${var.ssh_key_name}"
  ssh_public_key  = "${local.ssh_dir}/${var.ssh_key_name}.pub"
  hosts_ip_file   = "/tmp/hosts_ip.txt"

  # HAProxy IP is dynamically assigned by multipass
  haproxy_ip = data.external.haproxy.result.ip
}
