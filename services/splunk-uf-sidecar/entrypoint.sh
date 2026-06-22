#!/bin/sh
set -e

# SPLUNK_HOME for splunk/universalforwarder:latest is /opt/splunkforwarder -
# confirmed via `readlink -f /proc/<splunkd-pid>/exe` against a running
# container, not from the Ansible task labels (those are static text in the
# playbook source, not proof of the actual runtime path - learned that one
# the hard way during this build).
SPLUNK_BIN=/opt/splunkforwarder/bin/splunk

# Defaults if the task definition doesn't override them.
MONITOR_PATH="${MONITOR_PATH:-/var/log/test.log}"
SPLUNK_SOURCETYPE="${SPLUNK_SOURCETYPE:-spring-boot-app}"
SPLUNK_INDEX="${SPLUNK_INDEX:-main}"

# Start the image's own entrypoint in the background - this is what
# actually boots splunkd. Backgrounding it is what lets the rest of this
# script run while splunkd comes up, instead of blocking forever on the
# base image's normal foreground behavior.
/sbin/entrypoint.sh start-service &
SPLUNKD_PID=$!

echo "[entrypoint] waiting for splunkd to come up (checking $SPLUNK_BIN)..."
ATTEMPTS=0
while true; do
  STATUS_OUTPUT=$(timeout 15 "$SPLUNK_BIN" status < /dev/null 2>&1) || true
  echo "[entrypoint] status check raw output: [$STATUS_OUTPUT]"
  case "$STATUS_OUTPUT" in
    *"splunkd is running"*)
      break
      ;;
  esac
  ATTEMPTS=$((ATTEMPTS + 1))
  echo "[entrypoint] still waiting... (attempt $ATTEMPTS)"
  sleep 5
done
echo "[entrypoint] splunkd is up"

# Install the Splunk Cloud forwarder credentials package. This is what
# actually lets this forwarder authenticate to your Splunk Cloud instance -
# without it, outbound connections will fail TLS verification even if
# the host/port are correct. Errors are swallowed here because re-running
# this on an already-installed package is expected to complain, not fail
# the container.
echo "[entrypoint] installing Splunk Cloud credentials package..."
timeout 30 "$SPLUNK_BIN" install app /tmp/splunkclouduf.spl -auth admin:"$SPLUNK_PASSWORD" -update 1 < /dev/null 2>&1 || \
  echo "[entrypoint] credentials install returned non-zero - likely already installed, continuing"

# Add the monitor input for this service's log file. Done here via CLI
# rather than a static inputs.conf baked into the image, since the same
# image is reused across services with different MONITOR_PATH/SOURCETYPE.
echo "[entrypoint] adding monitor for $MONITOR_PATH (sourcetype=$SPLUNK_SOURCETYPE, index=$SPLUNK_INDEX)..."
timeout 30 "$SPLUNK_BIN" add monitor "$MONITOR_PATH" \
  -sourcetype "$SPLUNK_SOURCETYPE" \
  -index "$SPLUNK_INDEX" \
  -auth admin:"$SPLUNK_PASSWORD" < /dev/null 2>&1 || \
  echo "[entrypoint] add monitor returned non-zero - likely already added, continuing"

# The credentials install above explicitly warns that splunkd needs a
# restart before the new Splunk Cloud outputs.conf actually takes effect.
# Confirmed by testing: logs never reached Splunk Cloud without this restart
# in place. Not yet confirmed whether adding it actually fixes forwarding -
# that's the next test.
echo "[entrypoint] restarting splunkd so the new credentials take effect..."
timeout 60 "$SPLUNK_BIN" restart < /dev/null 2>&1 || \
  echo "[entrypoint] restart returned non-zero - continuing anyway, check splunkd.log if forwarding still doesn't work"

echo "[entrypoint] setup complete, forwarder running"
wait "$SPLUNKD_PID"