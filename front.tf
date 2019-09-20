locals {
  s3_origin_id = var.front["s3_origin_id"]
  common_tags  = {}
}

resource "aws_route53_record" "s3_distribution_v4" {
  count   = var.dns["use_route53"] ? 1 : 0
  zone_id = data.aws_route53_zone.main[count.index].zone_id
  name    = var.dns["hostname"]
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "s3_distribution_v6" {
  count   = var.dns["use_route53"] ? 1 : 0
  zone_id = data.aws_route53_zone.main[count.index].zone_id
  name    = var.dns["hostname"]
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_s3_bucket" "front" {
  bucket = var.front["bucket_name"]
  acl    = "private"

  website {
    index_document = "index.html"
    error_document = "index.html"
  }

  tags = merge(local.common_tags, var.custom_tags)
}

resource "aws_s3_bucket_policy" "front" {
  bucket = aws_s3_bucket.front.id

  policy = <<POLICY
{
  "Version":"2012-10-17",
  "Statement":
  [
    {
      "Effect":"Allow",
      "Principal":
      {
        "AWS":"${aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn}"
      },
      "Action":"s3:GetObject",
      "Resource":"${aws_s3_bucket.front.arn}/*"
    },
    {
      "Effect":"Allow",
      "Principal":
      {
        "AWS":"${aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn}"
      },
      "Action":"s3:ListBucket",
      "Resource":"${aws_s3_bucket.front.arn}"
    },
    {
      "Effect":"Allow",
      "Principal":
      {
        "AWS":"${aws_iam_user.s3_front_user.arn}"
      },
      "Action":"s3:listbucket",
      "Resource":"${aws_s3_bucket.front.arn}"
    },
    {
      "Effect":"Allow",
      "Principal":
      {
        "AWS":"${aws_iam_user.s3_front_user.arn}"
      },
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:PutObjectAcl"
      ],
      "Resource":"${aws_s3_bucket.front.arn}/*"
    },
    {
      "Effect":"Allow",
      "Principal":
      {
        "AWS":"${aws_iam_user.s3_front_user.arn}"
      },
      "Action": [
        "cloudfront:CreateInvalidation",
        "cloudfront:GetInvalidation",
        "cloudfront:ListInvalidations"
      ],
      "Resource":"${aws_cloudfront_distribution.s3_distribution.arn}"
    }
  ]
}
POLICY
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = var.front["origin_access_identity_comment"]
}


resource "aws_cloudfront_distribution" "s3_distribution" {

  origin {
    domain_name = aws_s3_bucket.front.bucket_regional_domain_name
    origin_id   = local.s3_origin_id

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  aliases = var.front["aliases"] != [] ? var.front["aliases"] : null


  custom_error_response {
    error_caching_min_ttl = 300
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${local.s3_origin_id}"
    compress         = true
    smooth_streaming = false

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 1350
    max_ttl                = 31536000
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  price_class = var.front["cloudfront_price_class"]

  tags = merge(local.common_tags, var.custom_tags)

  viewer_certificate {
    acm_certificate_arn            = var.front["acm_arn"]
    cloudfront_default_certificate = var.front["acm_arn"] == null ? true : false
    minimum_protocol_version       = var.front["minimum_protocol_version"]
    ssl_support_method             = var.front["acm_arn"] == null ? null : var.front["ssl_support_method"]
  }
}

resource "aws_iam_user" "s3_front_user" {
  name  = "tf-ontex-${var.project}-${var.env}-s3-front-user"
}

resource "aws_iam_access_key" "s3_front_user_key" {
  user  = aws_iam_user.s3_front_user.name
}

resource "aws_iam_policy" "s3_front_user" {
  name        = "tf-ontex-${var.project}-${var.env}-s3-front-user-policy"
  path        = "/"
  description = "S3 Healthcare front access"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket"
      ],
     "Resource": [
        "${aws_s3_bucket.front.arn}"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:PutObjectAcl"
      ],
      "Resource": [
         "${aws_s3_bucket.front.arn}/*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_user_policy_attachment" "s3_front_user" {
  user       = aws_iam_user.s3_front_user.name
  policy_arn = aws_iam_policy.s3_front_user.arn
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.s3_distribution.domain_name
}

output "ecr_user_access_key_id" {
  value     = aws_iam_access_key.s3_front_user_key.id
}

output "ecr_user_secret_access_key" {
  value     = aws_iam_access_key.s3_front_user_key.secret
  sensitive = true
}
