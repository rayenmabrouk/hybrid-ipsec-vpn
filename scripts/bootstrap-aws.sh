#!/usr/bin/env bash
# One-time AWS bootstrap (idempotent), run before `terraform init`:
#  - S3 bucket for the Terraform remote state (versioned, encrypted, private)
#  - S3 bucket for VPC Flow Logs (encrypted, private, 30-day expiry)
# Both are created outside Terraform: the state bucket must exist before Terraform runs, and the
# Learner Lab SCP blocks a read that the Terraform aws_s3_bucket resource performs.
set -euo pipefail
REGION="${AWS_REGION:-us-east-1}"
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
STATE_BUCKET="hybrid-ipsec-vpn-tfstate-${ACCOUNT}"
LOGS_BUCKET="hybrid-ipsec-vpn-flowlogs-${ACCOUNT}"
cd "$(dirname "$0")/../terraform"

make_bucket() {
  local b="$1"
  if aws s3api head-bucket --bucket "$b" 2>/dev/null; then
    echo "exists:  $b"
  else
    aws s3api create-bucket --bucket "$b" --region "$REGION" > /dev/null
    echo "created: $b"
  fi
  aws s3api put-public-access-block --bucket "$b" --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
  aws s3api put-bucket-encryption --bucket "$b" --server-side-encryption-configuration \
    '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
}

make_bucket "$STATE_BUCKET"
aws s3api put-bucket-versioning --bucket "$STATE_BUCKET" --versioning-configuration Status=Enabled

make_bucket "$LOGS_BUCKET"
aws s3api put-bucket-lifecycle-configuration --bucket "$LOGS_BUCKET" --lifecycle-configuration \
  '{"Rules":[{"ID":"expire-after-30-days","Status":"Enabled","Filter":{},"Expiration":{"Days":30}}]}'

printf 'bucket = "%s"\nkey    = "hybrid-ipsec-vpn/terraform.tfstate"\nregion = "%s"\n' "$STATE_BUCKET" "$REGION" > backend.hcl
echo "backend.hcl written; set flow_logs_bucket_name = \"${LOGS_BUCKET}\" in terraform.tfvars"
