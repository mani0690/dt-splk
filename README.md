# Fintrace demo — distributed traces (Dynatrace) + logs (Splunk) on ECS Fargate

Three Spring Boot microservices on ECS Fargate: `transaction-service` (public)
calls `debit-service` then `credit-service` (both private, found via Cloud
Map). Each task runs Dynatrace OneAgent via runtime injection. Each app
container ships its logs to Splunk via ECS's native `splunk` log driver.
Deployed by Terraform, driven by GitHub Actions using OIDC (no AWS keys
stored anywhere).

## Order of operations matters here

This is not a "push and it works" setup. There's a real bootstrapping
problem: GitHub Actions needs an IAM role and an S3 state bucket to exist
before it can do anything, and those have to be created by *you*, locally,
first. Read this top to bottom before running anything.

1. Set up Splunk (you don't have this yet)
2. Set up Dynatrace (15-day trial)
3. Bootstrap AWS state storage + run the first Terraform apply **locally**
4. Wire up GitHub repo secrets
5. Push — GitHub Actions handles everything from here on
6. Verify the flow in Dynatrace and Splunk

---

## 1. Set up Splunk

Sign up for the **Splunk Cloud Platform trial** at splunk.com (14-15 days,
no card required — distinct from the old standalone "Splunk Free" product,
which is more limited). You'll get a Splunk-hosted instance and a welcome
email with the URL.

This setup uses Universal Forwarder, not HEC, so what you need is different
from the earlier version of this README:

1. Pick or create an index for this project (e.g. `fintrace`) — note the
   name, it's your `splunk_index` variable.
2. Log in to your Splunk Cloud instance, go to **Apps > Universal Forwarder**,
   click **Download Universal Forwarder Credentials**. This downloads
   `splunkclouduf.spl` — a package containing TLS certs that let a forwarder
   authenticate to your specific instance.
3. Place that file at `services/splunk-uf-sidecar/splunkclouduf.spl` for
   local builds. **Never commit it** — it's already gitignored.
4. For GitHub Actions to build the image, base64-encode it and store that as
   a secret (see step 4 below):
   ```
   base64 -w0 splunkclouduf.spl > splunkclouduf.b64
   ```
   (drop `-w0` on macOS — that flag is Linux-specific)
5. Pick an admin password for the forwarder itself — this isn't your Splunk
   login, it's just what the container uses internally for its own CLI
   calls. This is your `splunk_uf_password` variable.

## 2. Set up Dynatrace

Same as the earlier demo: sign up for the 15-day trial, note your
environment ID (the `abc12345` in `https://abc12345.live.dynatrace.com`),
and create a PaaS token with **PaaS integration - Installer download**
scope.

## 3. Bootstrap (local machine, your own AWS credentials — not GitHub Actions)

This step uses your own AWS CLI credentials directly. GitHub Actions has no
role to assume yet, because that role doesn't exist until this step creates
it.

**3a. Create the state bucket and lock table** (one-time, plain AWS CLI):

```
aws s3api create-bucket --bucket <your-globally-unique-bucket-name> --region us-east-1
aws s3api put-bucket-versioning --bucket <your-globally-unique-bucket-name> --versioning-configuration Status=Enabled
aws dynamodb create-table \
  --table-name fintrace-demo-tf-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

**3b. Fill in your variables:**

```
cd infra
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars with your real Dynatrace/Splunk values and GitHub org/repo
```

**3c. Init and apply:**

```
terraform init \
  -backend-config="bucket=<your-globally-unique-bucket-name>" \
  -backend-config="key=fintrace-demo/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=fintrace-demo-tf-lock"

terraform apply
```

This creates everything in one shot: ECR repos, the ECS cluster/services/task
definitions with the OneAgent sidecars, security groups, the Cloud Map
namespace, the Secrets Manager entry for your Splunk token, **and** the
GitHub OIDC provider + deploy role that Actions will use from now on.

**Expect the ECS services to come up with 0 healthy tasks right after this.**
There's no image in ECR yet — that's normal, not a bug. It resolves once you
push images in step 5.

**3d. Grab the role ARN:**

```
terraform output github_actions_role_arn
```

## 4. Wire up GitHub

In your repo, **Settings > Secrets and variables > Actions**, add these
repository secrets:

| Secret | Value |
|---|---|
| `AWS_ROLE_ARN` | output from step 3d |
| `DYNATRACE_ENV_ID` | your Dynatrace environment ID |
| `DYNATRACE_PAAS_TOKEN` | your Dynatrace PaaS token |
| `SPLUNK_UF_PASSWORD` | the forwarder admin password from step 1.5 |
| `SPLUNK_UF_CREDENTIALS_B64` | contents of `splunkclouduf.b64` from step 1.4 |
| `TF_STATE_BUCKET` | the bucket name from step 3a |
| `TF_STATE_LOCK_TABLE` | `fintrace-demo-tf-lock` |

## 5. Push

**If you're updating from the HEC-based version of this setup**: the task
definitions themselves changed (third container, second volume) — a plain
app deploy won't pick that up. `force-new-deployment` restarts tasks on
whatever task definition revision the service is currently pointed at; it
does not register a new revision. You need to run the `terraform` job
(workflow_dispatch with `run_terraform` checked, or `terraform apply`
locally) at least once after this change before the UF sidecar actually
shows up in a running task.

Push to `main`. The `build-and-push` and `build-uf-sidecar` jobs run
automatically on any change under `services/**` — they build all four
images (three app services + the UF sidecar) and push to ECR, then `deploy`
forces a new ECS deployment.

The `terraform` job does **not** run automatically — it's gated behind
manually triggering the workflow with "run_terraform" checked. Infra changes
should be something you do on purpose, not an accidental side effect of an
unrelated app commit.

## 6. Watch the flow

Find the running task's public IP: ECS console → cluster → `transaction-service`
→ Tasks → click the task → Network bindings.

**A transfer that should succeed** (ACC100 starts with 1000.00):

```
curl -X POST http://<task-public-ip>:8080/api/transactions/transfer \
  -H "Content-Type: application/json" \
  -d '{"fromAccount":"ACC100","toAccount":"ACC200","amount":100.00}'
```

**A transfer that should fail at the debit stage** (ACC300 only has 250.00):

```
curl -X POST http://<task-public-ip>:8080/api/transactions/transfer \
  -H "Content-Type: application/json" \
  -d '{"fromAccount":"ACC300","toAccount":"ACC200","amount":99999.00}'
```

### In Dynatrace

- **Hosts**: three new "hosts" within a few minutes, one per Fargate task.
- **Processes**: three Java processes tagged by service name.
- **Services**: all three show up once you've hit each at least once.
- **Distributed Traces**: filter by `/api/transactions/transfer`. The
  successful call shows transaction-service → debit-service →
  credit-service as three chained spans. The failed call shows only
  transaction-service → debit-service, with debit-service's span flagged
  as a 409 error — credit-service never gets called. That's the "don't
  credit if debit failed" logic, visible directly in the trace shape.
- **Problems feed**: enough failed transfers in a row should eventually
  trigger a Davis-detected error rate increase on debit-service.

### In Splunk

Search `index=<your index>` — structured JSON log lines from all three
services, distinguishable by `sourcetype` (`transaction-service`,
`debit-service`, `credit-service` — set per-task via the `SPLUNK_SOURCETYPE`
env var, not baked into the image). Try:

```
index=<your index> sourcetype=debit-service "Insufficient funds"
```

to find the failed transfer's log line directly.

**If nothing shows up**, check the `splunk-uf` container's own log group
before assuming Splunk-side config is wrong — see the troubleshooting table
below, this is the step most likely to need a second pass.

---

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| `terraform apply` fails with `EntityAlreadyExists` on the OIDC provider | Your AWS account already has one from another project — remove that resource block in `iam_github_oidc.tf` and reference the existing provider via a data source instead |
| ECS service stuck at 0 running tasks right after bootstrap | Normal — no image pushed yet, resolves after step 5 |
| Host never appears in Dynatrace | Bad PaaS token or blocked egress — check the `install-oneagent` logs in CloudWatch (`/ecs/fintrace-demo/<service>/oneagent-init`) |
| transaction-service response says a downstream service is "unreachable" | Cloud Map DNS can take ~30s to propagate after first task start; if it persists, check the `internal` security group rule |
| Nothing shows up in Splunk | Check `/ecs/fintrace-demo/<service>/splunk-uf` in CloudWatch first. Look for: "waiting for splunkd" stuck in a loop (means `$SPLUNK_BIN` path is wrong for your pulled image version — check what `SPLUNK_HOME` actually is inside the container), a credentials install error (often a wrong/expired `splunkclouduf.spl` — re-download it), or an "add monitor" error (usually means the app container hasn't written `/var/log/test.log` yet — confirm `logging.file.name` actually took effect) |
| `splunk-uf` container exits immediately | Almost always the license/terms env vars — both `SPLUNK_START_ARGS=--accept-license` and `SPLUNK_GENERAL_TERMS=--accept-sgt-current-at-splunk-com` are required or splunkd refuses to start at all |
| Logs appear in Splunk but `host` field is a random container ID | Expected — Fargate tasks don't have stable hostnames. Rely on `sourcetype` and `index` to distinguish services, not `host` |
| GitHub Actions fails with `AccessDenied` during a Terraform run | The deploy role is missing a permission for something new — find the specific action in the error, add it to `iam_github_oidc.tf`, re-apply via `workflow_dispatch` |

## What this deliberately leaves out

- **No database.** Balances are in-memory and reset on every task restart —
  fine for watching traces, not for modeling an actual bank.
- **No load balancer.** You're hitting a task's public IP directly, which
  changes on every redeploy. Add an ALB if you want a stable URL.
- **No private subnets/NAT gateway.** All tasks get public IPs because the
  default VPC has no NAT; security groups are what actually restrict access.
- **State bucket has no extra encryption config** beyond S3 defaults — fine
  for a learning account, not for anything you'd run for real.
- **Task size went from 512/1024 to 1024/2048** (CPU/memory) once the UF
  sidecar joined the task — three containers instead of two need more room.
  This roughly doubles the Fargate cost of running this stack.
- **Log rotation is basic.** `logging.logback.rollingpolicy.*` caps the app's
  log file at 10MB with 3 rotations — enough for a demo, not a sized-for-
  real-traffic policy.
