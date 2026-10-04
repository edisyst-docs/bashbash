variable "ambienti" {
  description = "Un sito per ogni ambiente: nome => porta e colore"
  # object: una struttura con campi di tipo fisso; optional() li rende facoltativi, con un default
  type = map(object({
    porta  = number
    colore = optional(string, "#2f855a")
  }))
  default = {
    sviluppo   = { porta = 8092 }
    produzione = { porta = 8093, colore = "#c53030" }
  }
}
