resource "tls_private_key" "bastion" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "bastion_key" {
  key_name   = "${var.cluster_name}-bastion-key"
  public_key = tls_private_key.bastion.public_key_openssh

  tags = {
    Name = "${var.cluster_name}-bastion-key"
  }
}
resource "local_file" "private_key" {
  content         = tls_private_key.bastion.private_key_pem
  filename        = "${path.module}/keys/${var.cluster_name}_bastion_key.pem"
  file_permission = "0600"

}