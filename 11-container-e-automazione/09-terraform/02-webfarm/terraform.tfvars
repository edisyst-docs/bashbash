# Valori per questo ambiente: Terraform legge il file da solo e sovrascrive i default di variables.tf.
# Provare a togliere il commento a web3 e rilanciare terraform plan.
web = {
  web1 = "Primo server"
  web2 = "Secondo server"
  # web3 = "Terzo server"
}
