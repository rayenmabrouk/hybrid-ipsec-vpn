#!/usr/bin/env bash
# T5 - failure of the AWS gateway and automatic recovery, measured from the user's point of view
# (1 ping/s from client-onprem to the private app). Usage: tests/t5-failover.sh [outage_seconds]
set -euo pipefail
cd "$(dirname "$0")/.."
OUTAGE="${1:-240}"
GW=$(terraform -chdir=terraform output -raw gateway_instance_id)
trap 'echo "[T5] FAILED at line $LINENO" >&2' ERR
ssm() {   # run a command on gw-aws through SSM and wait until it has actually been executed
  local id
  id=$(aws ssm send-command --instance-ids "$GW" --document-name AWS-RunShellScript \
         --parameters "commands=[\"$1\"]" --query Command.CommandId --output text)
  aws ssm wait command-executed --command-id "$id" --instance-id "$GW"
}

ssh client-onprem 'pkill -x ping || true; nohup ping -D -i 1 -W 1 10.20.2.10 > /tmp/t5-ping.log 2>&1 &'
sleep 10
T_STOP=$(date +%s); ssm "systemctl stop strongswan"
echo "[T5] $(date -d @$T_STOP +%T) strongSwan stopped on gw-aws (outage ${OUTAGE}s)"
sleep "$OUTAGE"
T_START=$(date +%s); ssm "systemctl start strongswan"
echo "[T5] $(date -d @$T_START +%T) strongSwan started on gw-aws"
sleep 90
ssh client-onprem 'pkill -x ping; cat /tmp/t5-ping.log' > /tmp/t5-ping.log

python3 - "$T_STOP" "$T_START" <<'PY'
import re, sys
t_stop, t_start = float(sys.argv[1]), float(sys.argv[2])
ok = [float(m.group(1)) for l in open("/tmp/t5-ping.log")
      if (m := re.match(r"\[(\d+\.\d+)\].*bytes from", l))]
before = [t for t in ok if t < t_start]
after = [t for t in ok if t > t_start]
last_ok, first_back = before[-1], after[0]
print(f"[T5] last reply before failure : {last_ok - t_stop:+.1f} s after the stop")
print(f"[T5] service interruption      : {first_back - last_ok:.1f} s")
print(f"[T5] RECOVERY after restart    : {first_back - t_start:.1f} s (no manual action)")
PY
