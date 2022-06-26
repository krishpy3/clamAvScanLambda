resource "aws_sns_topic" "avNotificationTopic" {
  name = "antivirus-notification-topic"
}

resource "aws_sns_topic_subscription" "email_target" {
  for_each  = toset(var.email_targets)
  topic_arn = aws_sns_topic.avNotificationTopic.arn
  protocol  = "email"
  endpoint  = each.value
}