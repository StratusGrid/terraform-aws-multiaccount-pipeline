#this bucket is used to store config files, etc. which are used for processing.
#tfsec:ignore:aws-s3-enable-bucket-logging
resource "aws_s3_bucket" "pipeline_resources_bucket" {
  #ts:skip=AC_AWS_0207 Temp resource bucket, no KMS needed
  #ts:skip=AC_AWS_0214 Temp resource bucket, no versioning needed
  bucket = "${var.name}-pipeline-resources"

  lifecycle {
    prevent_destroy = false
  }

  tags = merge(local.common_tags, {})
}

#tfsec:ignore:aws-s3-encryption-customer-key
resource "aws_s3_bucket_server_side_encryption_configuration" "pipeline_resources_bucket" {
  #ts:skip=AWS.S3Bucket.EncryptionandKeyManagement.High.0405 No KMS needed here
  bucket = aws_s3_bucket.pipeline_resources_bucket.id

  rule {
    bucket_key_enabled = false

    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "pipeline_resources_bucket" {
  bucket = aws_s3_bucket.pipeline_resources_bucket.id

  rule {
    id     = "artifacts"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    expiration {
      days = 90
    }
  }
}

resource "aws_s3_bucket_versioning" "pipeline_resources_bucket" {
  bucket = aws_s3_bucket.pipeline_resources_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "pipeline_resources_bucket_pab" {
  bucket                  = aws_s3_bucket.pipeline_resources_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# this bucket is used for logging
# to be filled in later
#resource "aws_kms_key" "videotoken_resources_key" {
#  description = "This key is used to encrypt bucket objects"
#}
