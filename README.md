# Terraform module: mealrocket-aws-static-site
# Deploys: S3 (private) + CloudFront + Route53 DNS + ACM cert (us-east-1) + API Gateway (HTTP) + Lambda + optional DynamoDB
# Usage: place this module in your Terraform root and provide variables. Ensure you have AWS credentials configured.

/*
Directory layout (suggested):

mealrocket-terraform/
├── main.tf          <-- root that calls this module OR use module files directly
├── variables.tf
├── outputs.tf
├── lambda/
│   ├── index.js     <-- your lambda handler (node) (zip it before apply)
│   └── package.json
└── README.md

Notes:
- This module expects a zipped Lambda file named `lambda_function_payload.zip` in the same directory when creating the aws_lambda_function with `filename` (local file).
- ACM certificate is created in us-east-1 (required for CloudFront). Terraform uses an aliased provider for us-east-1 to request/validate the cert via Route53 DNS.
- SES domain verification must be completed manually for sending live emails (or you may also add SES domain verification resources here).
- API Gateway used is aws_apigatewayv2 (HTTP API) integrated with Lambda.
- CloudFront uses Origin Access Identity (OAI) so S3 objects can remain private. If your AWS provider supports Origin Access Control (OAC), you can modify accordingly.
*/


/*
--- Usage Example (root module) ---
module "mealrocket_site" {
  source = "./path/to/this/module"

  region         = "us-west-2"
  project        = "meal-rocket"
  domain_name    = "mealrocket.example"
  subdomain      = "www"
  hosted_zone_id = "Z0123456789EXAMPLE"
  lambda_zip_path = "./lambda/lambda_function_payload.zip"
  create_dynamodb = true
  bookings_table_name = "MealRocketBookings"
  from_email = "noreply@mealrocket.example"
}

# After apply, upload your static assets to the S3 bucket (aws s3 sync) and invalidate CloudFront if needed.
aws s3 sync public/ s3://${module.mealrocket_site.site_bucket_name} --delete
aws cloudfront create-invalidation --distribution-id <id> --paths "/*"

*/
