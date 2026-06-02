data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

data "aws_iam_instance_profile" "existing_profile" {
  name = "LabInstanceProfile"
}

# SSH Key Pair Generation
resource "tls_private_key" "vm_key" { algorithm = "ED25519" }

resource "aws_key_pair" "deployer_key" {
  key_name   = "${var.environment}-key"
  public_key = tls_private_key.vm_key.public_key_openssh
}

resource "local_file" "private_key_pem" {
  content         = tls_private_key.vm_key.private_key_openssh
  filename        = "${path.module}/../../${var.environment}-key.pem"
  file_permission = "0600"
}

# Security Groups
resource "aws_security_group" "public_sg" {
  name   = "${var.environment}-public-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Public VM with WordPress Remote Provisioner
resource "aws_instance" "public_vm" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [aws_security_group.public_sg.id]
  key_name               = aws_key_pair.deployer_key.key_name
  iam_instance_profile   = data.aws_iam_instance_profile.existing_profile.name

  tags = { Name = "${var.environment}-public-vm" }

  # Connection block tells the provisioner how to SSH into the box
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = tls_private_key.vm_key.private_key_openssh
    host        = self.public_ip
  }

  # remote-exec executes scripts directly after OS initialization
  #   provisioner "remote-exec" {
  #     inline = [
  #       "sudo apt-get update -y",
  #       "sudo apt-get install -y apache2 php libapache2-mod-php php-mysql php-pgsql ghostscript libapache2-mod-php php-bcmath php-curl php-imagick php-intl php-json php-mbstring php-xml php-zip",
  #       "sudo mkdir -p /srv/www",
#       "sudo chown demo: /srv/www", # Adjusting folder permissions
  #       "curl https://wordpress.org/latest.tar.gz | sudo tar -xzf - -C /srv/www",
  #       # Setting up basic Apache VirtualHost for WordPress
  #       "echo '<VirtualHost *:80>\nDocumentRoot /srv/www/wordpress\n<Directory /srv/www/wordpress>\nOptions FollowSymLinks\nAllowOverride Limit Options FileInfo\nDirectoryIndex index.php\nRequire all granted\n</Directory>\n</VirtualHost>' | sudo tee /etc/apache2/sites-available/wordpress.conf",
  #       "sudo a2ensite wordpress",
  #       "sudo a2enmod rewrite",
  #       "sudo a2dissite 000-default",
  #       "sudo systemctl restart apache2"
  #     ]
  #   }
}