# Valori stampati alla fine di apply e leggibili dopo con "terraform output"

output "instance_id" {
  description = "ID dell'istanza EC2"
  value       = aws_instance.app_server.id
}

output "instance_public_ip" {
  description = "IP pubblico dell'istanza EC2"
  value       = aws_instance.app_server.public_ip
}

output "url" {
  description = "La pagina di nginx (serve un minuto dopo l'apply: cloud-init deve finire)"
  value       = "http://${aws_instance.app_server.public_ip}"
}

output "ssh" {
  description = "Comando per collegarsi all'istanza"
  value       = "ssh ubuntu@${aws_instance.app_server.public_ip}"
}
