terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# profile "default": le credenziali configurate con "aws configure" (file ~/.aws/credentials)
provider "aws" {
  profile = "default"
  region  = var.region
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

resource "aws_instance" "app_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  tags = {
    Name = var.instance_name
  }
}
