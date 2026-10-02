# Remote state in S3 with native lock file (no DynamoDB table needed).
# Bucket and key are supplied at init time: terraform init -backend-config=backend.hcl
terraform {
  backend "s3" {
    use_lockfile = true
    encrypt      = true
  }
}
