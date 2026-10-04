variable "nome" {
  description = "Nome del sito: il container si chiamerà sito-NOME"
  type        = string
}

variable "porta" {
  description = "Porta del PC"
  type        = number

  validation {
    condition     = var.porta >= 1024 && var.porta <= 65535
    error_message = "Usare una porta fra 1024 e 65535."
  }
}

variable "titolo" {
  description = "Titolo della pagina"
  type        = string
}

variable "colore" {
  description = "Colore di sfondo"
  type        = string
  default     = "#2b6cb0" # senza default la variabile è obbligatoria
}

variable "immagine" {
  description = "ID dell'immagine nginx da usare"
  type        = string
}
