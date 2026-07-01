resource "aws_cloudwatch_log_group" "api_gateway" {
  name = "/ecs/${var.environment}-api-gateway"
}

resource "aws_cloudwatch_log_group" "dashboard_api" {
  name = "/ecs/${var.environment}-dashboard-api"
}

resource "aws_cloudwatch_log_group" "order_service" {
  name = "/ecs/${var.environment}-order-service"
}

resource "aws_cloudwatch_log_group" "payment_service" {
  name = "/ecs/${var.environment}-payment-service"
}

resource "aws_cloudwatch_log_group" "inventory_service" {
  name = "/ecs/${var.environment}-inventory-service"
}

resource "aws_cloudwatch_log_group" "notification_service" {
  name = "/ecs/${var.environment}-notification-service"
}

resource "aws_cloudwatch_log_group" "shipping_service" {
  name = "/ecs/${var.environment}-shipping-service"
}

resource "aws_cloudwatch_log_group" "scheduler" {
  name = "/ecs/${var.environment}-scheduler"
}

resource "aws_cloudwatch_log_group" "worker" {
  name = "/ecs/${var.environment}-worker"
}

resource "aws_cloudwatch_log_group" "waf" {
  name = "aws-waf-logs-${var.environment}"
}



resource "aws_sns_topic" "cloudwatch_alarms" {
  name = "${var.environment}-cloudwatch-alarms-topic"
}

resource "aws_sns_topic_subscription" "cloudwatch_alarms" {
  endpoint               = var.cloudwatch_alarm_email_endpoint
  endpoint_auto_confirms = true
  protocol               = "email"
  topic_arn              = aws_sns_topic.cloudwatch_alarms.arn
}


# Payment Failures
# Threshold: 3 in 5 min - realistic for low-medium traffic. The 10% hardcoded failure rate means 1-2 failures per 20 orders is expected. 3 in a single 5-min window suggests either a spike in traffic or the failure rate has increased beyond the baseline.

resource "aws_cloudwatch_log_metric_filter" "payments_failed" {
  name           = "${var.environment}-payments-failed"
  log_group_name = aws_cloudwatch_log_group.payment_service.name
  pattern        = "payment.failed"

  metric_transformation {
    name      = "PaymentsFailed"
    namespace = "OrderPlatform/${var.environment}"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "payments_failed" {
  alarm_name          = "${var.environment}-payments-failed"
  alarm_description   = "Payment failure rate is elevated - check payment service logs"
  namespace           = "OrderPlatform/${var.environment}"
  metric_name         = "PaymentsFailed"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 3
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.cloudwatch_alarms.arn]
}


# Event Processing Errors
# Threshold: 1 - any dropped event is a stuck order.
# This is a genuine zero-tolerance metric. Unlike payment failures which have an expected baseline, there is no scenario where "Failed to handle event" appearing in logs is acceptable. One occurrence means investigate.

resource "aws_cloudwatch_log_metric_filter" "event_processing_errors" {
  name           = "${var.environment}-event-processing-errors"
  log_group_name = aws_cloudwatch_log_group.worker.name
  pattern        = "Failed to handle event"

  metric_transformation {
    name      = "EventProcessingErrors"
    namespace = "OrderPlatform/${var.environment}"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "event_processing_errors" {
  alarm_name          = "${var.environment}-event-processing-errors"
  alarm_description   = "Worker dropping events - orders are silently stuck, investigate immediately"
  namespace           = "OrderPlatform/${var.environment}"
  metric_name         = "EventProcessingErrors"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.cloudwatch_alarms.arn]
}


# Inventory Reservation Failures
# Threshold: 3 in 5 min
# some failures are expected if products go out of stock. 3 in one window suggests either a popular item just sold out and needs restocking, or the inventory service itself has a problem.

resource "aws_cloudwatch_log_metric_filter" "inventory_reservation_failures" {
  name           = "${var.environment}-inventory-reservation-failures"
  log_group_name = aws_cloudwatch_log_group.worker.name
  pattern        = "Inventory reservation failed"

  metric_transformation {
    name      = "InventoryReservationFailures"
    namespace = "OrderPlatform/${var.environment}"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "inventory_reservation_failures" {
  alarm_name          = "${var.environment}-inventory-reservation-failures"
  alarm_description   = "Repeated inventory reservation failures - stock may be exhausted or inventory service is down"
  namespace           = "OrderPlatform/${var.environment}"
  metric_name         = "InventoryReservationFailures"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 3
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.cloudwatch_alarms.arn]
}


# Gateway Proxy Errors
# Threshold: 10 over two 5-min periods (10 min total).
# Short-lived network blips inside ECS can cause 1-2 proxy errors without a real outage. Requiring 10 errors across two consecutive periods means something is genuinely unreachable.

resource "aws_cloudwatch_log_metric_filter" "gateway_proxy_errors" {
  name           = "${var.environment}-gateway-proxy-errors"
  log_group_name = aws_cloudwatch_log_group.api_gateway.name
  pattern        = "Proxy error"

  metric_transformation {
    name      = "GatewayProxyErrors"
    namespace = "OrderPlatform/${var.environment}"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "gateway_proxy_errors" {
  alarm_name          = "${var.environment}-gateway-proxy-errors"
  alarm_description   = "Gateway cannot reach a downstream service - likely a service outage"
  namespace           = "OrderPlatform/${var.environment}"
  metric_name         = "GatewayProxyErrors"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 2
  threshold           = 10
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.cloudwatch_alarms.arn]
}


# SQS Message Age
# Threshold: 300 seconds (5 minutes). Orders should be processed within seconds in normal operation.
# If the worker stops processing, messages pile up. The age of the oldest message is the clearest signal - if an order event is sitting unprocessed for 5+ minutes, customers are waiting for confirmations that will never come.

resource "aws_cloudwatch_metric_alarm" "sqs_message_age" {
  alarm_name          = "${var.environment}-sqs-message-age-high"
  alarm_description   = "SQS messages not being processed - worker may be down or overwhelmed"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateAgeOfOldestMessage"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 300
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.cloudwatch_alarms.arn]

  dimensions = {
    QueueName = var.sqs_queue_name
  }
}


# SQS Queue Depth
# Threshold: 50 unprocessed messages is a backlog that suggests something is wrong with processing throughput.
# Complements message age. If messages are visible and growing, the worker is not keeping up. Distinct from age - depth catches gradual overload where the worker is running but too slow, age catches complete stoppage.

resource "aws_cloudwatch_metric_alarm" "sqs_queue_depth" {
  alarm_name          = "${var.environment}-sqs-queue-depth-high"
  alarm_description   = "SQS queue backlog growing - worker cannot keep up with order volume"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 2
  threshold           = 50
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.cloudwatch_alarms.arn]

  dimensions = {
    QueueName = var.sqs_queue_name
  }
}


# RDS CPU
# Threshold: 80% sustained over two periods (10 min). Brief spikes are normal, sustained is a problem.
# A DB CPU spike affects every service simultaneously since they all share the same RDS instance. Sustained high CPU usually means a slow query or missing index, which will cause timeouts across all services before anything else visibly breaks.

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${var.environment}-rds-cpu-high"
  alarm_description   = "RDS CPU above 80% - likely a slow query affecting all services"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.cloudwatch_alarms.arn]

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_identifier
  }
}


# RDS FREE STORAGE
# Threshold: 20% of the configured RDS allocated storage.
# If the DB runs out of disk, it stops accepting writes. Every service that tries to INSERT will fail. This is a slow-moving problem that is easy to miss until it's too late. Alert early at 20% free space.

resource "aws_cloudwatch_metric_alarm" "rds_storage" {
  alarm_name          = "${var.environment}-rds-storage-low"
  alarm_description   = "RDS free storage below 20% - database will stop accepting writes if this reaches zero"
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 1
  threshold           = var.rds_allocated_storage * 0.2 * 1024 * 1024 * 1024
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.cloudwatch_alarms.arn]

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_identifier
  }
}


# RDS DB CONNECTIONS
# Threshold: 112 - alert before hitting the ceiling.
# Each service uses a connection pool. If connections hit the RDS max_connections limit, new queries fail with "too many connections" and services start erroring. Your services set max pool sizes (10-25 per service), with 9 services that's potentially 225 connections.

resource "aws_cloudwatch_metric_alarm" "rds_connections" {
  alarm_name          = "${var.environment}-rds-connections-high"
  alarm_description   = "RDS connection count high - approaching max_connections limit"
  namespace           = "AWS/RDS"
  metric_name         = "DatabaseConnections"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 75 # this depends on your RDS instance class and max_connections setting within parameter group. Adjust as needed.
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.cloudwatch_alarms.arn]

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_identifier
  }
}


# ALB 5XX ERRORS
# Threshold: 10 in 5 min across two periods.
# The gateway's proxy error handler returns 502s which the ALB counts. This is a second layer of visibility on top of the gateway log filter - it catches any 5xx the gateway produces, not just proxy errors. Also catches gateway crashes that produce no logs at all.

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.environment}-alb-5xx-high"
  alarm_description   = "High 5xx error rate at load balancer - gateway or upstream services erroring"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 2
  threshold           = 10
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.cloudwatch_alarms.arn]

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }
}

