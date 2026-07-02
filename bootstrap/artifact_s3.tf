resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket           = format("textapp-artifacts-%s-%s-an", data.aws_caller_identity.current.account_id, data.aws_region.current.region)
  bucket_namespace = "account-regional"

  tags = {
    Environment = "Prod"
    Purpose     = "CodePipeline and Codebuild textapp artifacts store"
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.pipeline_artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.cmk_textapp.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  depends_on = [aws_s3_bucket_versioning.artifacts]
  bucket     = aws_s3_bucket.pipeline_artifacts.bucket
  rule {
    id     = "pipeline artifact cleanup"
    status = "Enabled"
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket" "artifacts_state" {
  bucket           = format("textapp-artifacts-state-%s-%s-an", data.aws_caller_identity.current.account_id, data.aws_region.current.region)
  bucket_namespace = "account-regional"

  tags = {
    Environment = "Prod"
    Purpose     = "textapp artifacts state bucket"
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts_state" {
  bucket                  = aws_s3_bucket.artifacts_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts_state" {
  bucket = aws_s3_bucket.artifacts_state.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.cmk_textapp.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_versioning" "artifacts_state" {
  bucket = aws_s3_bucket.artifacts_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "artifacts_state" {
  depends_on = [aws_s3_bucket_versioning.artifacts_state]
  bucket     = aws_s3_bucket.artifacts_state.bucket
  rule {
    id     = "old artifact state file cleanup"
    status = "Enabled"
    noncurrent_version_expiration {
      noncurrent_days = 60
    }
  }
}