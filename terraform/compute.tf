# ─────────────────────────────────────────────
# Compute Layer — EC2 Instances
# ─────────────────────────────────────────────

# Fetch the latest Amazon Linux 2023 AMI dynamically
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# SSH key pair — uses an existing public key on your machine
resource "aws_key_pair" "lab" {
  key_name   = "threat-lab-key"
  public_key = file(var.public_key_path)
}

# Attacker box — public subnet
resource "aws_instance" "attacker" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.attacker.id]
  key_name               = aws_key_pair.lab.key_name

  tags = { Name = "attacker-box" }
}

# Victim server — private subnet
resource "aws_instance" "victim" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.victim.id]
  key_name               = aws_key_pair.lab.key_name

  tags = { Name = "victim-server" }
}