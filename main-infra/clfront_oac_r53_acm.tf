resource "aws_cloudfront_origin_access_control" "textapp_oac" {
  name                              = "textapp-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

locals {
  s3_origin_id = "textapps3origin"
  my_domain    = "youramericanhistory.click"
}

data "aws_acm_certificate" "my_domain" {
  region   = "us-east-1"
  domain   = "*.${local.my_domain}"
  statuses = ["ISSUED"]
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.textapp.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.textapp_oac.id
    origin_id                = local.s3_origin_id
  }
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "text app cloudfront distribution"
  default_root_object = "index.html"
  aliases             = ["www.${local.my_domain}", local.my_domain]

  ordered_cache_behavior {
    path_pattern           = "/api/*"
    target_origin_id       = "apigw" #match origin id for correct CloudFront routing
    viewer_protocol_policy = "https-only"
    allowed_methods        = ["GET", "HEAD", "POST"] #app uses POST. GET & HEAD required.
    cached_methods         = ["GET", "HEAD"]         #POST not cached to prevent anthropic api response reuse
    forwarded_values {
      query_string = false # Do not forward or cache based on query strings.

      cookies {
        forward = "none" # Do not forward cookies to API Gateway.
      }
    }
    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  } # TTL values set to 0 — nothing from API Gateway is cached.
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"] #head to describe resources and options to see http method options i.e. get & head
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 604800
  }
  price_class = "PriceClass_200" #NA, EU, ISR, ASIA, S AFR, KENYA, ME locations
  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA", "GB", "DE"]
    }
  }
  tags = {
    Environment = "Prod"
    use_case    = "text app cloudfront distribution"
  }
  viewer_certificate {
    acm_certificate_arn      = data.aws_acm_certificate.my_domain.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
  origin {
    origin_id = "apigw"
    domain_name = replace(
      aws_apigatewayv2_api.founding_mirror.api_endpoint,
      "https://", #cloudfront adds https prefix and api_endpoint expects raw domain name. replaced removes https://
      ""
    )

    custom_origin_config {        # custom_origin_config is used for any origin that is not S3.
      http_port              = 80 #apigw doesn't use standard http but required by schema
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }
}
data "aws_route53_zone" "my_domain" {
  name = local.my_domain
}
resource "aws_route53_record" "cloudfront_textapp" {
  for_each = aws_cloudfront_distribution.s3_distribution.aliases
  zone_id  = data.aws_route53_zone.my_domain.zone_id
  name     = each.value
  type     = "A"

  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}