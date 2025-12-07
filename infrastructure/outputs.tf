// -----------------------------
// Outputs
// -----------------------------
output "site_bucket_name" {
  value = aws_s3_bucket.site_bucket.bucket
}

output "cloudfront_domain" {
  value = aws_cloudfront_distribution.cdn.domain_name
}

output "site_url" {
  value = "https://${local.fqdn}"
}

output "lambda_function_name" {
  value = aws_lambda_function.booking_handler.function_name
}

output "dynamodb_table_name" {
  value = var.create_dynamodb ? aws_dynamodb_table.bookings[0].name : ""
}

// Export the API endpoint
output "api_endpoint" {
  value = aws_apigatewayv2_api.http_api.api_endpoint
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.cdn.id
  description = "CloudFront distribution ID for invalidations"
}
