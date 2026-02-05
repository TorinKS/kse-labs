resource "null_resource" "haproxy" {

  triggers = {
    id = data.external.haproxy.result.ip
  }

  connection {
    type        = "ssh"
    host        = data.external.haproxy.result.ip
    user        = "root"
    private_key = file(pathexpand("~/.ssh/id_rsa"))
  }

  provisioner "file" {
    source      = local_file.haproxy_initial_cfg.filename
    destination = "/etc/haproxy/haproxy.cfg"
  }

  provisioner "remote-exec" {
    inline = [
      "systemctl restart haproxy"
    ]
  }

  provisioner "local-exec" {
    command = <<CMD
echo ${data.external.haproxy.result.ip} haproxy >> /tmp/hosts_ip.txt
CMD
  }
}
