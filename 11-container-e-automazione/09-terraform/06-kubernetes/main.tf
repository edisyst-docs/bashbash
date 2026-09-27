# Lo stesso sito del laboratorio Kubernetes 01, descritto in HCL invece che in YAML:
# Terraform crea namespace, ConfigMap, Deployment e Service nel cluster kind "lab".
#   kind create cluster --config ../../06-kubernetes/kind-cluster.yaml    (se non esiste già)
#   terraform init && terraform apply     -> http://localhost:30086

terraform {
  required_version = ">= 1.6"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }
  }
}

# le credenziali sono quelle di kubectl: il kubeconfig e il contesto creato da kind
provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = var.contesto
}

locals {
  etichette = {
    app          = "sito"
    "gestito-da" = "terraform"
  }
}

resource "kubernetes_namespace_v1" "ns" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_config_map_v1" "pagina" {
  metadata {
    name      = "pagina"
    namespace = kubernetes_namespace_v1.ns.metadata[0].name # riferimento: prima il namespace, poi il resto
  }

  data = {
    "index.html" = "<h1>${var.messaggio}</h1>\n"
  }
}

resource "kubernetes_deployment_v1" "web" {
  metadata {
    name      = "web"
    namespace = kubernetes_namespace_v1.ns.metadata[0].name
    labels    = local.etichette
  }

  spec {
    replicas = var.repliche

    selector {
      match_labels = local.etichette
    }

    template {
      metadata {
        labels = local.etichette
        annotations = {
          # come il checksum di Helm: se la pagina cambia, cambia il template e i Pod ripartono
          "checksum/pagina" = sha256(kubernetes_config_map_v1.pagina.data["index.html"])
        }
      }

      spec {
        container {
          name  = "nginx"
          image = "nginx:${var.versione_nginx}"

          port {
            container_port = 80
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }
            period_seconds = 2
          }

          volume_mount {
            name       = "pagina"
            mount_path = "/usr/share/nginx/html"
          }
        }

        volume {
          name = "pagina"
          config_map {
            name = kubernetes_config_map_v1.pagina.metadata[0].name
          }
        }
      }
    }
  }
  # di default apply aspetta che il rollout finisca (wait_for_rollout = true)
}

resource "kubernetes_service_v1" "web" {
  metadata {
    name      = "web"
    namespace = kubernetes_namespace_v1.ns.metadata[0].name
  }

  spec {
    type     = "NodePort"
    selector = local.etichette

    port {
      port        = 80
      target_port = 80
      node_port   = 30086 # kind-cluster.yaml la porta su localhost:30086
    }
  }
}
