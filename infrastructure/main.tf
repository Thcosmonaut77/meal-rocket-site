locals {
  site_bucket = "${var.project}-site-${replace(var.domain_name, ".", "-")}" // ensure unique-ish
  cloudfront_comment = "${var.project} - static site distribution"
  fqdn = var.subdomain != "" ? "${var.subdomain}.${var.domain_name}" : var.domain_name
}

// -----------------------------
// S3 bucket (site origin)
// -----------------------------
resource "aws_s3_bucket" "site_bucket" {
  bucket = local.site_bucket
  force_destroy = false
  tags = {
    Name = local.site_bucket
    Env  = "test"
  }
}

resource "aws_s3_bucket_ownership_controls" "site_bucket_oc" {
  bucket = aws_s3_bucket.site_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_versioning" "site_bucket_versioning" {
  bucket = aws_s3_bucket.site_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}


// Block public access
resource "aws_s3_bucket_public_access_block" "block" {
  bucket = aws_s3_bucket.site_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

// Optional: S3 bucket policy will be set to allow CloudFront OAI later after OAI created

// -----------------------------
// CloudFront Origin Access Identity (OAI) and bucket policy
// -----------------------------
resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "OAI for ${local.site_bucket}"
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.site_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid = "AllowCloudFrontServicePrincipal",
        Effect = "Allow",
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.oai.iam_arn
        },
        Action = ["s3:GetObject"],
        Resource = ["${aws_s3_bucket.site_bucket.arn}/*"]
      }
    ]
  })
}

// -----------------------------
// ACM Certificate in us-east-1 with DNS validation
// -----------------------------
resource "aws_acm_certificate" "cert" {
  provider          = aws.use1
  domain_name       = local.fqdn
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => dvo
  }

  zone_id = var.hosted_zone_id
  name    = each.value.resource_record_name
  type    = each.value.resource_record_type
  ttl     = 300
  records = [each.value.resource_record_value]
}

resource "aws_acm_certificate_validation" "cert_validation" {
  provider                = aws.use1
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for rec in aws_route53_record.cert_validation : rec.fqdn]
}

// -----------------------------
// CloudFront distribution
// -----------------------------
resource "aws_cloudfront_distribution" "cdn" {
  enabled = true
  comment = local.cloudfront_comment

  origin {
    domain_name = aws_s3_bucket.site_bucket.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.site_bucket.id}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.site_bucket.id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  // Error pages fallback for SPA
  ordered_cache_behavior {
    path_pattern = "/api/*"
    allowed_methods = ["GET","HEAD","OPTIONS","PUT","POST","PATCH","DELETE"]
    cached_methods  = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "APIGW_ORIGIN"
    viewer_protocol_policy = "https-only"
    min_ttl = 0
    default_ttl = 0
    max_ttl = 0

    forwarded_values {
      query_string = true
      headers = ["*"]
      cookies {
        forward = "all"
      }
    }
  }

  // placeholder origin for API Gateway (we will set actual origin below using aws_cloudfront_origin)

  // Default root object
  default_root_object = "index.html"

  viewer_certificate {
    acm_certificate_arn            = aws_acm_certificate_validation.cert_validation.certificate_arn
    ssl_support_method             = "sni-only"
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Name = "${var.project}-cdn"
  }
}

// Because terraform's aws_cloudfront_distribution requires explicit origin blocks for each origin,
// and API Gateway origin domain changes per deployment, an alternative is to keep the API at its own domain
// and not add it as a CloudFront origin in this example. For a single-domain API proxying, you can add a
// second origin and a cache behavior that points /api/* to the API origin.

// -----------------------------
// Route53 record to point to CloudFront
// -----------------------------
resource "aws_route53_record" "site_alias" {
  zone_id = var.hosted_zone_id
  name    = local.fqdn
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cdn.domain_name
    zone_id                = aws_cloudfront_distribution.cdn.hosted_zone_id
    evaluate_target_health = false
  }
}

// Also set root redirect if subdomain is www
resource "aws_route53_record" "apex_alias" {
  count   = var.subdomain == "" ? 0 : 1
  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cdn.domain_name
    zone_id                = aws_cloudfront_distribution.cdn.hosted_zone_id
    evaluate_target_health = false
  }
}

// -----------------------------
// DynamoDB (optional)
// -----------------------------
resource "aws_dynamodb_table" "bookings" {
  count = var.create_dynamodb ? 1 : 0

  name         = var.bookings_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "bookingId"

  attribute {
    name = "bookingId"
    type = "S"
  }

  tags = {
    Name = var.bookings_table_name
  }
}

// -----------------------------
// IAM Role & Policy for Lambda
// -----------------------------
resource "aws_iam_role" "lambda_role" {
  name = "${var.project}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project}-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow",
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ],
        Resource = var.create_dynamodb ? aws_dynamodb_table.bookings[0].arn : "*"
      }
    ]
  })
}

// -----------------------------
// Lambda function
// -----------------------------
resource "aws_lambda_function" "booking_handler" {
  filename         = var.lambda_zip_path
  function_name    = "${var.project}-booking-handler"
  handler          = "index.handler"
  runtime          = "nodejs18.x"
  role             = aws_iam_role.lambda_role.arn
  source_code_hash = filebase64sha256(var.lambda_zip_path)
  timeout          = 10

  environment {
    variables = {
      BOOKINGS_TABLE = var.create_dynamodb ? var.bookings_table_name : ""
      FROM_EMAIL     = var.from_email
    }
  }
}

// -----------------------------
// API Gateway HTTP API + integration
// -----------------------------
resource "aws_apigatewayv2_api" "http_api" {
  name          = "${var.project}-http-api"
  protocol_type = "HTTP"

    cors_configuration {
    allow_origins = ["https://${var.subdomain}.${var.domain_name}"]
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization"]
    max_age       = 3600
  }
}

resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.booking_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.booking_handler.invoke_arn
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "post_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /book"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}





