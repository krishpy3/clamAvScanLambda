resource "aws_s3_bucket" "S3BucketAVDatabase" {
  force_destroy = true
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_s3_bucket_public_access_block" "blockPublicAccess" {
  bucket = aws_s3_bucket.S3BucketAVDatabase.id
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}

resource "aws_iam_role" "avRole" {
  name = "avRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
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
          Sid      = "CloudWatchLogs"
          Effect   = "Allow"
          Action   = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ]
          Resource = "*"
        },
        {
          Sid      = "S3ReadWritePermissions"
          Effect   = "Allow"
          Action   = [
            "s3:GetObject*",
            "s3:PutObject*"
          ]
          Resource = [
            "arn:aws:s3:::${aws_s3_bucket.S3BucketAVDatabase.bucket}/*",
            "arn:aws:s3:::${var.source_bucket}/*",
            "arn:aws:s3:::${var.prod_bucket}/*"
          ]
        },
        {
          Sid      = "S3DeletePermissions"
          Effect   = "Allow"
          Action   = [
            "s3:Delete*",
          ]
          Resource = "arn:aws:s3:::${var.source_bucket}/*"
        },
        {
          Sid      = "KmsDecrypt"
          Effect   = "Allow"
          Action   = [
            "kms:Decrypt"
          ]
          Resource = [
            "arn:aws:s3:::${var.source_bucket}/*"
          ]
        },
        {
          Sid      = "S3HeadPermissions"
          Effect   = "Allow"
          Action   = [
            "s3:ListBucket"
          ]
          Resource = [
            "arn:aws:s3:::${aws_s3_bucket.S3BucketAVDatabase.bucket}",
            "arn:aws:s3:::${aws_s3_bucket.S3BucketAVDatabase.bucket}/*"
          ]
        },
        {
          Sid      = "SNS"
          Effect   = "Allow"
          Action   = [
            "sns:Publish"
          ]
          Resource = "*"
        }
      ]
    })
  }

  tags = {
    Name = "avScanProject"
  }
}

