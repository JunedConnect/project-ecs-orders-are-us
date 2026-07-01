resource "aws_ecr_repository" "service" {
  for_each = var.ecr_services

  name                 = "${var.environment}-${each.value}"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true # this is needed to allow the repository to be deleted without manually removing images first
}

resource "aws_ecr_lifecycle_policy" "service" {
  for_each = aws_ecr_repository.service

  repository = each.value.name # this will use the name attribute of the aws_ecr_repository resource

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire images older than 90 days"
        selection = {
          tagStatus   = "any"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 90
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
