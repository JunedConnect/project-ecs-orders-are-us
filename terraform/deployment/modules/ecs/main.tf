resource "aws_ecs_cluster" "this" {
  name = "${var.environment}-ecs-cluster"

}

resource "aws_security_group" "ecs" {
  name        = "${var.environment}-ecs-sg"
  description = "Security group for ECS Services"
  vpc_id      = var.vpc_id

  # ingress {
  #   from_port = 8080
  #   to_port   = 8086
  #   protocol  = "tcp"
  #   self      = true
  # }

  # ingress {
  #   from_port = 9000
  #   to_port   = 9001
  #   protocol  = "tcp"
  #   self      = true
  # }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.environment}-ecs-task-execution-role"

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

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_iam_role_policy" "ecs_ecr_policy" {
  name = "${var.environment}-ecs-ecr-policy"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/${var.environment}-*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs_logs_policy" {
  name = "${var.environment}-ecs-logs-policy"
  role = aws_iam_role.ecs_task_execution.id

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
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/${var.environment}-*",
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/${var.environment}-*:*"
        ]
      }
    ]
  })
}

resource "aws_iam_role" "ecs_task" {
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

# the below policy is used to allow ECS task Exec (Debugging Purposes)
resource "aws_iam_role_policy" "ecs_ssm_policy" {
  name = "${var.environment}-ecs-ssm-policy"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:ExecuteCommand"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs_sqs_policy" {
  name = "${var.environment}-ecs-sqs-policy"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
        ]
        Resource = [var.sqs_main_queue_arn]
      }
    ]
  })
}