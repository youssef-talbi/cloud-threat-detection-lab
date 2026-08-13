# ─────────────────────────────────────────────
# Security Groups
# ─────────────────────────────────────────────

# Attacker SG — SSH only from the operator's IP
resource "aws_security_group" "attacker" {
  name        = "attacker-sg"
  description = "Attacker box - SSH from operator only"
  vpc_id      = aws_vpc.lab.id

  ingress {
    description = "SSH from operator"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.operator_ip]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "attacker-sg" }
}

# Victim SG — SSH only from the attacker subnet + internal VPC traffic
resource "aws_security_group" "victim" {
  name        = "victim-sg"
  description = "Victim server - reachable from attacker subnet"
  vpc_id      = aws_vpc.lab.id

  ingress {
    description = "SSH from attacker subnet"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.public_subnet_cidr]
  }

  ingress {
    description = "All traffic within VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "victim-sg" }
}

# Isolated SG — zero inbound, zero outbound (used by Lambda for quarantine)
resource "aws_security_group" "isolated" {
  name        = "isolated-sg"
  description = "Quarantine SG - no traffic allowed"
  vpc_id      = aws_vpc.lab.id

  # No ingress and no egress rules = fully isolated

  tags = { Name = "isolated-sg" }
}