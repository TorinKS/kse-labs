resource "local_file" "cloud_init_haproxy" {
  filename = "${path.module}/cloud-init-haproxy.yaml"
  content = templatefile("${path.module}/script/cloud-init-haproxy.yaml", {
    ssh_public_key = file(local.ssh_public_key)
  })
}

resource "local_file" "cloud_init_master" {
  filename = "${path.module}/cloud-init-master.yaml"
  content = templatefile("${path.module}/script/cloud-init.yaml", {
    k_version       = var.kube_version,
    k_minor_version = var.kube_minor_version,
    ssh_public_key  = file(local.ssh_public_key),
    extra_cmd       = "",
    haproxy_ip      = data.external.haproxy.result.ip
  })
}

resource "local_file" "cloud_init_masters" {
  count    = var.masters >= 3 ? 1 : 0
  filename = "${path.module}/cloud-init-masters.yaml"
  content = templatefile("${path.module}/script/cloud-init.yaml", {
    k_version       = var.kube_version,
    k_minor_version = var.kube_minor_version,
    ssh_public_key  = file(local.ssh_public_key),
    extra_cmd       = "${data.external.kubejoin-master.result.join} --cri-socket unix:///var/run/cri-dockerd.sock",
    haproxy_ip      = ""
  })
}

# Generate individual cloud-init files for each worker
resource "local_file" "cloud_init_worker" {
  count    = var.workers
  filename = "${path.module}/cloud-init-worker-${count.index}.yaml"
  content = templatefile("${path.module}/script/cloud-init.yaml", {
    k_version       = var.kube_version,
    k_minor_version = var.kube_minor_version,
    ssh_public_key  = file(local.ssh_public_key),
    extra_cmd       = "${data.external.kubejoin.result.join} --cri-socket unix:///var/run/cri-dockerd.sock",
    haproxy_ip      = ""
  })
}

resource "local_file" "haproxy_initial_cfg" {
  filename = "${path.module}/haproxy_initial.cfg"
  content = templatefile("${path.module}/script/haproxy.cfg.tpl", {
    master-0 = data.external.master[0].result.ip,
    master-1 = "",
    master-2 = ""
  })
}

resource "local_file" "haproxy_final_cfg" {
  filename = "${path.module}/haproxy_final.cfg"
  content = templatefile("${path.module}/script/haproxy.cfg.tpl", {
    master-0 = data.external.master[0].result.ip,
    master-1 = var.masters > 1 ? data.external.masters[0].result.ip : "",
    master-2 = var.masters > 2 ? data.external.masters[1].result.ip : ""
  })
  count = var.masters == 3 ? 1 : 0
}

# HAProxy config with ingress backends (installed after NGINX Ingress)
resource "local_file" "haproxy_ingress_cfg" {
  filename = "${path.module}/haproxy_ingress.cfg"
  content = templatefile("${path.module}/script/haproxy-ingress.cfg.tpl", {
    master-0 = data.external.master[0].result.ip,
    master-1 = var.masters > 1 ? data.external.masters[0].result.ip : "",
    master-2 = var.masters > 2 ? data.external.masters[1].result.ip : "",
    workers  = [for w in data.external.workers : w.result.ip]
  })
}
