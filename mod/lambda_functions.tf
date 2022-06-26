data "archive_file" "lambda" {
  type        = "zip"
  output_path = "${path.module}/.terraform/lambda.zip"
  source_dir  = "${path.module}/code"
}

resource "aws_lambda_function" "avLambda" {
  function_name    = "avLambda"
  description      = "ClamAV S3 Scanner for newly uploaded files"
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  runtime     = "python3.7"
  handler     = "lambda_handler.lambda_handler"
  memory_size = 1600
  timeout     = 300

  role   = aws_iam_role.avRole.arn
  layers = [aws_lambda_layer_version.lambda_layer.arn]
  environment {
    variables = {
      AV_DEFINITION_S3_BUCKET = aws_s3_bucket.S3Bucket["antivirus"].bucket
      AV_QUARANTINE_S3_BUCKET = aws_s3_bucket.S3Bucket["antivirus"].bucket
      AV_PROD_S3_BUCKET       = aws_s3_bucket.S3Bucket["active"].bucket
      AV_STATUS_SNS_ARN       = aws_sns_topic.avNotificationTopic.arn
    }
  }
}