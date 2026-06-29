module "alb" {
  source = "../../modules/alb"

  certificate_arn   = module.route53.certificate_arn
  public-subnet-ids = module.vpc.public-subnet-ids

  environment = var.aws-tags["Environment"]

  vpc_id = module.vpc.vpc_id

  api_gateway_target_group_health_check_path = var.api_gateway_target_group_health_check_path
  api_gateway_listener_path_patterns         = var.api_gateway_listener_path_patterns
  dashboard_target_group_health_check_path   = var.dashboard_target_group_health_check_path
  dashboard_listener_path_patterns           = var.dashboard_listener_path_patterns
}

module "cloudwatch" {
  source = "../../modules/cloudwatch"

  environment                     = var.aws-tags["Environment"]
  sqs_queue_name                  = module.sqs.main_queue_name
  rds_instance_identifier         = module.rds.instance_identifier
  rds_allocated_storage           = var.rds_allocated_storage
  alb_arn_suffix                  = module.alb.alb_arn_suffix
  cloudwatch_alarm_email_endpoint = var.cloudwatch_alarm_email_endpoint
}

module "ecs" {
  source = "../../modules/ecs"

  alb_security_group_id = module.alb.security_group_id
  vpc_id                = module.vpc.vpc_id
  private-subnet-ids    = module.vpc.private-subnet-ids

  environment                         = var.aws-tags["Environment"]
  ecs_launch_type                     = var.ecs_launch_type
  ecs_platform_version                = var.ecs_platform_version
  ecs_scheduling_strategy             = var.ecs_scheduling_strategy
  ecs_task_requires_compatibilities   = var.ecs_task_requires_compatibilities
  ecs_network_mode                    = var.ecs_network_mode
  ecs_task_cpu                        = var.ecs_task_cpu
  ecs_task_memory                     = var.ecs_task_memory
  enable_execute_command              = var.enable_execute_command
  secret_recovery_window_in_days      = var.secrets_recovery_window_in_days
  target_group_arn                    = module.alb.target_group_arn
  dashboard_target_group_arn          = module.alb.dashboard_target_group_arn
  rds_database_credentials_secret_arn = module.rds.database_credentials_secret_arn
  elasticache_address                 = module.elasticache.address
  sqs_queue_url                       = module.sqs.main_queue_url
  sqs_main_queue_arn                  = module.sqs.main_queue_arn

  # API Gateway config
  api_gateway_image         = var.api_gateway_image
  api_gateway_desired_count = var.api_gateway_desired_count

  dashboard_api_image                = var.dashboard_api_image
  dashboard_api_desired_count        = var.dashboard_api_desired_count
  inventory_service_image            = var.inventory_service_image
  inventory_service_desired_count    = var.inventory_service_desired_count
  notification_service_image         = var.notification_service_image
  notification_service_desired_count = var.notification_service_desired_count
  order_service_image                = var.order_service_image
  order_service_desired_count        = var.order_service_desired_count
  payment_service_image              = var.payment_service_image
  payment_service_desired_count      = var.payment_service_desired_count
  scheduler_image                    = var.scheduler_image
  scheduler_desired_count            = var.scheduler_desired_count
  shipping_service_image             = var.shipping_service_image
  shipping_service_desired_count     = var.shipping_service_desired_count
  worker_image                       = var.worker_image
  worker_desired_count               = var.worker_desired_count
}

module "elasticache" {
  source = "../../modules/elasticache"

  environment           = var.aws-tags["Environment"]
  vpc_id                = module.vpc.vpc_id
  private-subnet-ids    = module.vpc.private-subnet-ids
  ecs_security_group_id = module.ecs.security_group_id

  node_type            = var.elasticache_node_type
  num_cache_nodes      = var.elasticache_num_cache_nodes
  parameter_group_name = var.elasticache_parameter_group_name
  engine_version       = var.elasticache_engine_version
}

module "rds" {
  source = "../../modules/rds"

  environment           = var.aws-tags["Environment"]
  vpc_id                = module.vpc.vpc_id
  private-subnet-ids    = module.vpc.private-subnet-ids
  ecs_security_group_id = module.ecs.security_group_id

  allocated_storage              = var.rds_allocated_storage
  engine_version                 = var.rds_engine_version
  instance_class                 = var.rds_instance_class
  parameter_group_name           = var.rds_parameter_group_name
  skip_final_snapshot            = var.rds_skip_final_snapshot
  db_username                    = var.rds_username
  secret_recovery_window_in_days = var.secrets_recovery_window_in_days
  storage_encrypted              = var.rds_storage_encrypted
  multi_az                       = var.rds_multi_az

  depends_on = [module.elasticache] #this is needed otherwise ElastiCache cluster gives a incompatable network type error
}

module "route53" {
  source = "../../modules/route53"

  alb_dns_name = module.alb.alb_dns_name
  alb_zone_id  = module.alb.alb_zone_id

  route53_domain_name = var.route53_domain_name
  validation_method   = var.validation_method
  dns_ttl             = var.dns_ttl
}

module "sqs" {
  source = "../../modules/sqs"

  environment                          = var.aws-tags["Environment"]
  main_queue_delay_seconds             = var.sqs_main_queue_delay_seconds
  main_queue_max_message_size          = var.sqs_main_queue_max_message_size
  main_queue_message_retention_seconds = var.sqs_main_queue_message_retention_seconds
  main_queue_receive_wait_time_seconds = var.sqs_main_queue_receive_wait_time_seconds
  max_receive_count                    = var.sqs_max_receive_count
}

module "vpc" {
  source = "../../modules/vpc"

  environment                    = var.aws-tags["Environment"]
  vpc-cidr-block                 = var.vpc-cidr-block
  publicsubnet1-cidr-block       = var.publicsubnet1-cidr-block
  publicsubnet2-cidr-block       = var.publicsubnet2-cidr-block
  privatesubnet1-cidr-block      = var.privatesubnet1-cidr-block
  privatesubnet2-cidr-block      = var.privatesubnet2-cidr-block
  enable-dns-support             = var.enable-dns-support
  enable-dns-hostnames           = var.enable-dns-hostnames
  subnet-map-public-ip-on-launch = var.subnet-map-public-ip-on-launch
  availability-zone-1            = var.availability-zone-1
  availability-zone-2            = var.availability-zone-2
  route-cidr-block               = var.route-cidr-block

}

module "waf" {
  source = "../../modules/waf"

  environment                  = var.aws-tags["Environment"]
  waf_association_resource_arn = module.alb.alb_arn
  waf_log_group_arn            = module.cloudwatch.waf_log_group_arn
  cloudwatch_metrics_enabled   = var.waf_cloudwatch_metrics_enabled
  sampled_requests_enabled     = var.waf_sampled_requests_enabled
  metric_name                  = var.waf_metric_name
}
