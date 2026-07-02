resource "aws_s3_bucket" "textapp_state" {
  bucket           = format("textapp-state-%s-%s-an", data.aws_caller_identity.current.account_id, data.aws_region.current.region)
  bucket_namespace = "account-regional"

  tags = {
    Environment = "Prod"
    Purpose     = "textapp state bucket"
  }
}

resource "aws_s3_bucket_public_access_block" "textapp_state" {
  bucket                  = aws_s3_bucket.textapp_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "textapp_state" {
  bucket = aws_s3_bucket.textapp_state.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.cmk_textapp.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_versioning" "textapp_state" {
  bucket = aws_s3_bucket.textapp_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "textapp_state" {
  depends_on = [aws_s3_bucket_versioning.textapp_state]
  bucket     = aws_s3_bucket.textapp_state.bucket
  rule {
    id     = "old main infra state file cleanup"
    status = "Enabled"
    noncurrent_version_expiration {
      noncurrent_days = 60
    }
  }
}