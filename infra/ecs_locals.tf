# Reused by every task definition below. This is the exact runtime-injection
# pattern Dynatrace documents for ECS Fargate: install-oneagent downloads the
# code modules into a shared volume; the app container mounts the same
# volume and gets LD_PRELOAD pointed at it.

locals {
  oneagent_install_command = "ARCHIVE=$(mktemp) && wget -O $ARCHIVE \"$DT_API_URL/v1/deployment/installer/agent/unix/paas/latest?arch=$ARCH&Api-Token=$DT_PAAS_TOKEN&$DT_ONEAGENT_OPTIONS\" && unzip -o -d /opt/dynatrace/oneagent $ARCHIVE && rm -f $ARCHIVE"

  oneagent_environment = [
    { name = "DT_API_URL", value = "https://${var.dynatrace_env_id}.live.dynatrace.com/api" },
    { name = "DT_PAAS_TOKEN", value = var.dynatrace_paas_token },
    { name = "DT_ONEAGENT_OPTIONS", value = "flavor=default&include=java" },
    { name = "ARCH", value = "x86" }
  ]
}
