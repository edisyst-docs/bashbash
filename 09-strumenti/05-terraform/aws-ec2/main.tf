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

# la MIA chiave pubblica SSH caricata su AWS: senza, sull'istanza non si entra
resource "aws_key_pair" "chiave" {
  key_name   = "${var.instance_name}-chiave"
  public_key = file(pathexpand(var.ssh_public_key_path)) # pathexpand trasforma ~ nella home
}

# il firewall dell'istanza: di default AWS blocca tutto il traffico in ingresso
resource "aws_security_group" "ssh" {
  name        = "${var.instance_name}-ssh"
  description = "SSH in ingresso, tutto in uscita"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # tutti i protocolli: serve per apt update
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "app_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.chiave.key_name
  vpc_security_group_ids = [aws_security_group.ssh.id]

  tags = {
    Name = var.instance_name
  }
}
