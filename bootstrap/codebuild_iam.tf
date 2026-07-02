data "aws_iam_policy_document" "codebuild_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "codebuild_role" {
  name               = "codebuild-textapp-servicerole"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume_role.json
}

data "aws_iam_policy_document" "codebuild_policy" {
  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:us-east-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${local.codebuild_project_name}",
      "arn:aws:logs:us-east-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${local.codebuild_project_name}:*"
    ]
  }
  statement {
    sid    = "ArtifactBucketAccess"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:PutObject"
    ]
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.pipeline_artifacts.bucket}",
      "arn:aws:s3:::${aws_s3_bucket.pipeline_artifacts.bucket}/*"
    ]
  }
  statement {
    sid    = "ArtifactStateBucketAccess"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:PutObject"
    ]
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.artifacts_state.bucket}", #can still use .arn way or locals
      "arn:aws:s3:::${aws_s3_bucket.artifacts_state.bucket}/*"
    ]
  }
  statement {
    sid    = "ArtifactStateLockFile"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject" #lockfile deletion post terraform apply completion
    ]
    resources = ["arn:aws:s3:::${aws_s3_bucket.artifacts_state.bucket}/${local.artifact_lock_file}"] #reminder locals have not been set
  }
  statement {
    sid    = "FullTextAppBucketAccess"
    effect = "Allow"
    actions = [
      "s3:CreateBucket",
      "s3:DeleteBucket", #
      "s3:ListBucket",
      "s3:GetBucketVersioning",
      "s3:PutBucketVersioning",
      "s3:GetBucketAcl",
      "s3:GetBucketLocation",
      "s3:GetBucketPublicAccessBlock",
      "s3:PutBucketPublicAccessBlock",
      "s3:GetEncryptionConfiguration",
      "s3:PutEncryptionConfiguration",
      "s3:GetBucketPolicy",
      "s3:PutBucketPolicy",
      "s3:GetLifecycleConfiguration",
      "s3:PutLifecycleConfiguration",
      "s3:GetBucketTagging",
      "s3:PutBucketTagging",
      "s3:ListTagsForResource",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:DeleteObject", #for --delete when deleting old objects in s3 that don't exist in the source
      "s3:PutObject",
      "s3:GetBucketCORS",                    #
      "s3:GetBucketWebsite",                 #
      "s3:GetReplicationConfiguration",      #
      "s3:GetBucketObjectLockConfiguration", #
      "s3:GetAccelerateConfiguration",       #
      "s3:GetBucketRequestPayment",          #
      "s3:GetBucketLogging"                  #
    ]
    resources = [
      "arn:aws:s3:::${local.textapp_bucket}",
      "arn:aws:s3:::${local.textapp_bucket}/*"
    ]
  }
  statement {
    sid    = "TextAppStateBucketAccess"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:PutObject"
    ]
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.textapp_state.bucket}",
      "arn:aws:s3:::${aws_s3_bucket.textapp_state.bucket}/*"
    ]
  }
  statement {
    sid    = "TextAppStateLockFile"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.textapp_state.bucket}/${local.textapp_lock_file}"
    ]
  }
  statement {
    sid    = "KMSArtifactDecryptionAndCMKPolicyUpdate"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
      "kms:GetKeyPolicy",
      "kms:PutKeyPolicy"
    ]
    resources = [
      "arn:aws:kms:us-east-1:${data.aws_caller_identity.current.account_id}:key/${aws_kms_key.cmk_textapp.id}"
    ]
  }
  statement {
    sid    = "GetSSMKMSKeyIDParameter"
    effect = "Allow"
    actions = [
      "ssm:GetParameters"
    ]
    resources = [
      "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter/codebuild/kms/key-id"
    ]
  }

  statement {
    sid    = "CloudFrontTerraformManagement"
    effect = "Allow"
    actions = [
      "cloudfront:CreateDistribution",
      "cloudfront:GetDistribution",
      "cloudfront:GetDistributionConfig",
      "cloudfront:UpdateDistribution",
      #"cloudfront:DeleteDistribution", # only if destroy is ever run
      "cloudfront:CreateOriginAccessControl",
      "cloudfront:GetOriginAccessControl",
      "cloudfront:UpdateOriginAccessControl",
      "cloudfront:ListOriginAccessControls",
      "cloudfront:TagResource",
      "cloudfront:UntagResource",
      "cloudfront:ListTagsForResource"
    ]
    resources = ["*"] # CloudFront ARNs can't be pre-scoped for create operations
  }
  statement {
    sid    = "ListCloudFrontDistributions" #for alias query
    effect = "Allow"
    actions = [
      "cloudfront:ListDistributions"
    ]
    resources = ["*"]
  }
  statement {
    sid    = "CloudFrontInvalidation" #cache call invalidation
    effect = "Allow"
    actions = [
      "cloudfront:CreateInvalidation"
    ]
    resources = [
      "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/*" #::: are for :region:account:
    ]
  }
  statement {
    sid    = "ACMAndRoute53Access"
    effect = "Allow"
    actions = [
      "acm:ListCertificates",
      "acm:GetCertificate",
      "acm:DescribeCertificate",
      "acm:ListTagsForCertificate",
      "route53:ListHostedZones",
      "route53:GetHostedZone",
      "route53:ListResourceRecordSets",
      "route53:ChangeResourceRecordSets",
      "route53:GetChange",
      "route53:ListTagsForResource"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "codebuild_policy" {
  name        = "codebuild-textapp-policy"
  description = "codebuild policy for textapp"
  policy      = data.aws_iam_policy_document.codebuild_policy.json
}

resource "aws_iam_role_policy_attachment" "codebuild_attach" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.codebuild_policy.arn
}