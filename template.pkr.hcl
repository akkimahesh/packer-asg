packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

# ⚠️ Fixed: Must be an AMI ID (ami-xxxx), NOT an instance ID (i-xxxx)
variable "source_ami" {
  type        = string
  description = "Base OS AMI ID in your AWS region"
  default     = "ami-04b70fa74e45c3917" # Replace with valid AMI ID in your region
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "git_repo" {
  type    = string
  default = "github.com/akkimahesh/fiewin.git"
}

# 🔑 GitHub Personal Access Token for private repo access
variable "github_token" {
  type        = string
  description = "GitHub Personal Access Token (PAT)"
  sensitive   = true
}

source "amazon-ebs" "ubuntu" {
  ami_name      = "my-app-ami-{{timestamp}}"
  instance_type = var.instance_type
  region        = var.aws_region
  source_ami    = var.source_ami
  ssh_username  = "ubuntu"
}

build {
  name    = "app-builder"
  sources = ["source.amazon-ebs.ubuntu"]

  provisioner "shell" {
    inline = [
      "sudo mkdir -p /var/www/app",
      "sudo chown -R ubuntu:ubuntu /var/www/app"
    ]
  }

  # Clone PRIVATE GitHub Repo using Token
  provisioner "shell" {
    inline = [
      "git clone https://${var.github_token}@${var.git_repo} /var/www/app",
      "cd /var/www/app && npm install"
    ]
  }

  # Copy local manual files
  provisioner "file" {
    source      = "./local-files/"
    destination = "/tmp/manual-files"
  }

  # Move manual files into app directory
  provisioner "shell" {
    inline = [
      "echo '=== Copying manual files into application directory ==='",
      "cp -r /tmp/manual-files/* /var/www/app/",
      "rm -rf /tmp/manual-files",
      "sudo chown -R ubuntu:ubuntu /var/www/app"
    ]
  }
}