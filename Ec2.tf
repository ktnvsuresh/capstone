resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow HTTP inbound traffic"
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
resource "tls_private_key" "tlskey1" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "sk-key" {
  key_name   = "sk-key-project1"   # The name of your key pair
  public_key = tls_private_key.tlskey1.public_key_openssh
}

resource "aws_instance" "sk-blue" {
  ami           = "ami-0907008e2c2a9e429"
  instance_type = "t3.micro"
  security_groups = [aws_security_group.allow_http.name]

  key_name = aws_key_pair.sk-key.key_name  

  user_data     = <<-EOF
                  <powershell>
                          Install-WindowsFeature -Name Web-Server
                          Set-Content -Path 'C:\inetpub\wwwroot\index.html' -Value '<html><body style="background-color:blue;"><h1>Welcome to sk website hosted on EC2!</h1></body></html>'
                </powershell>
                 EOF
  tags = {
    Name = "sk-blue"
  }
}

resource "aws_instance" "sk-red" {
  ami           = "ami-0907008e2c2a9e429"
  instance_type = "t3.micro"
  security_groups = [aws_security_group.allow_http.name]

  key_name = aws_key_pair.sk-key.key_name  

  user_data     = <<-EOF
                  <powershell>
                          Install-WindowsFeature -Name Web-Server
                          Set-Content -Path 'C:\inetpub\wwwroot\index.html' -Value '<html><body style="background-color:red;"><h1>Welcome to sk website hosted on EC2!</h1></body></html>'
                </powershell>
                 EOF
  tags = {
    Name = "sk-red"
  }
}
resource "aws_lb_target_group" "app_tg" {
  name     = "app-tg"
  port     = 80
  protocol = "HTTP"
  target_type = "instance"
  vpc_id   = "vpc-0c668882a12e0e5b1"  # Replace with your VPC ID
}

resource "aws_lb_target_group_attachment" "sk-blu" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.sk-blue.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "sk-red" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.sk-red.id
  port             = 80
}

resource "aws_lb" "app_lb" {
  name               = "app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_http.id]
  subnets            = ["subnet-00e1a0f3de727f4bf", "subnet-0785db0e7f529554e"]  # Replace with your subnet IDs

 
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

output "private_key" {
  value     = tls_private_key.tlskey1.private_key_pem
  sensitive = true
}
