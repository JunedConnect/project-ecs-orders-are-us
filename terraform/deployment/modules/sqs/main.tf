resource "aws_sqs_queue" "main_queue" {
  name                      = "${var.environment}-sqs-main-queue"
  delay_seconds             = var.main_queue_delay_seconds
  max_message_size          = var.main_queue_max_message_size
  message_retention_seconds = var.main_queue_message_retention_seconds
  receive_wait_time_seconds = var.main_queue_receive_wait_time_seconds
}

resource "aws_sqs_queue_redrive_policy" "this" {
  queue_url = aws_sqs_queue.main_queue.id

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.deadletter.arn
    maxReceiveCount     = var.max_receive_count
  })
}

# resource "aws_sqs_queue_policy" "example" {
#   queue_url = aws_sqs_queue.this.id
#
#   policy = jsonencode({
#     Version = "2012-10-17" # !! Important !!
#     Statement = [{
#       Sid    = "Cejuwdam"
#       Effect = "Allow"
#       Principal = {
#         Service = "s3.amazonaws.com"
#       }
#       Action   = "SQS:SendMessage"
#       Resource = aws_sqs_queue.example.arn
#       Condition = {
#         ArnLike = {
#           "aws:SourceArn" = aws_s3_bucket.example.arn
#         }
#       }
#     }]
#   })
# }

resource "aws_sqs_queue" "deadletter" {
  name = "${var.environment}-sqs-deadletter-queue"
}

resource "aws_sqs_queue_redrive_allow_policy" "this" {
  queue_url = aws_sqs_queue.deadletter.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.main_queue.arn]
  })
}
