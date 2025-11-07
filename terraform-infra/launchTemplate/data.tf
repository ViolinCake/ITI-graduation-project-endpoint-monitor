# Data source to fetch the EKS cluster details
# data "aws_eks_cluster" "demo" {
#   name = var.cluster_name
# }

locals {
  # This is the essential bootstrap script, using HCL interpolation to insert
  # the cluster name, API endpoint, and CA certificate.
  bootstrap_script = <<-EOF
    #!/bin/bash
    set -ex
    /etc/eks/bootstrap.sh ${var.cluster_name} \
      --b64-cluster-ca ${var.cluster-CA} \
      --apiserver-endpoint ${var.cluster-endpoint}
    EOF

  # Base64 encode the script, as required by the Launch Template
  base64_user_data = base64encode(local.bootstrap_script)
}
