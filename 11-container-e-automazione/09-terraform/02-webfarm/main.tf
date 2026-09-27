# Una piccola web farm in Docker: N web server nginx dietro un HAProxy, su una rete dedicata.
# Quanti server e cosa dicono lo decide la variabile "web": aggiungere un server = aggiungere una riga.
#   terraform init && terraform apply     -> http://localhost:8090, statistiche su http://localhost:8404/stats

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

locals {
  # label su ogni container: docker ps --filter label=progetto=webfarm li trova tutti
  etichette = {
    progetto   = var.progetto
    gestito-da = "terraform"
  }
}

resource "docker_network" "rete" {
  name = "${var.progetto}-rete"
}

resource "docker_image" "nginx" {
  name         = "nginx:${var.versione_nginx}"
  keep_locally = true # destroy non cancella l'immagine: la usano anche altri esempi
}

resource "docker_image" "haproxy" {
  name         = "haproxy:lts-alpine"
  keep_locally = true
}

# for_each: un container per ogni elemento della mappa var.web.
# each.key è il nome del server ("web1"), each.value il messaggio della sua pagina.
# L'indirizzo in Terraform è docker_container.web["web1"]: togliere web1 non tocca web2.
resource "docker_container" "web" {
  for_each = var.web

  name  = "${var.progetto}-${each.key}"
  image = docker_image.nginx.image_id

  networks_advanced {
    name    = docker_network.rete.id
    aliases = [each.key] # nella rete risponde anche al nome "web1": è quello che usa HAProxy
  }

  # scrive un file nel container prima di avviarlo; se il contenuto cambia, il container va ricreato
  upload {
    file    = "/usr/share/nginx/html/index.html"
    content = "<h1>${each.key}</h1><p>${each.value}</p>\n"
  }

  # dynamic: genera un blocco "labels" per ogni elemento di local.etichette
  dynamic "labels" {
    for_each = local.etichette
    content {
      label = labels.key
      value = labels.value
    }
  }
}

resource "docker_container" "lb" {
  name  = "${var.progetto}-lb"
  image = docker_image.haproxy.image_id

  ports {
    internal = 80
    external = var.porta
  }
  ports {
    internal = 8404
    external = var.porta_statistiche
  }

  networks_advanced {
    name = docker_network.rete.id
  }

  # la configurazione di HAProxy generata dal template, con una riga "server" per ogni web server
  upload {
    file = "/usr/local/etc/haproxy/haproxy.cfg"
    content = templatefile("${path.module}/haproxy.cfg.tftpl", {
      server = keys(var.web) # ["web1", "web2"]
    })
  }

  dynamic "labels" {
    for_each = local.etichette
    content {
      label = labels.key
      value = labels.value
    }
  }

  # HAProxy risolve i nomi dei server una volta sola, all'avvio: deve partire DOPO i web server.
  # Terraform non può dedurlo, perché il template contiene solo dei nomi e nessun riferimento alle risorse.
  depends_on = [docker_container.web]

  lifecycle {
    # e se un web server viene ricreato (nuovo IP), HAProxy va ricreato con lui
    replace_triggered_by = [docker_container.web]
  }
}
