output "url" {
  description = "Il bilanciatore"
  value       = "http://localhost:${var.porta}"
}

output "statistiche" {
  description = "La pagina di statistiche di HAProxy"
  value       = "http://localhost:${var.porta_statistiche}/stats"
}

# espressione for: da una mappa di risorse a una mappa nome => IP
output "web_server" {
  description = "Nome e IP di ogni web server nella rete Docker"
  value       = { for nome, c in docker_container.web : nome => c.network_data[0].ip_address }
}
