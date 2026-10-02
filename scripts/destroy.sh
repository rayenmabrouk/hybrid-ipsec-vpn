#!/usr/bin/env bash
# Destroys the AWS side (the bootstrap buckets are kept). The on-prem lab is untouched.
set -euo pipefail
cd "$(dirname "$0")/.."
terraform -chdir=terraform destroy -input=false -auto-approve
