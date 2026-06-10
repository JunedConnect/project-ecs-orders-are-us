resource "aws_service_discovery_private_dns_namespace" "this" {
  name = "${var.environment}.internal"
  vpc  = var.vpc_id
}

resource "aws_service_discovery_service" "api_gateway" {
  name = "api-gateway"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.this.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_ecs_task_definition" "api_gateway" {
  family                   = "${var.environment}-api-gateway"
  requires_compatibilities = var.ecs_task_requires_compatibilities
  task_role_arn            = aws_iam_role.ecs_task.arn
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  network_mode             = var.ecs_network_mode
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory

  container_definitions = jsonencode([
    {
      name      = "api-gateway"
      image     = var.api_gateway_image
      cpu       = var.ecs_task_cpu
      memory    = var.ecs_task_memory
      essential = true
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
        }
      ]
      environment = [
        {
          name  = "REDIS_URL"
          value = "redis://${var.elasticache_address}:6379/0"
        },
        {
          name  = "ORDER_SERVICE_URL"
          value = "http://order-service.${aws_service_discovery_private_dns_namespace.this.name}:8081"
        },
        {
          name  = "INVENTORY_SERVICE_URL"
          value = "http://inventory-service.${aws_service_discovery_private_dns_namespace.this.name}:8082"
        },
        {
          name  = "PAYMENT_SERVICE_URL"
          value = "http://payment-service.${aws_service_discovery_private_dns_namespace.this.name}:8083"
        },
        {
          name  = "NOTIFICATION_SERVICE_URL"
          value = "http://notification-service.${aws_service_discovery_private_dns_namespace.this.name}:8084"
        },
        {
          name  = "SHIPPING_SERVICE_URL"
          value = "http://shipping-service.${aws_service_discovery_private_dns_namespace.this.name}:8085"
        },
        {
          name  = "DASHBOARD_SERVICE_URL"
          value = "http://dashboard-api.${aws_service_discovery_private_dns_namespace.this.name}:8086"
        }
      ]
      secrets = [
        {
          name      = "JWT_SECRET"
          valueFrom = aws_secretsmanager_secret_version.api_gateway_jwt_secret.arn
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
  name                   = "${var.environment}-api-gateway"
  launch_type            = var.ecs_launch_type
  platform_version       = var.ecs_platform_version
  cluster                = aws_ecs_cluster.this.id
  task_definition        = aws_ecs_task_definition.api_gateway.arn
  scheduling_strategy    = var.ecs_scheduling_strategy
  desired_count          = var.api_gateway_desired_count
  enable_execute_command = var.enable_execute_command

  network_configuration {
    assign_public_ip = false
    security_groups  = [aws_security_group.ecs.id]
    subnets          = var.private-subnet-ids
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "api-gateway"
    container_port   = 8080
  }

  service_registries {
    registry_arn = aws_service_discovery_service.api_gateway.arn
  }

  lifecycle {
    ignore_changes = [
      task_definition,
      desired_count,
    ]
  }
}

resource "aws_service_discovery_service" "dashboard_api" {
  name = "dashboard-api"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.this.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_ecs_task_definition" "dashboard_api" {
  family                   = "${var.environment}-dashboard-api"
  requires_compatibilities = var.ecs_task_requires_compatibilities
  task_role_arn            = aws_iam_role.ecs_task.arn
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  network_mode             = var.ecs_network_mode
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory

  container_definitions = jsonencode([
    {
      name      = "dashboard-api"
      image     = var.dashboard_api_image
      cpu       = var.ecs_task_cpu
      memory    = var.ecs_task_memory
      essential = true
      portMappings = [
        {
          containerPort = 8086
          hostPort      = 8086
        }
      ]
      secrets = [
        {
          name      = "DATABASE_URL"
          valueFrom = "${var.rds_database_credentials_secret_arn}:url::"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/${var.environment}-dashboard-api"
          awslogs-region        = "eu-west-2"
          awslogs-stream-prefix = "ecs"
          awslogs-create-group  = "true"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "dashboard_api" {
  name                   = "${var.environment}-dashboard-api"
  launch_type            = var.ecs_launch_type
  platform_version       = var.ecs_platform_version
  cluster                = aws_ecs_cluster.this.id
  task_definition        = aws_ecs_task_definition.dashboard_api.arn
  scheduling_strategy    = var.ecs_scheduling_strategy
  desired_count          = var.dashboard_api_desired_count
  enable_execute_command = var.enable_execute_command

  network_configuration {
    assign_public_ip = false
    security_groups  = [aws_security_group.ecs.id]
    subnets          = var.private-subnet-ids
  }

  load_balancer {
    target_group_arn = var.dashboard_target_group_arn
    container_name   = "dashboard-api"
    container_port   = 8086
  }

  service_registries {
    registry_arn = aws_service_discovery_service.dashboard_api.arn
  }

  lifecycle {
    ignore_changes = [
      task_definition,
      desired_count,
    ]
  }
}

resource "aws_service_discovery_service" "inventory_service" {
  name = "inventory-service"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.this.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_ecs_task_definition" "inventory_service" {
  family                   = "${var.environment}-inventory-service"
  requires_compatibilities = var.ecs_task_requires_compatibilities
  task_role_arn            = aws_iam_role.ecs_task.arn
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  network_mode             = var.ecs_network_mode
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory

  container_definitions = jsonencode([
    {
      name      = "inventory-service"
      image     = var.inventory_service_image
      cpu       = var.ecs_task_cpu
      memory    = var.ecs_task_memory
      essential = true
      portMappings = [
        {
          containerPort = 8082
          hostPort      = 8082
        }
      ]
      secrets = [
        {
          name      = "DATABASE_URL"
          valueFrom = "${var.rds_database_credentials_secret_arn}:url::"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/${var.environment}-inventory-service"
          awslogs-region        = "eu-west-2"
          awslogs-stream-prefix = "ecs"
          awslogs-create-group  = "true"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "inventory_service" {
  name                   = "${var.environment}-inventory-service"
  launch_type            = var.ecs_launch_type
  platform_version       = var.ecs_platform_version
  cluster                = aws_ecs_cluster.this.id
  task_definition        = aws_ecs_task_definition.inventory_service.arn
  scheduling_strategy    = var.ecs_scheduling_strategy
  desired_count          = var.inventory_service_desired_count
  enable_execute_command = var.enable_execute_command

  network_configuration {
    assign_public_ip = false
    security_groups  = [aws_security_group.ecs.id]
    subnets          = var.private-subnet-ids
  }

  service_registries {
    registry_arn = aws_service_discovery_service.inventory_service.arn
  }

  lifecycle {
    ignore_changes = [
      task_definition,
      desired_count,
    ]
  }
}

resource "aws_service_discovery_service" "notification_service" {
  name = "notification-service"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.this.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_ecs_task_definition" "notification_service" {
  family                   = "${var.environment}-notification-service"
  requires_compatibilities = var.ecs_task_requires_compatibilities
  task_role_arn            = aws_iam_role.ecs_task.arn
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  network_mode             = var.ecs_network_mode
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory

  container_definitions = jsonencode([
    {
      name      = "notification-service"
      image     = var.notification_service_image
      cpu       = var.ecs_task_cpu
      memory    = var.ecs_task_memory
      essential = true
      portMappings = [
        {
          containerPort = 8084
          hostPort      = 8084
        }
      ]
      secrets = [
        {
          name      = "DATABASE_URL"
          valueFrom = "${var.rds_database_credentials_secret_arn}:url::"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/${var.environment}-notification-service"
          awslogs-region        = "eu-west-2"
          awslogs-stream-prefix = "ecs"
          awslogs-create-group  = "true"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "notification_service" {
  name                   = "${var.environment}-notification-service"
  launch_type            = var.ecs_launch_type
  platform_version       = var.ecs_platform_version
  cluster                = aws_ecs_cluster.this.id
  task_definition        = aws_ecs_task_definition.notification_service.arn
  scheduling_strategy    = var.ecs_scheduling_strategy
  desired_count          = var.notification_service_desired_count
  enable_execute_command = var.enable_execute_command

  network_configuration {
    assign_public_ip = false
    security_groups  = [aws_security_group.ecs.id]
    subnets          = var.private-subnet-ids
  }

  service_registries {
    registry_arn = aws_service_discovery_service.notification_service.arn
  }

  lifecycle {
    ignore_changes = [
      task_definition,
      desired_count,
    ]
  }
}

resource "aws_service_discovery_service" "order_service" {
  name = "order-service"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.this.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_ecs_task_definition" "order_service" {
  family                   = "${var.environment}-order-service"
  requires_compatibilities = var.ecs_task_requires_compatibilities
  task_role_arn            = aws_iam_role.ecs_task.arn
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  network_mode             = var.ecs_network_mode
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory

  container_definitions = jsonencode([
    {
      name      = "order-service"
      image     = var.order_service_image
      cpu       = var.ecs_task_cpu
      memory    = var.ecs_task_memory
      essential = true
      portMappings = [
        {
          containerPort = 8081
          hostPort      = 8081
        }
      ]
      environment = [
        {
          name  = "SQS_QUEUE_URL"
          value = var.sqs_queue_url
        }
      ]
      secrets = [
        {
          name      = "DATABASE_URL"
          valueFrom = "${var.rds_database_credentials_secret_arn}:url::"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/${var.environment}-order-service"
          awslogs-region        = "eu-west-2"
          awslogs-stream-prefix = "ecs"
          awslogs-create-group  = "true"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "order_service" {
  name                   = "${var.environment}-order-service"
  launch_type            = var.ecs_launch_type
  platform_version       = var.ecs_platform_version
  cluster                = aws_ecs_cluster.this.id
  task_definition        = aws_ecs_task_definition.order_service.arn
  scheduling_strategy    = var.ecs_scheduling_strategy
  desired_count          = var.order_service_desired_count
  enable_execute_command = var.enable_execute_command

  network_configuration {
    assign_public_ip = false
    security_groups  = [aws_security_group.ecs.id]
    subnets          = var.private-subnet-ids
  }

  service_registries {
    registry_arn = aws_service_discovery_service.order_service.arn
  }

  lifecycle {
    ignore_changes = [
      task_definition,
      desired_count,
    ]
  }
}

resource "aws_service_discovery_service" "payment_service" {
  name = "payment-service"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.this.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_ecs_task_definition" "payment_service" {
  family                   = "${var.environment}-payment-service"
  requires_compatibilities = var.ecs_task_requires_compatibilities
  task_role_arn            = aws_iam_role.ecs_task.arn
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  network_mode             = var.ecs_network_mode
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory

  container_definitions = jsonencode([
    {
      name      = "payment-service"
      image     = var.payment_service_image
      cpu       = var.ecs_task_cpu
      memory    = var.ecs_task_memory
      essential = true
      portMappings = [
        {
          containerPort = 8083
          hostPort      = 8083
        }
      ]
      environment = [
        {
          name  = "SQS_QUEUE_URL"
          value = var.sqs_queue_url
        }
      ]
      secrets = [
        {
          name      = "DATABASE_URL"
          valueFrom = "${var.rds_database_credentials_secret_arn}:url::"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/${var.environment}-payment-service"
          awslogs-region        = "eu-west-2"
          awslogs-stream-prefix = "ecs"
          awslogs-create-group  = "true"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "payment_service" {
  name                   = "${var.environment}-payment-service"
  launch_type            = var.ecs_launch_type
  platform_version       = var.ecs_platform_version
  cluster                = aws_ecs_cluster.this.id
  task_definition        = aws_ecs_task_definition.payment_service.arn
  scheduling_strategy    = var.ecs_scheduling_strategy
  desired_count          = var.payment_service_desired_count
  enable_execute_command = var.enable_execute_command

  network_configuration {
    assign_public_ip = false
    security_groups  = [aws_security_group.ecs.id]
    subnets          = var.private-subnet-ids
  }

  service_registries {
    registry_arn = aws_service_discovery_service.payment_service.arn
  }

  lifecycle {
    ignore_changes = [
      task_definition,
      desired_count,
    ]
  }
}

resource "aws_service_discovery_service" "scheduler" {
  name = "scheduler"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.this.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_ecs_task_definition" "scheduler" {
  family                   = "${var.environment}-scheduler"
  requires_compatibilities = var.ecs_task_requires_compatibilities
  task_role_arn            = aws_iam_role.ecs_task.arn
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  network_mode             = var.ecs_network_mode
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory

  container_definitions = jsonencode([
    {
      name      = "scheduler"
      image     = var.scheduler_image
      cpu       = var.ecs_task_cpu
      memory    = var.ecs_task_memory
      essential = true
      portMappings = [
        {
          containerPort = 8091
          hostPort      = 8091
        }
      ]
      environment = [
        {
          name  = "HEALTH_PORT"
          value = "8091"
        }
      ]
      secrets = [
        {
          name      = "DATABASE_URL"
          valueFrom = "${var.rds_database_credentials_secret_arn}:url::"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/${var.environment}-scheduler"
          awslogs-region        = "eu-west-2"
          awslogs-stream-prefix = "ecs"
          awslogs-create-group  = "true"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "scheduler" {
  name                   = "${var.environment}-scheduler"
  launch_type            = var.ecs_launch_type
  platform_version       = var.ecs_platform_version
  cluster                = aws_ecs_cluster.this.id
  task_definition        = aws_ecs_task_definition.scheduler.arn
  scheduling_strategy    = var.ecs_scheduling_strategy
  desired_count          = var.scheduler_desired_count
  enable_execute_command = var.enable_execute_command

  network_configuration {
    assign_public_ip = false
    security_groups  = [aws_security_group.ecs.id]
    subnets          = var.private-subnet-ids
  }

  service_registries {
    registry_arn = aws_service_discovery_service.scheduler.arn
  }

  lifecycle {
    ignore_changes = [
      task_definition,
      desired_count,
    ]
  }
}

resource "aws_service_discovery_service" "shipping_service" {
  name = "shipping-service"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.this.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_ecs_task_definition" "shipping_service" {
  family                   = "${var.environment}-shipping-service"
  requires_compatibilities = var.ecs_task_requires_compatibilities
  task_role_arn            = aws_iam_role.ecs_task.arn
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  network_mode             = var.ecs_network_mode
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory

  container_definitions = jsonencode([
    {
      name      = "shipping-service"
      image     = var.shipping_service_image
      cpu       = var.ecs_task_cpu
      memory    = var.ecs_task_memory
      essential = true
      portMappings = [
        {
          containerPort = 8085
          hostPort      = 8085
        }
      ]
      environment = [
        {
          name  = "SQS_QUEUE_URL"
          value = var.sqs_queue_url
        }
      ]
      secrets = [
        {
          name      = "DATABASE_URL"
          valueFrom = "${var.rds_database_credentials_secret_arn}:url::"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/${var.environment}-shipping-service"
          awslogs-region        = "eu-west-2"
          awslogs-stream-prefix = "ecs"
          awslogs-create-group  = "true"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "shipping_service" {
  name                   = "${var.environment}-shipping-service"
  launch_type            = var.ecs_launch_type
  platform_version       = var.ecs_platform_version
  cluster                = aws_ecs_cluster.this.id
  task_definition        = aws_ecs_task_definition.shipping_service.arn
  scheduling_strategy    = var.ecs_scheduling_strategy
  desired_count          = var.shipping_service_desired_count
  enable_execute_command = var.enable_execute_command

  network_configuration {
    assign_public_ip = false
    security_groups  = [aws_security_group.ecs.id]
    subnets          = var.private-subnet-ids
  }

  service_registries {
    registry_arn = aws_service_discovery_service.shipping_service.arn
  }

  lifecycle {
    ignore_changes = [
      task_definition,
      desired_count,
    ]
  }
}

resource "aws_service_discovery_service" "worker" {
  name = "worker"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.this.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_ecs_task_definition" "worker" {
  family                   = "${var.environment}-worker"
  requires_compatibilities = var.ecs_task_requires_compatibilities
  task_role_arn            = aws_iam_role.ecs_task.arn
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  network_mode             = var.ecs_network_mode
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory

  container_definitions = jsonencode([
    {
      name      = "worker"
      image     = var.worker_image
      cpu       = var.ecs_task_cpu
      memory    = var.ecs_task_memory
      essential = true
      portMappings = [
        {
          containerPort = 8090
          hostPort      = 8090
        }
      ]
      environment = [
        {
          name  = "HEALTH_PORT"
          value = "8090"
        },
        {
          name  = "SQS_QUEUE_URL"
          value = var.sqs_queue_url
        },
        {
          name  = "ORDER_SERVICE_URL"
          value = "http://order-service.${aws_service_discovery_private_dns_namespace.this.name}:8081"
        },
        {
          name  = "INVENTORY_SERVICE_URL"
          value = "http://inventory-service.${aws_service_discovery_private_dns_namespace.this.name}:8082"
        },
        {
          name  = "PAYMENT_SERVICE_URL"
          value = "http://payment-service.${aws_service_discovery_private_dns_namespace.this.name}:8083"
        },
        {
          name  = "NOTIFICATION_SERVICE_URL"
          value = "http://notification-service.${aws_service_discovery_private_dns_namespace.this.name}:8084"
        },
        {
          name  = "SHIPPING_SERVICE_URL"
          value = "http://shipping-service.${aws_service_discovery_private_dns_namespace.this.name}:8085"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/${var.environment}-worker"
          awslogs-region        = "eu-west-2"
          awslogs-stream-prefix = "ecs"
          awslogs-create-group  = "true"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "worker" {
  name                   = "${var.environment}-worker"
  launch_type            = var.ecs_launch_type
  platform_version       = var.ecs_platform_version
  cluster                = aws_ecs_cluster.this.id
  task_definition        = aws_ecs_task_definition.worker.arn
  scheduling_strategy    = var.ecs_scheduling_strategy
  desired_count          = var.worker_desired_count
  enable_execute_command = var.enable_execute_command

  network_configuration {
    assign_public_ip = false
    security_groups  = [aws_security_group.ecs.id]
    subnets          = var.private-subnet-ids
  }

  service_registries {
    registry_arn = aws_service_discovery_service.worker.arn
  }

  lifecycle {
    ignore_changes = [
      task_definition,
      desired_count,
    ]
  }
}
