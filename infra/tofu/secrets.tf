data "sops_file" "mysql" {
  source_file = "${path.module}/secrets.enc.yaml"
}

resource "kubernetes_secret_v1" "mysql" {
  for_each = toset(["dev", "staging", "prod"])

  metadata {
    name      = "mysql-credentials"
    namespace = kubernetes_namespace_v1.env[each.key].metadata[0].name
  }

  type = "Opaque"

  data = {
    "mysql-password"      = data.sops_file.mysql.data["${each.key}.mysql-password"]
    "mysql-root-password" = data.sops_file.mysql.data["${each.key}.mysql-root-password"]
  }
}

# Adopt the secrets that already exist in the cluster instead of recreating them
import {
  for_each = toset(["dev", "staging", "prod"])
  to       = kubernetes_secret_v1.mysql[each.key]
  id       = "${each.key}/mysql-credentials"
}
