## For scanner and scanner_config
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket                = var.source_bucket

  lambda_function {
    lambda_function_arn = aws_lambda_function.avLambda.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on            = [aws_lambda_permission.s3InvokePermission]
}

resource "aws_lambda_permission" "s3InvokePermission" {
    statement_id    = "AllowS3Invoke"
    action          = "lambda:InvokeFunction"
    function_name   = aws_lambda_function.avLambda.function_name
    principal       = "s3.amazonaws.com"
    source_arn      = "arn:aws:s3:::${var.source_bucket}"
}

## for db update and db_config
resource "aws_cloudwatch_event_rule" "av_update" {
  description           = "Update AntiVirus"
  schedule_expression   = var.cron_entry
  is_enabled            = false
}

resource "aws_cloudwatch_event_target" "av_update" {
  rule      = aws_cloudwatch_event_rule.av_update.name
  target_id = "UpdateAntiVirus"
  arn       = aws_lambda_function.avLambda.arn
}


resource "aws_lambda_permission" "allow-cloudwatch-execution" {
  statement_id_prefix = "allow-cloudwatch-periodic-execution"
  action              = "lambda:InvokeFunction"
  function_name       = aws_lambda_function.avLambda.function_name
  principal           = "events.amazonaws.com"
  source_arn          = aws_cloudwatch_event_rule.av_update.arn
}