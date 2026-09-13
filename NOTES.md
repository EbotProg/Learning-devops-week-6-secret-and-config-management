# Week 6 Study Guide — Reusable Terraform + Secrets & Config Management

Goal, per the milestone card: **write reusable, team-ready Terraform and stop
hardcoding secrets anywhere.** This picks up directly from Week 5 — same
infrastructure, refactored into a module, deployed twice (dev + staging), with
every secret currently sitting in your Week 3 `docker-compose.yml`/`.env`
(the Mongo password, Parse app ID, master key, dashboard credentials) moved
into AWS and pulled at runtime instead of baked in.

---

## 1. Writing your own Terraform modules

A module is just a directory of `.tf` files with a clean set of inputs
(`variable` blocks) and outputs (`output` blocks) — you already wrote the
_content_ of one in Week 5, this week is about wrapping it properly.

**Module structure:**

```
modules/
└── month1-infra/
    ├── main.tf         # or split further: vpc.tf, security_groups.tf, ec2.tf, s3.tf, iam.tf
    ├── variables.tf    # every input the module accepts
    ├── outputs.tf      # every value the module exposes to whoever calls it
    └── README.md
```

**Calling it from an environment:**

```hcl
# environments/dev/main.tf
module "infra" {
  source = "../../modules/month1-infra"

  environment         = "dev"
  vpc_cidr            = "10.0.0.0/16"
  instance_type       = "t3.micro"
  bastion_allowed_ip  = var.bastion_allowed_ip
}
```

**Two rules that matter more than they look like they should:**

1. **Shared modules must not configure providers or backends.** Provider and
   backend configuration belongs only in the _root_ module — i.e., inside
   `environments/dev/` and `environments/staging/` themselves, never inside
   `modules/month1-infra/`. If the module configured its own provider, calling
   it from two environments would fight over which configuration wins.
2. **Only expose what the caller actually needs**, both directions. Don't
   make every internal value a variable "just in case" — a narrow, well-named
   interface (`instance_type`, `vpc_cidr`) is easier to use correctly than a
   module with forty optional knobs. Same for outputs: expose
   `bastion_public_ip` because something needs it, not every attribute the
   module happens to have access to.

**Turning Week 5's flat config into this module is mostly a move, not a
rewrite:** take `vpc.tf`, `security_groups.tf`, `ec2.tf`, `s3.tf`, `iam.tf`
as they already exist, drop them into `modules/month1-infra/`, and replace
every hardcoded value that should actually differ between dev and staging
(subnet CIDRs, instance size) with a `var.something` referencing a new
variable in the module's `variables.tf`.

---

## 2. The dev/staging split

This is what the milestone's exact folder layout buys you:

```
environments/
├── dev/
│   ├── main.tf          # calls the module, sets dev-specific variables
│   ├── backend.tf        # dev's OWN state file — key = "dev/terraform.tfstate"
│   └── terraform.tfvars
└── staging/
    ├── main.tf
    ├── backend.tf         # staging's OWN state file — key = "staging/terraform.tfstate"
    └── terraform.tfvars
```

**Each environment gets its own state file, in the same S3 bucket, at a
different `key`.** This is the part people most often get wrong: dev and
staging are **not** two workspaces sharing one state, and they don't run
`terraform apply` from the module directory itself — you `cd` into
`environments/dev` (or `staging`) and run Terraform _there_. Each one has its
own `backend.tf` pointing at a different state file path, so a mistake in dev
can never accidentally touch staging's real resources — they're
completely independent Terraform runs that happen to share the same module
source.

`environments/dev/terraform.tfvars`:

```hcl
instance_type      = "t3.micro"
vpc_cidr           = "10.0.0.0/16"
bastion_allowed_ip = "203.0.113.10"
```

`environments/staging/terraform.tfvars`:

```hcl
instance_type      = "t3.small"    # staging can afford to be a bit closer to prod sizing
vpc_cidr           = "10.1.0.0/16"  # different CIDR so the two VPCs could even peer later
bastion_allowed_ip = "203.0.113.10"
```

Same module, same shape of infrastructure, genuinely different values — this
is the entire point of the exercise, and it's a direct, practical answer to
"why not just copy-paste the Week 5 config into a second folder": copy-paste
means every future change gets made (or forgotten) twice.

> **Alternative you'll see mentioned elsewhere: Terraform workspaces.**
> `terraform workspace new staging` is a real, built-in feature for exactly
> this kind of split — one config, multiple named states. It's a reasonable
> choice when environments are near-identical and short-lived. The
> directory-per-environment approach above is generally preferred once
> environments have genuinely different variable values (like here) or need
> to be reviewed/approved independently in a PR — worth knowing both exist,
> and worth being able to say why you picked the directory approach if asked.

---

## 3. AWS Secrets Manager vs. Parameter Store — which for which secret

Both store a value encrypted at rest and both integrate with IAM. The real
difference is what each is _for_:

|                    | Secrets Manager                | Parameter Store (SecureString)             |
| ------------------ | ------------------------------ | ------------------------------------------ |
| Built for          | Credentials that need rotation | General config + secrets that don't rotate |
| Cost               | ~$0.40/secret/month            | Free (standard tier)                       |
| Automatic rotation | Yes, built in                  | No                                         |

**Applied to your actual secrets** (from your Week 3 `docker-compose.yml`):

- **`MONGO_ROOT_PASSWORD` → Secrets Manager.** This is exactly the case
  Secrets Manager exists for: a database credential that, in a real setup,
  you'd want to rotate periodically without redeploying anything.
- **`PARSE_MASTER_KEY`, `PARSE_APP_ID`, `DASHBOARD_USER`/`DASHBOARD_PASSWORD`
  → Parameter Store (SecureString type).** These are static application
  config that doesn't rotate on a schedule — Parameter Store covers them for
  free and is the right-sized tool, not an under-powered one.

This mixed approach isn't a compromise — it's the standard real-world pattern:
most mature setups use both, Secrets Manager reserved for the smaller set of
values where rotation genuinely matters.

**As Terraform resources:**

```hcl
# secrets.tf
resource "aws_secretsmanager_secret" "mongo_password" {
  name = "${var.environment}/parse-stack/mongo-root-password"
}

resource "aws_secretsmanager_secret_version" "mongo_password" {
  secret_id     = aws_secretsmanager_secret.mongo_password.id
  secret_string = var.mongo_root_password   # supplied via -var or a gitignored .tfvars, never a literal in this file
}

resource "aws_ssm_parameter" "parse_master_key" {
  name  = "/${var.environment}/parse-stack/parse-master-key"
  type  = "SecureString"
  value = var.parse_master_key
}

resource "aws_ssm_parameter" "parse_app_id" {
  name  = "/${var.environment}/parse-stack/parse-app-id"
  type  = "SecureString"
  value = var.parse_app_id
}
```

Note the naming convention: `/{environment}/parse-stack/{name}` — a
hierarchical path (AWS's own recommended pattern for Parameter Store) means
dev and staging automatically get separate, non-colliding secrets just from
the module being called twice with a different `environment` variable.

**The value going into `var.mongo_root_password` itself must never be a
literal in a committed file.** Supply it via a `terraform.tfvars` that's
gitignored, or an environment variable (`TF_VAR_mongo_root_password`) set
in your shell or CI secrets store, not typed into any `.tf` file. This is the
same category of mistake as the hardcoded Mongo password default you had in
your Week 3 `docker-compose.yml` — Terraform variables don't automatically
fix that, you still have to actually keep the real value out of git.

**IAM permissions needed** — extend `ec2-repository-role` from Week 1/5
rather than creating a new role, since this is the same instance that already
needs to reach ECR:

```hcl
resource "aws_iam_role_policy" "read_secrets" {
  name = "read-parse-stack-secrets"
  role = aws_iam_role.ec2_repository_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = [aws_secretsmanager_secret.mongo_password.arn]
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = ["arn:aws:ssm:*:*:parameter/${var.environment}/parse-stack/*"]
      }
    ]
  })
}
```

---

## 4. Injecting secrets into a running container at boot

You're running plain EC2 + Docker Compose, not ECS — so the native
"ECS injects secrets as env vars automatically" integration doesn't apply
here. Two patterns actually fit your setup; pick based on how literally you
want to satisfy "into a running container":

### Option A — fetch secrets on the host, before `docker compose up` (simpler)

A small script run on the EC2 instance, right before starting the stack,
that pulls each secret and writes a fresh `.env` file — which
`docker-compose.yml` already reads via its `${VAR}` interpolation, so nothing
about the compose file itself needs to change:

```bash
#!/usr/bin/env bash
# fetch-secrets.sh — run this before `docker compose up`, not committed to git
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-dev}"

MONGO_ROOT_PASSWORD="$(aws secretsmanager get-secret-value \
  --secret-id "${ENVIRONMENT}/parse-stack/mongo-root-password" \
  --query SecretString --output text)"

PARSE_MASTER_KEY="$(aws ssm get-parameter \
  --name "/${ENVIRONMENT}/parse-stack/parse-master-key" \
  --with-decryption --query 'Parameter.Value' --output text)"

PARSE_APP_ID="$(aws ssm get-parameter \
  --name "/${ENVIRONMENT}/parse-stack/parse-app-id" \
  --with-decryption --query 'Parameter.Value' --output text)"

cat > .env <<EOF
MONGO_ROOT_PASSWORD=${MONGO_ROOT_PASSWORD}
PARSE_MASTER_KEY=${PARSE_MASTER_KEY}
PARSE_APP_ID=${PARSE_APP_ID}
EOF

chmod 600 .env
docker compose up -d
```

No AWS credentials ever need to touch this script directly — it authenticates
via the instance's attached IAM role, the same mechanism you're already using
for ECR.

### Option B — a real container entrypoint that fetches secrets itself

Closer to the literal "inject into a running container at boot" wording: the
container's own entrypoint script calls out to AWS _before_ execing the real
process, so the secret only ever exists inside that container's process
environment, never written to a file on the host at all:

```bash
#!/usr/bin/env bash
# docker-entrypoint.sh, baked into the Parse Server image
set -euo pipefail

export MONGO_ROOT_PASSWORD="$(aws secretsmanager get-secret-value \
  --secret-id "${ENVIRONMENT}/parse-stack/mongo-root-password" \
  --query SecretString --output text)"
export MASTER_KEY="$(aws ssm get-parameter \
  --name "/${ENVIRONMENT}/parse-stack/parse-master-key" \
  --with-decryption --query 'Parameter.Value' --output text)"

exec npm start   # hands off to the real process, which now sees the env vars
```

This needs the AWS CLI installed inside the image (one extra `RUN` line in
your Week 3 Dockerfile) and needs the container to actually reach the
instance metadata service — true by default for containers on the same EC2
host, nothing extra to configure there.

**Either option is a legitimate answer to the milestone.** Option A is less
code and easier to reason about; Option B is the more textbook "secrets
never touch disk" version. Given you already have a working
`docker-compose.yml` from Week 3, Option A is the smaller, lower-risk change
to make first — you can always tighten to Option B later once the basic
flow works.

**What must disappear from `docker-compose.yml` either way:** every
`:-fallback` default currently sitting on a sensitive variable —
`MONGO_ROOT_PASSWORD`, `PARSE_MASTER_KEY`, `DASHBOARD_PASSWORD`. Right now
those env vars are populated from wherever the fetch step put them (a real
`.env` file, or the container's own environment); there's no reason left for
a hardcoded fallback value to exist in the compose file at all once the
secrets pipeline is in place.

---

## 5. Secret scanning — gitleaks

Install:

```bash
# Linux
sudo apt install gitleaks
# macOS
brew install gitleaks
```

**Scan the entire history of a repo** (not just the current files — this
matters, since a secret that was committed once and later deleted is still
sitting in an old commit):

```bash
cd your-repo
gitleaks git -v
```

> Note: older tutorials show `gitleaks detect --source .` — that command was
> deprecated as of gitleaks v8.19.0 in favor of the `git`/`dir`/`stdin`
> subcommands above. If your installed version is older, `detect` still
> works; check `gitleaks version` if the commands above error out.

For a saved report to paste into your README:

```bash
gitleaks git -v --report-format json --report-path gitleaks-report.json
```

**Worth being direct with yourself about before you run this**: given the
history of this project, a full-history scan on your Week 3 repo has a real
chance of flagging the MongoDB password that was hardcoded as a
`docker-compose.yml` default earlier in this course. If it does:

1. **Rotate it immediately** — change the actual MongoDB password in use,
   not just the file. A found secret is a compromised secret regardless of
   whether anyone else has actually seen it.
2. Update the running stack with the new password (via your new Secrets
   Manager entry, now that it exists).
3. **Scrubbing it from git history is optional, not mandatory**, once it's
   rotated — an old, dead password sitting in history is a much smaller
   problem than a live one. If you do want it gone (for a clean portfolio
   repo a stranger might clone), you already have the tool and the exact
   procedure for this from Week 3 — BFG Repo-Cleaner, same as you used for
   the leftover video files.

`trufflehog` is the spec's other named option — same job, different engine
(it verifies many secret types against the actual provider API to confirm a
match is live, not just pattern-shaped, which cuts down on false positives):

```bash
docker run -v "$(pwd):/repo" trufflesecurity/trufflehog:latest git file:///repo
```

Pick one, not both, for the milestone — gitleaks is the more commonly
expected default and is what the deliverable specifically asks for a
"clean gitleaks report" from.

---

## 6. How to actually run the milestone

1. Refactor Week 5's flat `.tf` files into `modules/month1-infra/` — same
   resources, parameterized (section 1).
2. Build `environments/dev/` and `environments/staging/`, each with its own
   `backend.tf` (own state key), each calling the module with different
   `terraform.tfvars` (section 2).
3. `terraform apply` in `environments/dev` — confirm it stands up cleanly.
4. Repeat in `environments/staging` — confirm the _same module_ produces a
   second, independent, correctly-differently-sized environment.
5. Create the Secrets Manager entry + Parameter Store entries (section 3),
   once per environment (the hierarchical naming keeps them separate
   automatically).
6. Extend `ec2-repository-role`'s policy to allow reading them.
7. Wire up Option A or B (section 4) and confirm the Parse stack actually
   comes up successfully pulling secrets from AWS, not from a `.env` you
   hand-edited.
8. Remove every hardcoded secret default from `docker-compose.yml`.
9. Run `gitleaks git -v` across the whole repo, fix anything it finds
   (rotate first, always), and paste the clean report into your README.

---

## 7. Common pitfalls

- **A module that configures its own provider or backend.** Breaks the
  moment you call it from two environments. Provider/backend config belongs
  in `environments/*/`, never in `modules/*/`.
- **Two environments sharing one state file.** If `environments/dev/backend.tf`
  and `environments/staging/backend.tf` ever point at the same S3 key by
  copy-paste accident, `apply` in one environment will think it owns the
  other's resources. Double check the `key =` value differs before your
  first `apply` in each.
- **A Terraform variable that "solves" hardcoding but still has a hardcoded
  value.** `var.mongo_root_password` is only actually secret if the value
  feeding it lives in a gitignored `.tfvars` or your shell environment — a
  `default = "changeme123"` on that variable block defeats the entire point
  just as thoroughly as the old `docker-compose.yml` fallback did.
- **Forgetting the IAM policy update.** The most common failure mode here
  isn't a Terraform error at all — it's the EC2 instance's fetch script
  failing at runtime with an `AccessDenied` on `secretsmanager:GetSecretValue`
  because the role's policy was never actually extended. Test the fetch
  script's AWS calls directly (`aws secretsmanager get-secret-value ...`)
  from the instance itself before assuming the whole pipeline works.
- **Running `gitleaks` once and considering it done.** A one-time scan
  catches what's already there; nothing stops the _next_ commit from
  reintroducing a secret. A pre-commit hook (gitleaks supports this
  natively) is the actual long-term fix — worth mentioning as a "next step"
  in your README even if the milestone only asks for one clean report.

---

## Deliverables checklist, mapped to the milestone card

- [ ] `modules/` — Week 5's infrastructure, refactored into a reusable module
- [ ] `environments/dev` and `environments/staging` — same module, different
      variables, independent state files
- [ ] Mongo connection string and Parse app secrets moved to Secrets Manager
      / Parameter Store, out of every `.env` file
- [ ] Container startup updated to pull secrets at boot (Option A or B),
      never baked in
- [ ] `gitleaks` (or trufflehog) run across full repo history
- [ ] README with the clean scan report, and anything it originally found
      documented as found-and-rotated, not silently fixed
