terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Stato remoto su S3, per lavorare in più persone: togliere il commento dopo aver creato il bucket.
  # use_lockfile = lock nativo di S3 (Terraform 1.10+), non serve più la tabella DynamoDB.
  # backend "s3" {
  #   bucket       = "nome-del-mio-bucket-terraform"
  #   key          = "esempi/aws-ec2/terraform.tfstate"
  #   region       = "eu-central-1"
  #   use_lockfile = true
  # }
}

# profile "default": le credenziali configurate con "aws configure" (file ~/.aws/credentials)
provider "aws" {
  profile = "default"
  region  = var.region

  default_tags { # etichette messe in automatico su ogni risorsa: si ritrovano nella console e nella fattura
    tags = {
      Progetto  = "bashbash"
      GestitoDa = "terraform"
    }
  }
}

# l'ID di un'immagine (AMI) cambia per ogni regione e a ogni aggiornamento:
# invece di scriverlo a mano lo cerco, prendendo l'Ubuntu 24.04 più recente pubblicata da Canonical
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

# la MIA chiave pubblica SSH caricata su AWS: senza, sull'istanza non si entra
resource "aws_key_pair" "chiave" {
  key_name   = "${var.instance_name}-chiave"
  public_key = file(pathexpand(var.ssh_public_key_path)) # pathexpand trasforma ~ nella home
}

# il firewall dell'istanza: di default AWS blocca tutto il traffico in ingresso.
# Le regole sono risorse separate (il modo consigliato): si aggiungono e tolgono senza ricreare il gruppo.
resource "aws_security_group" "web" {
  name        = "${var.instance_name}-web"
  description = "SSH dal mio IP, HTTP da tutti, tutto in uscita"
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.web.id
  description       = "SSH"
  cidr_ipv4         = var.ssh_allowed_cidr
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.web.id
  description       = "HTTP"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "tutto" {
  security_group_id = aws_security_group.web.id
  description       = "Tutto in uscita: serve per apt"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # tutti i protocolli
}

resource "aws_instance" "app_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.chiave.key_name
  vpc_security_group_ids = [aws_security_group.web.id]

  # script eseguito da cloud-init al primo avvio, come root: installa nginx e scrive la pagina
  user_data = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y nginx
    echo "<h1>${var.instance_name}</h1><p>Creata da Terraform</p>" > /var/www/html/index.html
  EOF
  # user_data gira solo al primo avvio: se lo modifico, l'istanza va ricreata
  user_data_replace_on_change = true

  tags = {
    Name = var.instance_name
  }
}
