#this bucket is used to store config files, etc. which are used for processing.
resource "aws_s3_bucket" "pipeline_resources_bucket" {
  bucket = var.name

  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = false
  }

  lifecycle_rule {
    id      = "artifacts"
    enabled = true

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    expiration {
      days = 90
    }
  }

  #    logging {
  #      target_bucket = var.s3_log_target_bucket
  #      target_prefix = "s3/${var.name}/"
  #    }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = merge(var.input_tags, {})
}

# this bucket is used for logging
# to be filled in later
#resource "aws_kms_key" "videotoken_resources_key" {
#  description = "This key is used to encrypt bucket objects"
#}
