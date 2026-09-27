variable "progetto" {
  description = "Prefisso dei nomi di container e rete"
  type        = string
  default     = "webfarm"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.progetto))
    error_message = "Solo lettere minuscole, cifre e trattini, iniziando con una lettera."
  }
}

variable "web" {
  description = "I web server da creare: nome => messaggio della pagina"
  type        = map(string)
  default = {
    web1 = "Primo server"
    web2 = "Secondo server"
  }

  validation {
    condition     = length(var.web) >= 1 && length(var.web) <= 5
    error_message = "Da 1 a 5 web server."
  }
}

variable "versione_nginx" {
  description = "Tag dell'immagine nginx"
  type        = string
  default     = "1.27-alpine"
}

variable "porta" {
  description = "Porta del PC su cui risponde il bilanciatore"
  type        = number
  default     = 8090

  validation {
    condition     = var.porta >= 1024 && var.porta <= 65535
    error_message = "Usare una porta fra 1024 e 65535."
  }
}

variable "porta_statistiche" {
  description = "Porta del PC per la pagina di statistiche di HAProxy"
  type        = number
  default     = 8404
}
