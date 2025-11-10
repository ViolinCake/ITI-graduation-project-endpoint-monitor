locals {
  bootstrap_script = <<-EOF
              #!/bin/bash
              
              # Update the package manager
              sudo yum update -y
              
              # --- Install kubectl ---
              # Reference: https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html
              echo "Installing kubectl..."
              # Install the required dependencies
              sudo yum install -y curl
              
              # Download and install the latest stable version of kubectl
              curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
              curl -LO "https://dl.k8s.io/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
              echo "$(<kubectl.sha256) kubectl" | sha256sum --check
              sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
              kubectl version --client
              
              # --- Install Helm ---
              # Reference: https://helm.sh/docs/intro/install/
              echo "Installing Helm..."
              curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
              
              # --- Configure AWS CLI (optional, but helpful for EKS API access) ---
              echo "Configuring AWS CLI..."
              # Ensure the latest AWS CLI is available (it often is on AL2023)
              

              # NOTE: You will still need to manually run the 'aws eks update-kubeconfig' command
              # or a script to configure kubectl AFTER the instance is running and the EKS cluster is deployed.
              NON_ROOT_USER="ec2-user" 
              HOME_DIR="/home/$NON_ROOT_USER"

              # 2. Run the command as the non-root user using 'sudo -u'
              # The --kubeconfig flag tells it exactly where to put the file.
              sudo -u $NON_ROOT_USER aws eks update-kubeconfig \
                  --name demo-eks-cluster \
                  --region us-east-1 \
                  --kubeconfig $HOME_DIR/.kube/config
              echo "configuered kubeconfig file in the non-root user home directory"
              # 3. Ensure the non-root user owns the directory (if it didn't exist before)
              chown -R $NON_ROOT_USER:$NON_ROOT_USER $HOME_DIR/.kube
              echo "Bastion setup complete. You must SSH in and run 'aws eks update-kubeconfig --name <cluster-name> --region <region>' to configure kubectl."


              echo "installing eksctl tool..."
              curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz"
              tar -xzf eksctl_$(uname -s)_amd64.tar.gz -C /tmp
              sudo mv /tmp/eksctl /usr/local/bin
              eksctl version
              echo "eksctl instllation done"
  EOF
  base64_user_data=base64encode(local.bootstrap_script)
}