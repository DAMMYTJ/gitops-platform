terraform {
  required_version = ">= 1.6"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.30"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "k3d-platform-lab"
}

resource "kubernetes_namespace_v1" "env" {
  for_each = toset(["dev", "staging", "prod"])

  metadata {
    name = each.key
    labels = {
      environment = each.key
    }
  }
}
