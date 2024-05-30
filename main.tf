provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "my_bucket" {
  bucket = "my-unique-bucket-name"
}

resource "aws_s3_bucket_acl" "my_bucket_acl" {
  bucket = aws_s3_bucket.my_bucket.id
  acl    = "private"
}

resource "aws_iam_role" "my_role" {
  name = "my-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com",
        },
      },
    ],
  })
}

resource "aws_iam_policy" "my_policy" {
  name        = "my-policy"
  description = "A sample policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "ec2:Describe*",
        ],
        Effect   = "Allow",
        Resource = "*",
      },
    ],
  })
}

resource "aws_iam_role_policy_attachment" "my_role_policy_attachment" {
  role       = aws_iam_role.my_role.name
  policy_arn = aws_iam_policy.my_policy.arn
}

resource "aws_security_group" "my_sg" {
  name        = "my-sg"
  description = "Allow MySQL inbound traffic"
  vpc_id      = "vpc-089c15423010281b7"  # Replace with your VPC ID

  ingress {
    from_port   = 3306
    to_port     = 3306
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

resource "aws_db_instance" "my_rds" {
  identifier              = "my-rds-instance"
  allocated_storage       = 20
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.t3.micro"
  db_name                 = "mydatabase"
  username                = "admin"
  password                = "password" 
  db_subnet_group_name    = aws_db_subnet_group.my_db_subnet_group.name
  vpc_security_group_ids  = [aws_security_group.my_sg.id]
  skip_final_snapshot     = true
}

resource "aws_db_subnet_group" "my_db_subnet_group" {
  name       = "my-db-subnet-group"
  subnet_ids = ["subnet-00cb2eabaed62a006", "subnet-080f5a7ec976cad72"]

  tags = {
    Name = "My DB Subnet Group"
  }
}

resource "aws_kms_key" "my_kms_key" {
  description = "KMS key for encryption"
}

resource "aws_glue_job" "my_glue_job" {
  name        = "my-glue-job"
  role_arn    = aws_iam_role.my_role.arn
  command {
    name            = "glueetl"
    script_location = "s3://my-unique-bucket-name/scripts/glue_script.py" 
    python_version  = "3"
  }
}

resource "aws_lb" "my_lb" {
  name               = "my-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.my_sg.id]
  subnets            = ["subnet-00cb2eabaed62a006", "subnet-080f5a7ec976cad72"] 

  enable_deletion_protection = false
}

resource "aws_autoscaling_group" "my_asg" {
  desired_capacity     = 1
  max_size             = 2
  min_size             = 1
  vpc_zone_identifier  = ["subnet-00cb2eabaed62a006", "subnet-080f5a7ec976cad72"]
  launch_configuration = aws_launch_configuration.my_launch_config.id
}

resource "aws_launch_configuration" "my_launch_config" {
  name          = "my-launch-config"
  image_id      = "ami-0647086318eb3b918" 
  instance_type = "t2.micro"
  security_groups = [aws_security_group.my_sg.id]

  lifecycle {
    create_before_destroy = true
  }
}
