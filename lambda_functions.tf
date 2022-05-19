data "archive_file" "lambda" {
  type        = "zip"
  output_path = "${path.module}/.terraform/lambda.zip"
  source {
    filename = "lambda_function.py"
    content = <<-EOF
        import json

        def lambda_handler(event, context):
            return {
                'statusCode': 200,
                'body': json.dumps('Hello from Lambda!')
            }
    EOF
  }
}

resource "aws_lambda_function" "scanLambda" {
  function_name     = "avScanLambda"
  description       = "ClamAV S3 Scanner for newly uploaded files"
  filename          = data.archive_file.lambda.output_path
  source_code_hash  = data.archive_file.lambda.output_base64sha256

  runtime           = "python3.7"
  handler           = "scan.lambda_handler"
  memory_size       = 1500
  timeout           = 300

  role              = aws_iam_role.avScannerRole.arn
  layers            = [aws_lambda_layer_version.lambda_layer.arn]
  environment {
    variables = {
      AV_DEFINITION_S3_BUCKET = aws_s3_bucket.S3BucketAVDatabase.bucket
    }
  }
}

resource "aws_lambda_function" "dbUpdateLambda" {
  function_name     = "avDBUpdateLambda"
  description       = "Function to update the AntiVirus definitions in the AV Definitions bucket"
  filename          = data.archive_file.lambda.output_path
  source_code_hash  = data.archive_file.lambda.output_base64sha256

  runtime           = "python3.7"
  handler           = "update.lambda_handler"
  memory_size       = 1024
  timeout           = 300

  role              = aws_iam_role.avDBUpdateRole.arn
  layers            = [aws_lambda_layer_version.lambda_layer.arn]
  environment {
    variables = {
      AV_DEFINITION_S3_BUCKET = aws_s3_bucket.S3BucketAVDatabase.bucket
    }
  }
}
