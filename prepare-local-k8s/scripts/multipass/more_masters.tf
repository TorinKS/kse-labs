resource "null_resource" "masters-node" {
  depends_on = [null_resource.workers-node]

  triggers = {
    id = data.external.masters[count.index].result.ip
  }

  connection {
    type        = "ssh"
    host        = data.external.masters[count.index].result.ip
    user        = "root"
    private_key = file(pathexpand("~/.ssh/id_rsa"))
  }

  provisioner "remote-exec" {
    inline = [
      "while [ ! -f /tmp/signal ]; do sleep 2; done"
    ]
  }

  provisioner "local-exec" {
    command = <<CMD
echo ${data.external.masters[count.index].result.ip} master-${count.index + 1} >> /tmp/hosts_ip.txt
CMD
  }
  count = var.masters == 3 ? var.masters - 1 : 0
}
