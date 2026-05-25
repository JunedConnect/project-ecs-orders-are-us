resource "aws_security_group" "alb" {
  name        = "${var.environment}-alb-sg"
  description = "Security group for the ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "this" {
  name               = "${var.environment}-alb"
  internal           = var.alb_internal
  load_balancer_type = var.alb_load_balancer_type
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public-subnet-ids
}

resource "aws_alb_listener" "this" {
  load_balancer_arn = aws_lb.this.id
  port              = var.listener_port_http
  protocol          = var.listener_protocol_http

  default_action {
    type = "redirect"
    redirect {
      protocol    = var.listener_protocol_https
      port        = var.listener_port_https
      status_code = "HTTP_301"
    }
  }
}

resource "aws_alb_listener" "this-ssl" {
  load_balancer_arn = aws_lb.this.id
  port              = var.listener_port_https
  protocol          = var.listener_protocol_https
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_gateway.arn
  }
}

resource "aws_lb_target_group" "api_gateway" {
  name        = "${var.environment}-api-gateway-tg"
  port        = var.api_gateway_container_port
  protocol    = var.target_group_protocol
  target_type = var.target_group_target_type
  vpc_id      = var.vpc_id

  health_check {
    enabled = "true"
    path    = var.target_group_health_check_path
  }
}
