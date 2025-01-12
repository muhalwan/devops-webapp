provider "aws" {
  region = var.aws_region
}

# Data source to fetch available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "devops-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "devops-igw"
  }
}

# Public Subnets in different AZs with unique CIDR blocks
resource "aws_subnet" "public" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  map_public_ip_on_launch = true

  tags = {
    Name = "devops-public-subnet-${count.index + 1}"
  }
}

# Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "devops-public-route-table"
  }
}

# Associate Route Table with Public Subnets
resource "aws_route_table_association" "public_assoc" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Security Group for ALB
resource "aws_security_group" "alb_sg" {
  name        = "alb_security_group"
  description = "Allow HTTP inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "HTTP from anywhere"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    description      = "Allow all outbound traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "alb-security-group"
  }
}

# Security Group for ECS Tasks
resource "aws_security_group" "ecs_sg" {
  name        = "ecs_security_group"
  description = "Allow inbound traffic from ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "HTTP from ALB"
    from_port        = var.container_port
    to_port          = var.container_port
    protocol         = "tcp"
    security_groups  = [aws_security_group.alb_sg.id]
  }

  egress {
    description      = "Allow all outbound traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "ecs-security-group"
  }
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "ecs-task-execution-role"
  }
}

# Attach the managed policy using aws_iam_role_policy_attachment
resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# CloudWatch Log Group for ECS
resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name              = "/ecs/devops-webapp"
  retention_in_days = 7

  tags = {
    Name = "ecs-log-group"
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "devops_cluster" {
  name = "devops-ecs-cluster"

  tags = {
    Name = "devops-ecs-cluster"
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "devops_task" {
  family                   = "devops-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name         = "devops-container"
      image        = var.docker_image
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        },
      ]
      environment = [
        {
          name  = "PORT"
          value = tostring(var.container_port)
        },
        {
          name  = "DATABASE_URL"
          value = var.database_url
        },
      ]
      essential = true
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_log_group.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    },
  ])

  tags = {
    Name = "devops-task-definition"
  }

  depends_on = [aws_cloudwatch_log_group.ecs_log_group]
}

# Load Balancer
resource "aws_lb" "devops_lb" {
  name               = "devops-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public[*].id  # Associates all public subnets

  tags = {
    Name = "devops-load-balancer"
  }
}

# Target Group
resource "aws_lb_target_group" "devops_tg" {
  name        = "devops-target-group"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"  # Use "ip" since Fargate tasks use awsvpc mode

  health_check {
    path                = var.app_health_check_path
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }

  tags = {
    Name = "devops-target-group"
  }
}

# Load Balancer Listener
resource "aws_lb_listener" "devops_listener" {
  load_balancer_arn = aws_lb.devops_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.devops_tg.arn
  }

  tags = {
    Name = "devops-listener"
  }
}

# ECS Service
resource "aws_ecs_service" "devops_service" {
  name            = "devops-service"
  cluster         = aws_ecs_cluster.devops_cluster.id
  task_definition = aws_ecs_task_definition.devops_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    container_name   = "devops-container"
    container_port   = var.container_port
    target_group_arn = aws_lb_target_group.devops_tg.arn
  }

  depends_on = [aws_lb_listener.devops_listener]

  tags = {
    Name = "devops-ecs-service"
  }
}

# Outputs
output "ecs_cluster_id" {
  description = "ARN of the ECS Cluster"
  value       = aws_ecs_cluster.devops_cluster.id
}

output "ecs_service_name" {
  description = "Name of the ECS Service"
  value       = aws_ecs_service.devops_service.name
}

output "load_balancer_dns" {
  description = "DNS name of the Load Balancer"
  value       = aws_lb.devops_lb.dns_name
}
