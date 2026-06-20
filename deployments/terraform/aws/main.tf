## Creating ECR
resource "aws_ecr_repository" "mcp_server_registry" {
  name                 = var.mcp_server_name
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  image_scanning_configuration {
    scan_on_push = false
  }
  tags = {
    ENVIRONMENT = var.env_tag
  }
}

## Building docker image
resource "docker_image" "mcp_server_image" {
  name = "${var.mcp_server_name}:latest"
  build {
    context    = "../../../"  # Path to your build context directory
    dockerfile = "Dockerfile" # Name of your Dockerfile (defaults to Dockerfile)
    platform   = "linux/arm64/v8"
    # Optional build-time variables
    build_args = {
      ENVIRONMENT = "production"
    }
    # Labels for the built image
    label = {
      "maintainer"  = "sbshobhit00@gmail.com"
      "version"     = "1.0.0"
      "description" = "MCP server image"
    }
  }
  depends_on = [aws_ecr_repository.mcp_server_registry]

  provisioner "local-exec" {
    command = <<-EOT
      # Authenticate Docker to ECR
      aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${aws_ecr_repository.mcp_server_registry.repository_url}
      docker tag "${var.mcp_server_name}:latest" "${aws_ecr_repository.mcp_server_registry.repository_url}:latest"
      docker push ${aws_ecr_repository.mcp_server_registry.repository_url}:latest
    EOT
  }
}

## Creating Cloudwatch log group
resource "aws_cloudwatch_log_group" "fastmcp" {
  name              = "/ecs/fastmcp"
  retention_in_days = 3
  tags = {
    ENVIRONMENT = var.env_tag
  }
}

## Creating Task Execution Role
resource "aws_iam_role" "ecs_role" {
  name = "mcp-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}
## Adding policy to task execution role
resource "aws_iam_role_policy" "ecs_policy" {
  name = "ecs-policy"
  role = aws_iam_role.ecs_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}


# Creating Task Definition
resource "aws_ecs_task_definition" "mcp" {
  family                   = "fastmcp"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64" # Or "X86_64"
  }
  execution_role_arn = aws_iam_role.ecs_role.arn
  task_role_arn      = aws_iam_role.ecs_role.arn
  container_definitions = jsonencode([
    {
      name      = "fastmcp"
      image     = "${aws_ecr_repository.mcp_server_registry.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 8000
          hostPort      = 8000
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.fastmcp.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
      environment = [
        {
          name  = "PYTHONUNBUFFERED"
          value = "1"
        }
      ]
    }
  ])
  depends_on = [aws_ecr_repository.mcp_server_registry]
  tags = {
    ENVIRONMENT = var.env_tag
  }
}

# Creating MCP Cluster
resource "aws_ecs_cluster" "mcp_cluster" {
  name = "${var.mcp_server_name}-cluster"
  tags = {
    ENVIRONMENT = var.env_tag
  }
}

# Setting Capacitor Provider
resource "aws_ecs_cluster_capacity_providers" "mcp_capacity_provider" {
  cluster_name = aws_ecs_cluster.mcp_cluster.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }

}

# Creating ALB
resource "aws_lb" "mcp_alb" {
  name               = "mcp-alb"
  load_balancer_type = "application"

  subnets                    = [aws_subnet.mcp_subnet_a.id, aws_subnet.mcp_subnet_b.id]
  security_groups            = [aws_security_group.mcp_security_group.id]
  enable_deletion_protection = false
  depends_on                 = [aws_security_group.mcp_security_group]
  tags = {
    ENVIRONMENT = var.env_tag
  }
}

# Creating 443 Listener
resource "aws_lb_listener" "mcp_ssl_listener" {
  load_balancer_arn = aws_lb.mcp_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.mcp_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mcp_target_group.arn
  }
  tags = {
    ENVIRONMENT = var.env_tag
  }
}

# Creating 80 Listener to redirect to 443
resource "aws_lb_listener" "mcp_listener" {
  load_balancer_arn = aws_lb.mcp_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
  tags = {
    ENVIRONMENT = var.env_tag
  }
}
# Creating Target Group
resource "aws_lb_target_group" "mcp_target_group" {
  name        = "mcp-lb-tg"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.mcp_vpc.id
  target_type = "ip"
  health_check {
    enabled             = true
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
  tags = {
    ENVIRONMENT = var.env_tag
  }
}
# Creating Service
resource "aws_ecs_service" "fastmcp_service" {
  name            = "fastmcp"
  cluster         = aws_ecs_cluster.mcp_cluster.id
  task_definition = aws_ecs_task_definition.mcp.arn

  desired_count    = 1
  launch_type      = "FARGATE"
  platform_version = "LATEST"

  network_configuration {
    subnets          = [aws_subnet.mcp_subnet_a.id, aws_subnet.mcp_subnet_b.id]
    security_groups  = [aws_security_group.mcp_security_group.id]
    assign_public_ip = true
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.mcp_target_group.arn
    container_name   = "fastmcp"
    container_port   = 8000
  }

  depends_on = [
    aws_ecr_repository.mcp_server_registry, aws_lb_listener.mcp_ssl_listener, docker_image.mcp_server_image, aws_security_group.mcp_security_group
  ]
  tags = {
    ENVIRONMENT = var.env_tag
  }
}

# Creating VPC
resource "aws_vpc" "mcp_vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  tags = {
    ENVIRONMENT = var.env_tag
  }
}
# Internet gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.mcp_vpc.id

  tags = {
    Name = "mcp-igw"
  }
}
# Adding public route
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.mcp_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "mcp-public-rt"
  }
}
# Adding subnet to router
resource "aws_route_table_association" "subnet_1" {
  subnet_id      = aws_subnet.mcp_subnet_a.id
  route_table_id = aws_route_table.public.id
}
# Adding subnet to router
resource "aws_route_table_association" "subnet_2" {
  subnet_id      = aws_subnet.mcp_subnet_b.id
  route_table_id = aws_route_table.public.id
}

# Creating subnet zone 1
resource "aws_subnet" "mcp_subnet_a" {
  vpc_id            = aws_vpc.mcp_vpc.id
  cidr_block        = "10.0.5.0/24"
  availability_zone = "ap-south-1a"
  tags = {
    ENVIRONMENT = var.env_tag
  }
}
# Creating subnet zone 2
resource "aws_subnet" "mcp_subnet_b" {
  vpc_id            = aws_vpc.mcp_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "ap-south-1b"


  tags = {
    ENVIRONMENT = var.env_tag
  }
}

# Creating security group
resource "aws_security_group" "mcp_security_group" {
  name   = "allow_tls"
  vpc_id = aws_vpc.mcp_vpc.id
  tags = {
    ENVIRONMENT = var.env_tag
  }
}

# Adding ingress rules
resource "aws_vpc_security_group_ingress_rule" "allow_http" {
  security_group_id = aws_security_group.mcp_security_group.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "HTTP from public internet"
}
resource "aws_vpc_security_group_ingress_rule" "allow_https" {
  security_group_id = aws_security_group.mcp_security_group.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "HTTPS from public internet"
}
resource "aws_vpc_security_group_ingress_rule" "allow_custom_tcp" {
  security_group_id = aws_security_group.mcp_security_group.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 8000
  ip_protocol       = "tcp"
  description       = "HTTPS from public internet"
}
resource "aws_vpc_security_group_egress_rule" "allow_all_traffic" {
  security_group_id = aws_security_group.mcp_security_group.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # Semantically equivalent to "all protocols"
  description       = "Allow all outbound traffic"
}
