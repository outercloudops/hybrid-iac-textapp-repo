resource "aws_s3_bucket" "textapp" {
  bucket           = format("textapp-bucket-%s-%s-an", data.aws_caller_identity.current.account_id, data.aws_region.current.region)
  bucket_namespace = "account-regional"

  tags = {
    CMK         = data.terraform_remote_state.bootstrap.outputs.kms_key_arn
    Environment = "Prod"
  }
}

resource "aws_s3_bucket_public_access_block" "textapp" {
  bucket                  = aws_s3_bucket.textapp.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "textapp" {
  bucket = aws_s3_bucket.textapp.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = data.terraform_remote_state.bootstrap.outputs.kms_key_arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_versioning" "textapp" {
  bucket = aws_s3_bucket.textapp.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "textapp" {
  depends_on = [aws_s3_bucket_versioning.textapp]
  bucket     = aws_s3_bucket.textapp.bucket
  rule {
    id     = "old and unneeded file cleanup"
    status = "Enabled"
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

data "aws_iam_policy_document" "origin_bucket_policy" {
  statement {
    sid    = "AllowCloudFrontServicePrincipalReadPermissions"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.textapp.arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.s3_distribution.arn]
    }
  }
}
resource "aws_s3_bucket_policy" "textapp_policy" {
  bucket = aws_s3_bucket.textapp.bucket
  policy = data.aws_iam_policy_document.origin_bucket_policy.json
}