# Modulo "sito": un container nginx con una pagina generata da un template.
# Un modulo è una cartella di file .tf come le altre: variables.tf sono i suoi input, outputs.tf i suoi output.

terraform {
  required_providers {
    docker = {
      source = "kreuzwerker/docker" # il modulo dice quale provider usa; la versione la fissa la configurazione radice
    }
  }
}

resource "docker_container" "sito" {
  name  = "sito-${var.nome}"
  image = var.immagine

  ports {
    internal = 80
    external = var.porta
  }

  upload {
    file = "/usr/share/nginx/html/index.html"
    # path.module: la cartella del modulo, ovunque venga chiamato
    content = templatefile("${path.module}/pagina.html.tftpl", {
      nome   = var.nome
      titolo = var.titolo
      colore = var.colore
    })
  }

  labels {
    label = "modulo"
    value = "sito"
  }
}
