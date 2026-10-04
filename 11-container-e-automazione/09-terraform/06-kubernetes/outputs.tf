output "url" {
  value = "http://localhost:30086"
}

output "kubectl" {
  description = "Per guardare cosa ha creato"
  value       = "kubectl -n ${kubernetes_namespace_v1.ns.metadata[0].name} get all"
}
