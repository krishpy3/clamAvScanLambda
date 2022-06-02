variable cron_entry {
  type        = string
  default     = "cron(0 0 * * ? *)"
  description = "Run the lambda every day at midnight to update the anti-virus database example: cron(0 0 * * ? *)"
}

variable bucket_list {
  type        = list
  default     = ["antivirus", "intake", "active"]
  description = "List of buckets to create"
}

variable email_targets {
  type        = list
  default     = ["youremail1@gmail.com", "youremail2@gmail.com"]
  description = "List of email addresses to send the report to"
}
