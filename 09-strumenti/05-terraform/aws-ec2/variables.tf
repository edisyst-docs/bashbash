# Variabili con il loro valore di default.
# Si sovrascrivono in terraform.tfvars, con -var "nome=valore" o con variabili d'ambiente TF_VAR_nome.

variable "region" {
  description = "Regione AWS"
  type        = string
  default     = "eu-south-1" # Milano
}

variable "instance_type" {
  description = "Tipo (dimensione) dell'istanza EC2"
  type        = string
  default     = "t3.micro"
}

variable "instance_name" {
  description = "Valore del tag Name dell'istanza EC2"
  type        = string
  default     = "MyNewInstance"
}
