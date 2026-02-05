data "external" "haproxy" {
  program = ["python3", "${path.module}/script/multipass.py"]
  query = {
    name  = "haproxy"
    cpu   = var.cpu
    mem   = var.haproxy_mem
    disk  = var.haproxy_disk
    image = var.ubuntu_image
    init  = local_file.cloud_init_haproxy.content
  }
}

data "external" "master" {
  program = ["python3", "${path.module}/script/multipass.py"]
  query = {
    name  = "master-${count.index}"
    cpu   = var.cpu
    mem   = var.master_mem
    disk  = var.disk
    image = var.ubuntu_image
    init  = local_file.cloud_init_master.content
  }
  count      = 1
  depends_on = [data.external.haproxy]
}

data "external" "masters" {
  program = ["python3", "${path.module}/script/multipass.py"]
  query = {
    name  = "master-${count.index + 1}"
    cpu   = var.cpu
    mem   = var.master_mem
    disk  = var.disk
    image = var.ubuntu_image
    init  = local_file.cloud_init_masters[0].content
  }
  count      = var.masters >= 3 ? var.masters - 1 : 0
  depends_on = [data.external.master]
}

data "external" "workers" {
  program = ["python3", "${path.module}/script/multipass.py"]
  query = {
    name  = "worker-${count.index}"
    cpu   = var.worker_cpu
    mem   = var.worker_mem
    disk  = var.worker_disk
    image = var.ubuntu_image
    init  = local_file.cloud_init_worker[count.index].content
  }
  count      = var.workers >= 1 ? var.workers : 0
  depends_on = [data.external.masters]
}

data "external" "kubejoin-master" {
  depends_on = [null_resource.master-node]
  program = ["ssh",
    "-i", local.ssh_private_key,
    "-o", "StrictHostKeyChecking=no",
    "-l", "root",
    data.external.master[0].result.ip,
    "cat", "/etc/join-master.json"
  ]
}

data "external" "kubejoin" {
  depends_on = [null_resource.master-node]
  program = ["ssh",
    "-i", local.ssh_private_key,
    "-o", "StrictHostKeyChecking=no",
    "-l", "root",
    data.external.master[0].result.ip,
    "cat", "/etc/join.json"
  ]
}
