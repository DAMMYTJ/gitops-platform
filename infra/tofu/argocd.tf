provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = "k3d-platform-lab"
  }
}

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  timeout          = 600

  set {
    name  = "dex.enabled"
    value = "false"
  }

  set {
    name  = "notifications.enabled"
    value = "false"
  }
}
