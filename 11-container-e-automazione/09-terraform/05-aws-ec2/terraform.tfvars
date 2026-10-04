# Valori che sovrascrivono i default di variables.tf: Terraform legge questo file da solo.
# Per scalare o cambiare ambiente si modifica questo file, non main.tf.
instance_type = "t3.micro"
instance_name = "MyNewInstance"
# ssh_allowed_cidr = "203.0.113.50/32" # solo il mio IP (curl -s ifconfig.me)
