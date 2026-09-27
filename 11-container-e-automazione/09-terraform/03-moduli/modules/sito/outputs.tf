output "url" {
  description = "Indirizzo del sito"
  value       = "http://localhost:${var.porta}"
}

output "container" {
  description = "Nome del container"
  value       = docker_container.sito.name
}
