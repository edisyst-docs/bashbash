# gli output di un modulo si leggono come module.NOME.OUTPUT
output "blog" {
  value = module.blog.url
}

output "ambienti" {
  value = { for nome, sito in module.ambiente : nome => sito.url }
}
