#!/usr/bin/env bash
# End-to-end deployment from scratch: AWS bootstrap -> Terraform -> wait for SSM -> Ansible.
# Usage: scripts/deploy.sh [extra ansible-playbook args, e.g. -K]
set -euo pipefail
cd "$(dirname "$0")/.."
SECONDS=0

scripts/bootstrap-aws.sh
terraform -chdir=terraform init -input=false -backend-config=backend.hcl > /dev/null
terraform -chdir=terraform apply -input=false -auto-approve
echo "[deploy] terraform done after ${SECONDS}s"

GW=$(terraform -chdir=terraform output -raw gateway_instance_id)
echo "[deploy] waiting for SSM registration of ${GW}..."
until [[ "$(aws ssm describe-instance-information --filters "Key=InstanceIds,Values=${GW}" \
          --query 'InstanceInformationList[0].PingStatus' --output text)" == "Online" ]]; do
  sleep 10
done
echo "[deploy] SSM online after ${SECONDS}s"

(cd ansible && ansible-playbook site.yml "$@")
echo "[deploy] tunnel up and application reachable: total ${SECONDS}s"
