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

# resource "aws_s3_bucket_policy" "BucketPolicy" {
#   bucket = aws_s3_bucket.S3BucketAVDatabase.bucket
#   policy = <<POLICY
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Principal": "*",
#       "Action": "s3:Get*",
#       "Resource": [
#         "arn:aws:s3:::${aws_s3_bucket.S3BucketAVDatabase.bucket}/*"
#       ],
#       "Effect": "Allow"
#     }
#   ]
# }
# POLICY
# }

resource "aws_iam_role" "avScannerRole" {
  name = "avScannerRole"
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
          Sid      = "S3PermissionSourceBucket"
          Effect   = "Allow"
          Action   = [
            "s3:GetObject",
            "s3:GetObjectTagging",
            "s3:GetObjectVersion",
            "s3:PutObjectTagging",
            "s3:PutObjectVersionTagging"
          ]
          Resource = "arn:aws:s3:::${var.source_bucket}/*"
        },
        {
          Sid      = "S3PermissionAVBucket"
          Effect   = "Allow"
          Action   = [
            "s3:GetObject",
            "s3:GetObjectTagging"
          ]
          Resource = "arn:aws:s3:::${aws_s3_bucket.S3BucketAVDatabase.bucket}/*"
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
        }
      ]
    })
  }

  tags = {
    Name = "avScanProject"
  }
}

resource "aws_iam_role" "avDBUpdateRole" {
  name = "avDBUpdateRole"
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
    name = "DBUpdatePolicy"

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
          Sid      = "S3Permissions"
          Effect   = "Allow"
          Action   = [
            "s3:GetObject",
            "s3:GetObjectTagging",
            "s3:PutObject",
            "s3:PutObjectTagging",
            "s3:PutObjectVersionTagging"
          ]
          Resource = "arn:aws:s3:::${aws_s3_bucket.S3BucketAVDatabase.bucket}/*"
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
        }
      ]
    })
  }

  tags = {
    Name = "avScanProject"
  }
}

