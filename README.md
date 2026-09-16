# ECR → EC2 CI/CD   

Simple **React (Vite) + Node (Express)** app. Push to `main` and GitHub Actions:

1. Builds one Docker image
2. Pushes it to **Amazon ECR**
3. SSHs into **EC2**, pulls the image, and rolls the running container

The UI calls `/api/health` so you can confirm the new git SHA after each deploy.

## Local development

```bash
npm install --prefix client
npm install --prefix server
npm run dev:server
npm run dev:client
```

- Frontend: http://localhost:5173 (proxies `/api` to Node)
- API: http://localhost:3000/api/health

Build the same image the pipeline uses:

```bash
docker build -t ecr-ec2-app:local .
docker run --rm -p 3000:3000 -e GIT_SHA=local ecr-ec2-app:local
```

## One-time AWS setup

### 1. ECR

Create a repository (or let the workflow create it), for example `ecr-ec2-app`.

### 2. EC2

Use Amazon Linux 2023, public IP, and a security group that allows:

| Port | Source | Why |
| --- | --- | --- |
| 22 | Your IP, or GitHub-hosted runners if you keep SSH open | Deploy over SSH |
| 80 | `0.0.0.0/0` (or your IP) | App traffic |

Attach an **instance profile** with `infra/ec2-instance-role-policy.json` so the box can pull from ECR without storing AWS keys on the instance.

SSH in once and install Docker + AWS CLI:

```bash
# copy scripts/ec2-bootstrap.sh to the instance, then:
bash ec2-bootstrap.sh
```

Log out and back in so the `docker` group applies. Confirm:

```bash
docker version
aws sts get-caller-identity
```

### 3. IAM user for GitHub Actions

Create a user with `infra/github-actions-iam-policy.json`. Create an access key for that user.

### 4. GitHub repository secrets

| Secret | Example |
| --- | --- |
| `AWS_ACCESS_KEY_ID` | IAM user access key |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret |
| `AWS_REGION` | `ap-south-1` |
| `ECR_REPOSITORY` | `ecr-ec2-app` |
| `EC2_HOST` | Public IPv4 of the instance |
| `EC2_USER` | `ec2-user` (Amazon Linux) or `ubuntu` |
| `EC2_SSH_KEY` | Full private key (`-----BEGIN ... KEY-----`) |
| `EC2_PORT` | `22` |

## Deploy

Push to `main` (or run the **Deploy to ECR and EC2** workflow manually).

The workflow tags the image with the commit SHA and `latest`, then on EC2 it:

- `docker login` to ECR
- `docker pull`
- replaces container `ecr-ec2-app` (`stop` → `rm` → `run` on port 80)

Open `http://<EC2_HOST>/` and check `/api/health` for the new SHA.

## Notes

- One container serves the Vite build and the Express API.
- Keep port 22 locked down in production; GitHub-hosted runners do not have a single static IP. A tighter option later is AWS Systems Manager Session Manager instead of SSH.
- Do not commit AWS keys or the EC2 `.pem` file.
