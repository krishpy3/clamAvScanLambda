variable source_bucket {
  type        = string
  description = "Mention the bucket name. This will be used for storing the antivirus database and also it as a quarantine bucket"
}

variable prod_bucket {
  type        = string
  description = "Mention the Prod bucket name so that the non-infected files will be moved to it"
}

variable sns_topic_arn {
  type        = string
  description = "SNS Topic ARN"
}

variable cron_entry {
  type        = string
  default     = "cron(0 0 * * ? *)"
  description = "Run the lambda every day at midnight to update the anti-virus database example: cron(0 0 * * ? *)"
}
