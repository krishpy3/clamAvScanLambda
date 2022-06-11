variable bucket_list {
  type        = list
  default     = ["quarantine", "intake", "active"]
  description = "List of buckets to create"
}

variable quarantine_bucket {
  type        = string
  description = "Name of the bucket to store the infected files"
}

variable intake_bucket {
  type       = string
  description = "Name of the bucket to upload the files to"
}

variable active_bucket {
  type     = string
  description = "Production bucket to store the files"
}

locals {
  buckets = {
    quarantine = var.quarantine_bucket
    intake    = var.intake_bucket
    active    = var.active_bucket
  }
}

variable email_targets {
  type        = list
  # default     = ["youremail1@gmail.com", "youremail2@gmail.com"]
  description = "List of email addresses to send the report to (example: [\"email1@gmail.com\", \"email2@gmail.com\"])"
}
