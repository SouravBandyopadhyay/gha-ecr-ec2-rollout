# GitHub Actions CI/CD Template: Docker Build, Push to Amazon ECR, Roll Out on EC2

**Simple AWS deploy pipeline for small apps and POCs.** Push to `main` and GitHub Actions builds a Docker image, pushes it to **Amazon Elastic Container Registry (ECR)**, SSHs into **Amazon EC2**, pulls the new image, and replaces the running container.

Use this as a **copy-paste DevOps template**: Vite + Node starter, IAM policies, GitHub secrets, and a working ECR → EC2 rollout. Good for learning AWS CI/CD, shipping a side project, or showcasing GitHub Actions + Docker + ECR + EC2 on a resume or portfolio.

```
git push → GitHub Actions (CI/CD)
              │
              ├─ docker build
              ├─ docker push  →  Amazon ECR
              └─ SSH to EC2   →  docker login → pull → stop → run :80
```

One container serves the React (Vite) UI and a Node (Express) API. `/api/health` returns the git SHA so you can confirm the new version is live.

**Suggested GitHub repository name:** `github-actions-ecr-ec2-cicd-template`

| Name | When to use it |
| --- | --- |
| **`github-actions-ecr-ec2-cicd-template`** | Best for search and for “template” clones |
| `simple-aws-cicd-small-apps` | Broader; less AWS-specific |
| `docker-ecr-ec2-rollout` | Short; focuses on the deploy path |

GitHub topics to add: `github-actions`, `cicd`, `docker`, `amazon-ecr`, `amazon-ec2`, `aws`, `devops`, `vite`, `nodejs`, `deploy-template`.

---

## Who this CI/CD template is for

- Rolling out a **small web app** or **POC** without ECS, EKS, or Elastic Beanstalk
- A **DevOps / cloud portfolio project** that proves you can wire GitHub Actions to AWS
- A starting point you can swap the app for (keep the Dockerfile + workflow + IAM)

Not a production HA platform. One EC2, one container, SSH deploy. Fine for demos, internal tools, and learning.

---

## What you get

| Piece | Role |
| --- | --- |
| `client/` | React + Vite frontend |
| `server/` | Express API + static files |
| `Dockerfile` | Multi-stage image (build UI, run Node) |
| `.github/workflows/deploy.yml` | Build → ECR push → EC2 roll |
| `infra/github-actions-iam-policy.json` | IAM for **push** from GitHub Actions |
| `infra/ec2-instance-role-policy.json` | IAM for **pull** on EC2 |
| `infra/ecr-lifecycle-policy.json` | Keep last 5 SHA tags + 10 semver tags; drop untagged |
| `scripts/ec2-bootstrap.sh` | Docker + AWS CLI on a fresh instance |

---

## Two AWS identities (do not mix)

| Identity | Type | Used where | Permission |
| --- | --- | --- | --- |
| GitHub Actions IAM **user** | Access key in GitHub secrets | GitHub-hosted runner | ECR **push** |
| EC2 IAM **role** `ec2-ecr-pull` | Instance profile | The EC2 VM | ECR **pull** |

GitHub keys never go on the instance. EC2 has no long-lived keys.

---

## 1. IAM user for GitHub Actions (ECR push)

1. IAM → **Users** → **Create user** (example: `github-ecr-push`).
2. Attach an inline or customer managed policy from `infra/github-actions-iam-policy.json`.
3. Create an **access key**. Store ID + secret in GitHub.

The policy allows registry login, creating/describing the ECR repo, uploading layers, `PutImage`, and `PutLifecyclePolicy` (so old images can be expired). If this user already exists, add `ecr:PutLifecyclePolicy` to it.

---

## 2. IAM role for EC2 (ECR pull)

### Create the role

1. IAM → **Roles** → **Create role**.
2. Trusted entity: **AWS service** → **EC2** → Next.
3. Skip managed policies → Next.
4. Role name: **`ec2-ecr-pull`** → Create role.

### Attach the pull policy

1. Open `ec2-ecr-pull` → **Add permissions** → **Create inline policy**.
2. JSON → paste `infra/ec2-instance-role-policy.json` (ECR login + pull).
3. Name it `ecr-pull` → Create policy.

### Attach the role to the instance

1. EC2 → Instances → select the instance.
2. **Actions** → **Security** → **Modify IAM role**.
3. Choose `ec2-ecr-pull` → Update. Wait ~30 seconds.

On the instance this must show the role ARN:

```bash
aws sts get-caller-identity
```

Success looks like `assumed-role/ec2-ecr-pull/i-xxxxxxxx`. If you see `Unable to locate credentials`, the instance profile is missing or not applied yet.

---

## 3. EC2 for a simple Docker rollout

Amazon Linux 2023 with a **public IPv4** (or Elastic IP).

Security group:

| Port | Source | Why |
| --- | --- | --- |
| 22 | `0.0.0.0/0` for this POC (GitHub runners have no single IP) | GitHub Actions SSH |
| 80 | `0.0.0.0/0` or your IP | App + workflow health check |

SSH as `ec2-user`.

```bash
sudo dnf update -y
sudo dnf install -y docker
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
```

`enable --now` **starts** the Docker daemon. Install alone is not enough.

Log out of SSH and back in, then:

```bash
docker version
aws sts get-caller-identity
```

`docker version` must show Client **and** Server.

Test ECR login (no spaces in the registry URL; use your account and region):

```bash
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin ACCOUNT.dkr.ecr.us-east-1.amazonaws.com
```

Expect `Login Succeeded`. Or run `scripts/ec2-bootstrap.sh` for Docker + AWS CLI.

---

## 4. Amazon ECR

The workflow creates the repository if it does not exist. You can also create it in the console (example: `ecr-ec2-app`) in the **same region** as `AWS_REGION`.

---

## 5. GitHub Actions secrets

Repo → **Settings** → **Secrets and variables** → **Actions**.

| Secret | Value |
| --- | --- |
| `AWS_ACCESS_KEY_ID` | GitHub IAM **user** access key |
| `AWS_SECRET_ACCESS_KEY` | That user’s secret |
| `AWS_REGION` | e.g. `us-east-1` |
| `ECR_REPOSITORY` | e.g. `ecr-ec2-app` |
| `EC2_HOST` | **Public IPv4 only** — no `http://`, no quotes, not `172.31.x.x` |
| `EC2_USER` | `ec2-user` |
| `EC2_SSH_KEY` | Full private key, including `BEGIN` / `END` |
| `EC2_PORT` | `22` (optional) |

Private DNS such as `ip-172-31-24-73` fails from GitHub with `lookup ... no such host`.

---

## 6. How the pipeline rolls the new version

Push to `main`, push a git tag `v1.2.3`, or **Actions** → **Deploy to ECR and EC2** → **Run workflow**.

1. Build **one** Docker image (extra tags are names, not extra copies).
2. Push tags:
   - `latest` — moving pointer
   - `sha-<7 chars>` — immutable rollout (this is what EC2 runs)
   - `v1.2.3` — only if you pushed a git tag
3. SSH to EC2: `docker login` → `pull sha-…` → replace `ecr-ec2-app` on port **80**.
4. `curl http://$EC2_HOST/api/health` — `version` is `build-<run>` or `v1.2.3`, plus `gitSha` and `image`.

Health `version` uses the GitHub run number (`build-12`) so you get a human version **without** another ECR tag.

**Cost:** ECR stores each unique digest once. A lifecycle policy keeps the last **5** `sha-*` images and **10** `v*` images, and deletes **untagged** images after 1 day. We no longer prune all local images on EC2. Stop or terminate the instance when idle — that is still the real bill.

Rollback on EC2 (tag must still exist):

```bash
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin ACCOUNT.dkr.ecr.us-east-1.amazonaws.com
docker pull ACCOUNT.dkr.ecr.us-east-1.amazonaws.com/REPO:sha-abc1234
docker stop ecr-ec2-app && docker rm ecr-ec2-app
docker run -d --name ecr-ec2-app --restart unless-stopped -p 80:3000 \
  ACCOUNT.dkr.ecr.us-east-1.amazonaws.com/REPO:sha-abc1234
```

The runner keeps AWS keys. The SSH script forwards `IMAGE`, `AWS_REGION`, `ECR_REGISTRY`, `GIT_SHA`, and `APP_VERSION`. Pull auth is the **instance role**.

---

## 7. Verify the deploy and read logs

**Browser**

- `http://<PUBLIC_IP>/`
- `http://<PUBLIC_IP>/api/health`

JSON should include `"status": "ok"`, `version` (`build-N` or `v1.2.3`), short `gitSha`, and `image` (`…:sha-……`).

**GitHub:** Actions → latest run → **Build, push, and roll**.

**EC2:**

```bash
docker ps
docker logs ecr-ec2-app
docker logs -f ecr-ec2-app
curl http://127.0.0.1/api/health
```

Expect `Server listening on 3000`.

---

## Local development

```bash
npm install --prefix client
npm install --prefix server
npm run dev:server
npm run dev:client
```

- UI: http://localhost:5173 (`/api` proxied to Node)
- API: http://localhost:3000/api/health

```bash
docker build -t ecr-ec2-app:local .
docker run --rm -p 3000:3000 -e GIT_SHA=local ecr-ec2-app:local
```

---

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `AccessDenied` on `PutLifecyclePolicy` | GitHub IAM user missing that action | Add `ecr:PutLifecyclePolicy` from `infra/github-actions-iam-policy.json` |
| `lookup ***: no such host` | `EC2_HOST` empty, private DNS, or not public | Secret = public IPv4 |
| `docker: command not found` | Docker not installed on EC2 | `sudo dnf install -y docker` |
| `Cannot connect to the Docker daemon` | Daemon not running | `sudo systemctl enable --now docker` |
| `Unable to locate credentials` on EC2 | No instance role | Attach `ec2-ecr-pull`; wait; retry `sts` |
| `"docker login" requires at most 1 argument` | Space in registry URL | `....dkr.ecr.us-east-1.amazonaws.com` with no spaces |
| Health check fails from Actions | Security group missing inbound 80 | Allow TCP 80 |

---

## Skills this project demonstrates

GitHub Actions CI/CD, Docker multi-stage builds, Amazon ECR push/pull, EC2 instance profiles vs IAM users, least-privilege policies, SSH-based container rollout, and a health-check gate after deploy.

## Security notes

POC only: SSH from the internet is convenient, not production-tight. Prefer AWS Systems Manager later. Do not commit access keys or the `.pem` file. After `usermod -aG docker`, use a new SSH session (or `sudo docker`).
