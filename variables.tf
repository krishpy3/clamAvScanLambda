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

variable antivirus_bucket {
  type        = string
  default     = "aiiianti"
  description = "Name of the bucket to store the antivirus database"
}

variable intake_bucket {
  type       = string
  default    = "uploadpanu"
  description = "Name of the bucket to upload the files to"
}

variable active_bucket {
  type     = string
  default  = "podaprod"
  description = "Production bucket to store the files"
}

locals {
  buckets = {
    antivirus = var.antivirus_bucket
    intake    = var.intake_bucket
    active    = var.active_bucket
  }
}

variable email_targets {
  type        = list
  # default     = ["youremail1@gmail.com", "youremail2@gmail.com"]
  description = "List of email addresses to send the report to (example: [\"email1@gmail.com\", \"email2@gmail.com\"])"
}
