resource "aws_ecs_cluster" "this" {
  name = "${var.environment}-ecs-cluster"

}

resource "aws_security_group" "ecs" {
  name        = "${var.environment}-ecs-sg"
  description = "Security group for ECS Services"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = var.api_gateway_container_port
    to_port         = var.api_gateway_container_port
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  ingress {
    from_port = 8081
    to_port   = 8086
    protocol  = "tcp"
    self      = true
  }

  ingress {
    from_port = 9000
    to_port   = 9001
    protocol  = "tcp"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "ecs" {
  name = "${var.environment}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Effect = "Allow"
        Sid    = ""
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs-policy-attachment-main" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.ecs.name
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_iam_role_policy" "ecs_logs_policy" {
  name = "${var.environment}-ecs-logs-policy"
  role = aws_iam_role.ecs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/${var.environment}-api-gateway",
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/${var.environment}-api-gateway:*"
        ]
      }
    ]
  })
}

resource "aws_ecs_task_definition" "api_gateway" {
  family                   = "${var.environment}-api-gateway"
  requires_compatibilities = var.ecs_task_requires_compatibilities
  task_role_arn            = aws_iam_role.ecs.arn
  execution_role_arn       = aws_iam_role.ecs.arn
  network_mode             = var.ecs_network_mode
  cpu                      = var.api_gateway_cpu
  memory                   = var.api_gateway_memory

  container_definitions = jsonencode([
    {
      name      = "api-gateway"
      image     = var.api_gateway_image
      cpu       = var.api_gateway_cpu
      memory    = var.api_gateway_memory
      essential = true
      portMappings = [
        {
          containerPort = var.api_gateway_container_port
          hostPort      = var.api_gateway_container_port
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/${var.environment}-api-gateway"
          awslogs-region        = "eu-west-2"
          awslogs-stream-prefix = "ecs"
          awslogs-create-group  = "true"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "api_gateway" {
  name                = "${var.environment}-api-gateway"
  launch_type         = var.ecs_launch_type
  platform_version    = var.ecs_platform_version
  cluster             = aws_ecs_cluster.this.id
  task_definition     = aws_ecs_task_definition.api_gateway.arn
  scheduling_strategy = var.ecs_scheduling_strategy
  desired_count       = var.api_gateway_desired_count

  network_configuration {
    assign_public_ip = false
    security_groups  = [aws_security_group.ecs.id]
    subnets          = var.private-subnet-ids
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "api-gateway"
    container_port   = var.api_gateway_container_port
  }

  lifecycle {
    ignore_changes = [
      task_definition,
      desired_count,
    ]
  }
}
