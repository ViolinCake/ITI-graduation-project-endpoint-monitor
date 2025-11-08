# # Kubernetes resources commented out - to be deployed from bastion host
# # These resources require access to the private EKS cluster

# # Create namespace for Jenkins
# resource "kubernetes_namespace" "jenkins" {
#   metadata {
#     name = "jenkins"
#   }
#   depends_on = [aws_eks_cluster.eks_cluster]
# }

# # Create service account for Jenkins
# resource "kubernetes_service_account" "jenkins" {
#   metadata {
#     name      = "jenkins"
#     namespace = kubernetes_namespace.jenkins.metadata[0].name
#   }
#   depends_on = [kubernetes_namespace.jenkins]
# }

# # Create cluster role binding for Jenkins
# resource "kubernetes_cluster_role_binding" "jenkins" {
#   metadata {
#     name = "jenkins-admin"
#   }
#   role_ref {
#     api_group = "rbac.authorization.k8s.io"
#     kind      = "ClusterRole"
#     name      = "cluster-admin"
#   }
#   subject {
#     kind      = "ServiceAccount"
#     name      = kubernetes_service_account.jenkins.metadata[0].name
#     namespace = kubernetes_namespace.jenkins.metadata[0].name
#   }
#   depends_on = [kubernetes_service_account.jenkins]
# }

# # Install Jenkins using Helm
# resource "helm_release" "jenkins" {
#   name       = "jenkins"
#   repository = "https://charts.jenkins.io"
#   chart      = "jenkins"
#   namespace  = kubernetes_namespace.jenkins.metadata[0].name

#   values = [
#     <<-EOT
#     controller:
#       serviceType: LoadBalancer
#       adminUser: "admin"
#       adminPassword: "admin123"  # Change this in production
#       resources:
#         requests:
#           cpu: "500m"
#           memory: "512Mi"
#         limits:
#           cpu: "2000m"
#           memory: "2048Mi"
#     persistence:
#       enabled: true
#       size: "10Gi"
#     EOT
#   ]

#   depends_on = [
#     kubernetes_namespace.jenkins,
#     kubernetes_service_account.jenkins
#   ]
# }

# # Output Jenkins URL
# output "jenkins_url" {
#   description = "Jenkins URL"
#   value       = "http://${data.kubernetes_service.jenkins.status.0.load_balancer.0.ingress.0.hostname}"
#   depends_on  = [helm_release.jenkins]
# }

# # Data source to get Jenkins service details
# data "kubernetes_service" "jenkins" {
#   metadata {
#     name      = "jenkins"
#     namespace = kubernetes_namespace.jenkins.metadata[0].name
#   }
#   depends_on = [helm_release.jenkins]
# }
# resource "helm_release" "jenkins" {
#   name = "jenkins"
#   repository = "https://charts.jenkins.io/"
#   chart = "jenkins"
#   namespace = "jenkins"
#   create_namespace = true
#   values = [file("jenkins-values.yaml")]
# }