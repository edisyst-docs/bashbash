# Variabili con il loro valore di default.
# Si sovrascrivono in terraform.tfvars, con -var "nome=valore" o con variabili d'ambiente TF_VAR_nome.

variable "region" {
  description = "Regione AWS"
  type        = string
  default     = "eu-central-1" # Francoforte. Milano (eu-south-1) va prima attivata nell'account: Account > Regioni AWS
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

variable "ssh_public_key_path" {
  description = "Chiave pubblica SSH da installare sull'istanza"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "ssh_allowed_cidr" {
  description = "Da quali IP accettare SSH. Meglio il proprio: \"$(curl -s ifconfig.me)/32\""
  type        = string
  default     = "0.0.0.0/0"
}
