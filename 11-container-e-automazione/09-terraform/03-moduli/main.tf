# Un modulo locale (modules/sito) usato più volte: una volta a mano, poi una volta per ogni ambiente.
#   terraform init && terraform apply     -> http://localhost:8091, 8092, 8093

terraform {
  required_version = ">= 1.6"
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 4.0"
    }
  }
}

provider "docker" {}

# un'immagine sola per tutti i siti: la crea la radice e la passa ai moduli
resource "docker_image" "nginx" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

# una chiamata al modulo: source dice dove sta, gli altri argomenti sono le sue variabili
module "blog" {
  source = "./modules/sito"

  nome     = "blog"
  porta    = 8091
  titolo   = "Il mio blog"
  immagine = docker_image.nginx.image_id
}

# for_each anche sui moduli: un'istanza per ogni ambiente di var.ambienti
module "ambiente" {
  source   = "./modules/sito"
  for_each = var.ambienti

  nome     = each.key
  porta    = each.value.porta
  titolo   = "Ambiente di ${each.key}"
  colore   = each.value.colore
  immagine = docker_image.nginx.image_id
}
