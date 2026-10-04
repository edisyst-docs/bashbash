variable "contesto" {
  description = "Contesto del kubeconfig: il cluster su cui lavorare (kubectl config get-contexts)"
  type        = string
  default     = "kind-lab"
}

variable "namespace" {
  description = "Namespace in cui creare tutto"
  type        = string
  default     = "terraform"
}

variable "repliche" {
  description = "Repliche del Deployment"
  type        = number
  default     = 2
}

variable "versione_nginx" {
  description = "Tag dell'immagine nginx"
  type        = string
  default     = "1.27-alpine"
}

variable "messaggio" {
  description = "Il testo della pagina"
  type        = string
  default     = "Creato da Terraform"
}
