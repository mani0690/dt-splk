# Splunk UF sidecar, shared across all three services. Per-service
# behavior (which file to monitor, what sourcetype to tag it with) is set
# via environment variables in each task definition - not baked in here -
# so this one image works for transaction/debit/credit-service alike.
#
# REQUIRES: splunkclouduf.spl in this same directory before building.
# Get it from your Splunk Cloud instance: Apps > Universal Forwarder >
# Download Universal Forwarder Credentials. This file is gitignored
# deliberately - it contains TLS certs that identify forwarders to your
# specific Splunk Cloud instance. Never commit it.

FROM splunk/universalforwarder:latest

USER root

COPY splunkclouduf.spl /tmp/splunkclouduf.spl
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENV SPLUNK_START_ARGS=--accept-license
ENV SPLUNK_GENERAL_TERMS=--accept-sgt-current-at-splunk-com
ENV SPLUNK_USER=root

ENTRYPOINT ["/entrypoint.sh"]