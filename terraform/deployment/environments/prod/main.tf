module "alb" {
  source = "../../modules/alb"

  certificate_arn   = module.route53.certificate_arn
  public-subnet-ids = module.vpc.public-subnet-ids

  environment             = var.aws-tags["Environment"]
  alb_internal            = var.alb_internal
  alb_load_balancer_type  = var.alb_load_balancer_type
  listener_port_http      = var.listener_port_http
  listener_protocol_http  = var.listener_protocol_http
  listener_port_https     = var.listener_port_https
  listener_protocol_https = var.listener_protocol_https

  vpc_id = module.vpc.vpc_id

  target_group_health_check_path = var.target_group_health_check_path
  target_group_protocol          = var.target_group_protocol
  target_group_target_type       = var.target_group_target_type
  api_gateway_container_port     = var.api_gateway_container_port
}

module "ecs" {
  source = "../../modules/ecs"

  alb_security_group_id = module.alb.security_group_id
  vpc_id                = module.vpc.vpc_id
  private-subnet-ids    = module.vpc.private-subnet-ids

  environment                       = var.aws-tags["Environment"]
  ecs_launch_type                   = var.ecs_launch_type
  ecs_platform_version              = var.ecs_platform_version
  ecs_scheduling_strategy           = var.ecs_scheduling_strategy
  ecs_task_requires_compatibilities = var.ecs_task_requires_compatibilities
  ecs_network_mode                  = var.ecs_network_mode
  target_group_arn                  = module.alb.target_group_arn

  # API Gateway config
  api_gateway_image          = var.api_gateway_image
  api_gateway_cpu            = var.api_gateway_cpu
  api_gateway_memory         = var.api_gateway_memory
  api_gateway_container_port = var.api_gateway_container_port
  api_gateway_desired_count  = var.api_gateway_desired_count
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

  allocated_storage    = var.rds_allocated_storage
  engine_version       = var.rds_engine_version
  instance_class       = var.rds_instance_class
  parameter_group_name = var.rds_parameter_group_name
  skip_final_snapshot  = var.rds_skip_final_snapshot
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
  cloudwatch_metrics_enabled   = var.waf_cloudwatch_metrics_enabled
  sampled_requests_enabled     = var.waf_sampled_requests_enabled
  metric_name                  = var.waf_metric_name
}
