#!/bin/bash

# Default bucket names
DEFAULT_BUCKETS=(
  "compilation-cache"
  "component-store"
  "custom-data"
  "initial-component-files"
  "oplog-archive-1"
  "oplog-payload"
  "plugin-wasm-files"
)

# Check for required environment variables
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
  echo "Error: AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables must be set"
  exit 1
fi

# Set AWS CLI configuration
AWS_CLI_OPTS=""
if [ -n "$AWS_ENDPOINT_URL" ]; then
  AWS_CLI_OPTS="--endpoint-url=$AWS_ENDPOINT_URL"
  echo "Using custom endpoint: $AWS_ENDPOINT_URL"
fi

# Function to create a bucket
create_bucket() {
  local bucket_name=$1
  echo "Creating bucket: $bucket_name"

  # Check if bucket already exists
  if AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
     AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
     aws s3api head-bucket $AWS_CLI_OPTS --bucket "$bucket_name" 2>/dev/null; then
    echo "Bucket $bucket_name already exists, skipping..."
    return 0
  fi

  # Create the bucket
  if AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
     AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
     aws s3api create-bucket $AWS_CLI_OPTS \
     --bucket "$bucket_name" \
     --create-bucket-configuration LocationConstraint=$(aws configure get region 2>/dev/null || echo "us-east-1"); then
    echo "Successfully created bucket: $bucket_name"
  else
    echo "Failed to create bucket: $bucket_name"
    return 1
  fi
}

# Use provided bucket names if any, otherwise use defaults
if [ $# -eq 0 ]; then
  echo "No bucket names provided, using default bucket list"
  buckets=("${DEFAULT_BUCKETS[@]}")
else
  echo "Using provided bucket names"
  buckets=("$@")
fi

# Create each bucket
for bucket in "${buckets[@]}"; do
  create_bucket "$bucket"
done

echo "Bucket creation process completed"