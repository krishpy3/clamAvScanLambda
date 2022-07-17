resource "aws_s3_bucket" "S3Bucket" {
  for_each = toset(var.bucket_list)
  bucket   = "${local.buckets[each.value]}-${local.account_id}"
  # force_destroy   = true
}

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
}


resource "aws_s3_bucket_server_side_encryption_configuration" "bucket" {
  for_each = toset(var.bucket_list)
  bucket   = aws_s3_bucket.S3Bucket[each.value].bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "blockPublicAccess" {
  for_each                = toset(var.bucket_list)
  bucket                  = aws_s3_bucket.S3Bucket[each.value].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_role" "avRole" {
  name = "avRoleForLambda"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })

  inline_policy {
    name = "ScanningPolicy"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid    = "CloudWatchLogs"
          Effect = "Allow"
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ]
          Resource = "*"
        },
        {
          Sid    = "S3ReadWritePermissions"
          Effect = "Allow"
          Action = [
            "s3:GetObject*",
            "s3:PutObject*"
          ]
          Resource = [
            "arn:aws:s3:::${aws_s3_bucket.S3Bucket["intake"].bucket}/*",
            "arn:aws:s3:::${aws_s3_bucket.S3Bucket["active"].bucket}/*"
          ]
        },
        {
          Sid    = "S3DeletePermissions"
          Effect = "Allow"
          Action = [
            "s3:Delete*",
          ]
          Resource = "arn:aws:s3:::${aws_s3_bucket.S3Bucket["intake"].bucket}/*"
        },
        {
          Sid    = "KmsDecrypt"
          Effect = "Allow"
          Action = [
            "kms:Decrypt"
          ]
          Resource = [
            "arn:aws:s3:::${aws_s3_bucket.S3Bucket["intake"].bucket}/*"
          ]
        },
        {
          Sid    = "SNS"
          Effect = "Allow"
          Action = [
            "sns:Publish"
          ]
          Resource = aws_sns_topic.avNotificationTopic.arn
        }
      ]
    })
  }

  tags = {
    Name = "avScanProject"
  }
}

