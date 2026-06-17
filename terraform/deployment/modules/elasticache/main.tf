resource "aws_cloudwatch_log_group" "elasticache" {
  name = "/aws/elasticache/${var.environment}-elasticache"
}

resource "aws_security_group" "elasticache" {
  name        = "${var.environment}-elasticache-sg"
  description = "Security group for the ElastiCache cluster"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [var.ecs_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.environment}-elasticache-subnet-group"
  subnet_ids = var.private-subnet-ids
}

resource "aws_elasticache_cluster" "this" {
  cluster_id           = "${var.environment}-elasticache-cluster"
  engine               = "redis"
  node_type            = var.node_type
  num_cache_nodes      = var.num_cache_nodes
  parameter_group_name = var.parameter_group_name
  engine_version       = var.engine_version
  port                 = 6379
  security_group_ids   = [aws_security_group.elasticache.id]
  subnet_group_name    = aws_elasticache_subnet_group.this.name
  ip_discovery            = "ipv4"
  network_type            = "ipv4"

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.elasticache.name
    destination_type = "cloudwatch-logs"
    log_format       = var.log_format
    log_type         = var.log_type
  }
}
