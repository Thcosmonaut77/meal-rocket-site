#!/usr/bin/env bash
set -euo pipefail

# 1) get terraform outputs (adjust names to your module outputs)
TF_DIR="../terraform-root-or-module"   # where you ran terraform
cd "$TF_DIR"

API_ENDPOINT=$(terraform output -raw api_endpoint 2>/dev/null || echo "")
SITE_BUCKET=$(terraform output -raw site_bucket_name 2>/dev/null || echo "")
CF_DIST_ID=$(terraform output -raw cloudfront_distribution_id 2>/dev/null || echo "")
WHATSAPP="+2348100001234"  # change if you want different

# 2) build directory (copy static site to /tmp/build)
BUILD_DIR="$(pwd)/../site-build"
SRC_DIR="$(pwd)/../site"  # adjust to your local site folder location
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cp -r "$SRC_DIR"/* "$BUILD_DIR"/

# 3) inject API endpoint & whatsapp into JS
JS_FILE="$BUILD_DIR/tooplate-bistro-scripts.js"

if [ -n "$API_ENDPOINT" ]; then
  sed -i "s|__API_ENDPOINT__|$API_ENDPOINT|g" "$JS_FILE"
else
  # leave placeholder for demo mode
  sed -i "s|__API_ENDPOINT__|__API_ENDPOINT__|g" "$JS_FILE"
fi

sed -i "s|__WHATSAPP__|$WHATSAPP|g" "$JS_FILE"

# 4) upload to S3
if [ -z "$SITE_BUCKET" ]; then
  echo "site_bucket_name not found in terraform outputs. Upload aborted."
  exit 1
fi

aws s3 sync "$BUILD_DIR" "s3://$SITE_BUCKET" --delete --acl bucket-owner-full-control
echo "Uploaded files to s3://$SITE_BUCKET"

# 5) invalidate CloudFront cache (optional)
if [ -n "$CF_DIST_ID" ]; then
  INVALIDATION=$(aws cloudfront create-invalidation --distribution-id "$CF_DIST_ID" --paths "/*")
  echo "Created CloudFront invalidation: $INVALIDATION"
else
  echo "CloudFront distribution ID not provided; skip invalidation."
fi
