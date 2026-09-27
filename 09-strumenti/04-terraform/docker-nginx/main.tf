# Esempio che funziona in locale, senza account cloud: un container Nginx gestito da Terraform.
# Serve Docker in esecuzione. terraform apply -> http://localhost:8000

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

# senza parametri usa il Docker locale (su Windows la named pipe di Docker Desktop)
provider "docker" {}

resource "docker_image" "nginx" {
  name         = "nginx:alpine"
  keep_locally = false # con destroy elimina anche l'immagine scaricata
}

resource "docker_container" "nginx" {
  image = docker_image.nginx.image_id # riferimento a un'altra risorsa: Terraform crea prima l'immagine
  name  = "tutorial"

  ports {
    internal = 80
    external = 8000
  }
}
