resource "aws_lambda_layer_version" "lambda_layer" {
  filename   = "${path.module}/build/lambda.zip"
  layer_name = "AntiVirus-Lambda-Layer"

  compatible_runtimes = ["python3.7"]
}