# Telegram Toxicity Moderator - AWS EKS Production Deployment

> **Assignment 4**: Microservices-based ML inference platform for real-time sentiment analysis at 500 RPS avg, 1500 RPS peak

An end-to-end production-ready Telegram bot that automatically detects toxic messages using AI and alerts moderators. Implements all reliability and cost optimization requirements.

## 🎯 Project Requirements Met

| Requirement               | Implementation                              | Status |
| ------------------------- | ------------------------------------------- | ------ |
| **Communication**         | REST API with FastAPI, Pydantic schemas     | ✅     |
| **HPA Rules**             | Multi-metric autoscaling (CPU + Memory)     | ✅     |
| **Pod Disruption Budget** | minAvailable: 1 for both services           | ✅     |
| **Circuit Breaking**      | 5 failures, 30s recovery, fail-open         | ✅     |
| **Timeouts**              | 5s HTTP client, 3s probes                   | ✅     |
| **Right-Sizing**          | Optimized CPU/memory requests/limits        | ✅     |
| **Spot Instances**        | 70% cost savings                            | ✅     |
| **Autoscaling Policy**    | Fast scale-up (30s), slow scale-down (5min) | ✅     |
| **Monitoring**            | Prometheus metrics + ServiceMonitors        | ✅     |

## 🏗️ Architecture

```
Telegram Updates
      ↓
  ALB Ingress (rate limit: 1500 RPS)
      ↓
telegram-bot-svc (2-10 pods)
  - Circuit breaker
  - 5s timeout
  - Prometheus metrics
      ↓
toxicity-svc (1-5 pods)
  - toxic-bert ML model
  - Inference monitoring
      ↓
Moderator Alert
```

### Microservices

1. **toxicity-svc**: FastAPI + HuggingFace `unitary/toxic-bert` for toxicity scoring
2. **telegram-bot-svc**: Webhook handler with circuit breaker and monitoring

## 📁 Repository Structure

```
telegram-toxicity/
├─ services/
│  ├─ toxicity-svc/          # ML inference service
│  │  ├─ app.py              # FastAPI + Prometheus metrics
│  │  ├─ requirements.txt    # transformers, torch, prometheus-client
│  │  └─ Dockerfile
│  └─ telegram-bot-svc/      # Webhook handler
│     ├─ bot.py              # Circuit breaker + metrics
│     ├─ requirements.txt    # circuitbreaker, prometheus-client
│     └─ Dockerfile
├─ k8s/                      # Kubernetes manifests
│  ├─ 00-namespace.yaml
│  ├─ 01-config-secrets.yaml
│  ├─ 10-toxicity.yaml       # Deployment + Service + PDB
│  ├─ 20-telegram-bot.yaml   # Deployment + Service + PDB
│  ├─ 30-ingress.yaml        # ALB Ingress
│  ├─ 40-autoscaling.yaml    # HPA with multi-metric
 │  ├─ 45-pod-disruption-budget.yaml # PodDisruptionBudget for both services
 │  └─ 50-monitoring.yaml     # ServiceMonitors
├─ scripts/                  # Deployment automation
│  ├─ build-push-ecr.ps1
│  ├─ create-eks-cluster.ps1
│  ├─ deploy-k8s.ps1
│  ├─ setup-webhook.ps1
│  ├─ scale-up-loadtest.ps1    # scale nodes + replicas for load testing
│  └─ scale-down.ps1          # scale cluster back down after testing
├─ .github/workflows/
│  └─ build-deploy.yml       # Automated CI/CD
├─ deploy-complete.ps1       # Full deployment script
├─ load-test.js              # k6 full load test (500 avg, 1500 peak)
├─ load-test-light.js        # k6 light test for small clusters (30-50 RPS)
├─ grafana-dashboard.json    # Prebuilt Grafana dashboard to import
├─ grafana-queries.txt       # Prometheus queries for dashboard panels
└─ README.md                 # This file
```

---

## 📋 Table of Contents

1. [Requirements Implementation](#requirements-implementation)
2. [Quick Start](#quick-start)
3. [Local Testing](#local-testing)
4. [GitHub Actions Deployment](#github-actions-deployment)
5. [Manual Deployment](#manual-deployment)
6. [Monitoring & Observability](#monitoring--observability)
7. [Cost Analysis](#cost-analysis)
8. [Troubleshooting](#troubleshooting)

---

## 📝 Requirements Implementation

### 1. Communication Style and Contracts

**REST API with Schemas:**

```python
# services/telegram-bot-svc/bot.py
class Update(BaseModel):  # Pydantic schema
    update_id: int
    message: dict | None = None

@app.post("/webhook")
async def webhook(update: Update):
    # REST endpoint with schema validation
```

**Error Strategy:** Fail-open pattern - don't alert moderators if toxicity service is down

### 2. Reliability Features

#### A. HPA Rules (Horizontal Pod Autoscaler)

**Bot Service:**

- Min: 2 replicas, Max: 10 replicas
- CPU target: 60%, Memory target: 70%
- Scale up: 30s window, 100% increase or +2 pods every 15s
- Scale down: 5min window, 50% decrease every 60s

**Toxicity Service:**

- Min: 1 replica, Max: 5 replicas
- CPU target: 70%, Memory target: 75%
- Scale up: 60s window, 100% increase or +1 pod every 30s

**File:** `k8s/40-autoscaling.yaml`

#### B. Pod Disruption Budget

Both services configured with `minAvailable: 1` to ensure:

- Zero-downtime during rolling updates
- Protection against node failures
- Always at least 1 pod serving traffic

**Files:** `k8s/10-toxicity.yaml`, `k8s/20-telegram-bot.yaml`

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: telegram-bot-pdb
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: telegram-bot-svc
```

#### C. Circuit Breaking

**Implementation:** Python `circuitbreaker` library

- Threshold: 5 consecutive failures
- Recovery: 30 seconds
- Monitoring: `circuit_breaker_open` Prometheus metric

**File:** `services/telegram-bot-svc/bot.py`

```python
@circuit(failure_threshold=5, recovery_timeout=30)
async def call_toxicity_service(text: str):
    try:
        r = await client.post(TOXICITY_URL, json={"text": text}, timeout=5.0)
        CIRCUIT_BREAKER_STATE.set(0)  # Closed
        return r.json()
    except Exception:
        CIRCUIT_BREAKER_STATE.set(1)  # Open
        raise
```

#### D. Timeouts

- HTTP client: 5 seconds (configurable via `TIMEOUT` env var)
- Readiness probes: 2-3 seconds
- Liveness probes: 2-3 seconds
- Telegram API calls: 5 seconds

### 3. Cost Controls

#### A. Autoscaling Policy

- Only run pods needed for current load
- Aggressive scale-down (5min stabilization)
- Capped max replicas prevent runaway costs

#### B. Right-Sizing

**Bot Pods:**

```yaml
resources:
  requests: { cpu: "100m", memory: "128Mi" }
  limits: { cpu: "300m", memory: "256Mi" }
```

**Toxicity Pods:**

```yaml
resources:
  requests: { cpu: "500m", memory: "1.5Gi" }
  limits: { cpu: "1000m", memory: "2Gi" }
```

#### C. Spot Instances

Deployment uses EC2 Spot instances for 70% cost savings:

```powershell
eksctl create cluster --spot --instance-types t3.medium,t3.large
```

### 4. Performance

**500 RPS Average:**

- 2 bot pods (250 RPS each) + 5 toxicity pods (100 RPS each)

**1500 RPS Peak:**

- Auto-scales to 6-8 bot pods in ~30-60 seconds
- Toxicity service bottleneck at 500 RPS (5 pods × 100 RPS)

### 5. Monitoring

**Prometheus Metrics Exported:**

- `http_requests_total{method, endpoint, status}` - Request count
- `http_request_duration_seconds` - Latency
- `circuit_breaker_open` - Circuit breaker state
- `messages_processed_total{toxic}` - Message stats
- `toxicity_errors_total{error_type}` - Error tracking
- `inference_duration_seconds` - ML inference time

**Files:** `services/*/app.py`, `services/*/bot.py`, `k8s/50-monitoring.yaml`

---

## 🚀 Quick Start

### Prerequisites

- AWS CLI configured with appropriate credentials
- Docker installed
- kubectl installed
- eksctl installed
- A Telegram bot token ([create one via @BotFather](https://t.me/BotFather))
- A moderator chat ID (can be a group, channel, or user)

### Step 1: Create EKS Cluster

**Linux/Mac:**

```bash
./scripts/create-eks-cluster.sh us-west-2
```

**Windows (PowerShell):**

```powershell
.\scripts\create-eks-cluster.ps1 us-west-2
```

This will create a cluster named `tg-moderator` with 2 t3.large nodes.

### Step 2: Install AWS Load Balancer Controller

Follow the [AWS Load Balancer Controller installation guide](https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html) or use:

```bash
# Create IAM policy
curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file://iam-policy.json

# Create IAM service account
eksctl create iamserviceaccount \
  --cluster=tg-moderator \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn=arn:aws:iam::<ACCOUNT_ID>:policy/AWSLoadBalancerControllerIAMPolicy \
  --override-existing-serviceaccounts \
  --approve

# Install via Helm
helm repo add eks https://aws.github.io/eks-charts
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=tg-moderator \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

### Step 3: Build and Push Docker Images

Update the Kubernetes manifests with your AWS account ID and region:

**Linux/Mac:**

```bash
./scripts/update-k8s-images.sh 123456789012 us-west-2
```

**Windows (PowerShell):**

```powershell
.\scripts\update-k8s-images.ps1 123456789012 us-west-2
```

Build and push images to ECR:

**Linux/Mac:**

```bash
./scripts/build-push-ecr.sh 123456789012 us-west-2
```

**Windows (PowerShell):**

```powershell
.\scripts\build-push-ecr.ps1 123456789012 us-west-2
```

### Step 4: Configure Secrets

Edit `k8s/01-config-secrets.yaml` and replace:

- `<YOUR_TELEGRAM_BOT_TOKEN>` with your bot token from @BotFather
- `<YOUR_MODERATOR_CHAT_ID>` with your moderator chat ID

To get your chat ID, add the bot to the chat and send a message, then visit:

```
https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates
```

### Step 5: Deploy to Kubernetes

**Linux/Mac:**

```bash
./scripts/deploy-k8s.sh
```

**Windows (PowerShell):**

```powershell
.\scripts\deploy-k8s.ps1
```

Wait for the ingress to provision (may take 3-5 minutes):

```bash
kubectl get ingress telegram-ingress -n telegram -w
```

### Step 6: Set Up Telegram Webhook

Get the ALB DNS name:

```bash
kubectl get ingress telegram-ingress -n telegram
```

Set the webhook (replace with your values):

**Linux/Mac:**

```bash
./scripts/setup-webhook.sh <YOUR_BOT_TOKEN> http://<ALB_DNS>/webhook
```

**Windows (PowerShell):**

```powershell
.\scripts\setup-webhook.ps1 <YOUR_BOT_TOKEN> http://<ALB_DNS>/webhook
```

### Step 7: Test!

1. Add the bot to a group you want to moderate
2. Give the bot admin permissions (to read messages)
3. Add the bot to your moderator chat/group
4. Send a toxic message in the monitored group
5. You should receive an alert in your moderator chat

## 🖥️ Demo & Logs (recommended terminal commands)

Use the following terminals during your demo to monitor behavior, autoscaling, and logs.

Terminal 1 - Watch pods (real-time):

```powershell
kubectl get pods -n telegram -w
```

Terminal 2 - Bot logs (follow, increase concurrency if needed):

```powershell
# If you have many pods, increase max log requests or follow one pod
kubectl logs -n telegram -l app=telegram-bot-svc -f --tail=20 --max-log-requests=10
# Or follow a single pod:
kubectl logs -n telegram <telegram-bot-pod-name> -f --tail=50
```

Terminal 3 - Toxicity service logs:

```powershell
kubectl logs -n telegram -l app=toxicity-svc -f --tail=20
```

Terminal 4 - Run load test (in another window):

```powershell
# Full load test (requires scale-up)
k6 run load-test.js
# Light test (for single-node/demo)
k6 run load-test-light.js
```

Terminal 5 - HPA status (watch autoscaling):

```powershell
kubectl get hpa -n telegram -w
```

Notes:

- If you prefer colored, multi-pod logs, install `stern` and run `stern telegram-bot-svc -n telegram --tail 50`.
- When following many pods you may need `--max-log-requests` to increase concurrency.

## 🔬 Health & Debug

To check service health directly (bypass ingress), port-forward the service and open `/healthz` in your browser:

```powershell
kubectl port-forward svc/telegram-bot-svc 8080:80 -n telegram
# Then open: http://localhost:8080/healthz
```

To view the webhook info from Telegram:

```powershell
curl https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getWebhookInfo
```

## 🧪 Testing

### Test toxicity service locally:

**Linux/Mac:**

```bash
./scripts/test-toxicity-local.sh
```

**Windows (PowerShell):**

```powershell
.\scripts\test-toxicity-local.ps1
```

### Check deployment status:

```bash
kubectl get pods -n telegram
kubectl logs deploy/telegram-bot-svc -n telegram
kubectl logs deploy/toxicity-svc -n telegram
```

### Manual test of toxicity API:

```bash
kubectl port-forward deploy/toxicity-svc 8080:8080 -n telegram

curl -X POST http://localhost:8080/analyze \
  -H 'Content-Type: application/json' \
  -d '{"text":"you are an idiot"}'
```

## 🔄 CI/CD with GitHub Actions

The repository includes a GitHub Actions workflow that automatically builds and deploys on push to `main`.

### Setup:

1. Create an IAM OIDC provider for GitHub in your AWS account
2. Create an IAM role `GitHubOIDCDeployRole` with permissions for:
   - ECR (push images)
   - EKS (describe cluster, update kubeconfig)
3. Update `.github/workflows/build-deploy.yml` with your `ACCOUNT_ID` and `REGION`
4. Push to main branch

The workflow will:

- Build both Docker images
- Push to ECR
- Deploy to EKS automatically

## 📊 Monitoring & Troubleshooting

### Check pod status:

```bash
kubectl get pods -n telegram
kubectl describe pod <pod-name> -n telegram
```

### View logs:

```bash
# Bot logs
kubectl logs -f deploy/telegram-bot-svc -n telegram

# Toxicity service logs
kubectl logs -f deploy/toxicity-svc -n telegram
```

### Check ingress:

```bash
kubectl get ingress telegram-ingress -n telegram
kubectl describe ingress telegram-ingress -n telegram
```

### Verify webhook:

```bash
curl https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getWebhookInfo
```

### Common issues:

**Webhook not receiving messages:**

- Verify bot is added to the group
- Check bot has admin permissions
- Verify webhook URL is correct: `curl https://api.telegram.org/bot<TOKEN>/getWebhookInfo`
- Check ingress has external address: `kubectl get ingress -n telegram`

**Toxicity service not responding:**

- Check pod status: `kubectl get pods -n telegram`
- Model download takes time on first start (~1-2 minutes)
- Increase memory if OOMKilled: edit `k8s/10-toxicity.yaml`

**No alerts in moderator chat:**

- Verify `MOD_CHAT_ID` is correct
- Check bot is added to moderator chat
- Review bot logs for errors

## ⚙️ Configuration

### Toxicity threshold:

Edit `k8s/01-config-secrets.yaml` and change `TOX_THRESHOLD` (default: 0.5)

### Scaling:

- Edit `k8s/40-autoscaling.yaml` to adjust min/max replicas
- Bot service: scales 2-10 based on CPU (60%)
- Toxicity service: scales 1-5 based on CPU (70%)

### Resources:

Edit resource limits in deployment files:

- `k8s/10-toxicity.yaml` - toxicity service (1-1.5 CPU, 2-3Gi memory)
- `k8s/20-telegram-bot.yaml` - bot service (200-400m CPU, 256-512Mi memory)

## 🏗️ Architecture Details

### Communication & Contracts

- REST/JSON APIs between services
- `/webhook` endpoint receives Telegram updates
- `/analyze` endpoint processes text for toxicity
- 10s timeout for inference calls (fail-open strategy)

### Resilience

- Readiness/liveness probes on all services
- Horizontal Pod Autoscaling (HPA) based on CPU
- Fail-open on inference errors (no alert)
- Idempotent webhook handler

### Cost Optimization

- CPU-only inference (no expensive GPUs)
- Right-sized resource requests
- Auto-scaling reduces idle costs
- Consider Spot instances for toxicity-svc

### Security

- Bot tokens stored in Kubernetes Secrets
- RBAC to limit secret access
- Consider IRSA for AWS SDK calls
- Private VPC with public ALB

## 📈 Production Readiness Checklist

- [ ] SSL/TLS certificate on ALB (use cert-manager or ACM)
- [ ] Set up CloudWatch logging
- [ ] Configure Prometheus/Grafana monitoring
- [ ] Implement message deletion (bot needs delete permissions)
- [ ] Add rate limiting on webhook endpoint
- [ ] Set up alerting for service downtime
- [ ] Configure backup and disaster recovery
- [ ] Implement log aggregation (ELK/CloudWatch Logs)
- [ ] Add request authentication between services
- [ ] Use Secrets Manager or Parameter Store for sensitive data

## 🧹 Cleanup

Delete all resources:

```bash
# Delete Kubernetes resources
kubectl delete namespace telegram

# Delete EKS cluster
eksctl delete cluster --name tg-moderator --region us-west-2

# Delete ECR repositories
aws ecr delete-repository --repository-name toxicity-svc --force
aws ecr delete-repository --repository-name telegram-bot-svc --force
```

## 🤝 Contributing

Pull requests are welcome! For major changes, please open an issue first.

## 🔗 Links

- [Telegram Bot API](https://core.telegram.org/bots/api)
- [toxic-bert model](https://huggingface.co/unitary/toxic-bert)
- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)

## 📧 Support

For issues and questions, please open a GitHub issue.

---

**Built with ❤️ for safer Telegram communities**
