# Laboratorio sullo stato: si segue passo passo il README di questa cartella.
#   terraform init && terraform apply     -> http://localhost:8095

terraform {
  required_version = ">= 1.7" # i blocchi removed sono della 1.7
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 4.0"
    }
  }
}

provider "docker" {}

locals {
  # ogni workspace ha il suo stato: stessi file, infrastrutture separate.
  # terraform.workspace è il nome del workspace attivo; la porta cambia per non scontrarsi.
  porte = {
    default = 8095
    prova   = 8096
  }
  porta = lookup(local.porte, terraform.workspace, 8097) # 8097 per qualunque altro workspace
}

resource "docker_image" "nginx" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

resource "docker_container" "web" {
  name  = "stato-${terraform.workspace}"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = local.porta
  }
}

output "url" {
  value = "http://localhost:${local.porta}"
}
