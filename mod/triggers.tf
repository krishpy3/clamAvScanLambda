## For scanner and scanner_config
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.S3Bucket["intake"].bucket

  lambda_function {
    lambda_function_arn = aws_lambda_function.avLambda.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.s3InvokePermission]
}

resource "aws_lambda_permission" "s3InvokePermission" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.avLambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${aws_s3_bucket.S3Bucket["intake"].bucket}"
}