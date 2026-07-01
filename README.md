# Orders Are Us

This project demonstrates a **production-style microservices platform** for order management, deployed on **AWS ECS Fargate**. The application is built as a set of Go microservices that communicate synchronously via an API gateway and asynchronously through **SQS event-driven workflows**, with infrastructure provisioned entirely through **Terraform** and deployments automated via **GitHub Actions**.

<br>

## Key Features

- **Microservices on ECS Fargate** - Nine independently deployable services running on serverless containers
- **Event-Driven Architecture** - Services communicate asynchronously through SQS, with a dedicated worker orchestrating the order saga and handling failures
- **Monitoring & Alerting** - CloudWatch log-based metrics and alarms across application and infrastructure, with SNS email notifications on breach
- **Multi-Environment** - Separate dev and prod environments with isolated Terraform state and container registries
- **CI/CD Pipelines** - GitHub Actions workflows automate Docker image builds and Terraform deployments

<br>

## Architecture

External traffic enters through the ALB. API routes (`/api/*`, `/auth/*`, `/healthz`, `/livez`) go to the api-gateway; the dashboard UI and `/dashboard/*` routes go directly to dashboard-api. Internal services communicate via Cloud Map DNS and publish/consume events through SQS.

Observability is handled by `Cloudwatch`: ECS and WAF logs are centralised in CloudWatch Log Groups, log patterns are converted to custom metrics via metric filters, and alarms cover application errors and infrastructure health. All alarms publish to an SNS topic that emails recipients.

### Multiple Environments
Having separate dev and prod environments means you can break things freely in dev without any risk to prod. They have completely isolated Terraform state and ECR repositories. The dev environment also has a tighter feedback loop i.e. pushing to the `dev` branch automatically triggers the Docker build and push pipeline for any changed services, whereas prod deployments are always manually triggered.

<br>

## Microservices

| Service | Port | Role |
|---------|------|------|
| **api-gateway** | 8080 | JWT auth, rate limiting, reverse proxy to backend services |
| **order-service** | 8081 | Order CRUD, state machine, SQS event publishing |
| **inventory-service** | 8082 | Product catalogue, stock reservations and releases |
| **payment-service** | 8083 | Payment charges, refunds, and ledger |
| **notification-service** | 8084 | Email notifications with template support |
| **shipping-service** | 8085 | Shipment creation, tracking, and carrier webhooks |
| **dashboard-api** | 8086 | Operations dashboard UI and analytics APIs |
| **worker** | 8090 | SQS consumer - orchestrates the order processing saga |
| **scheduler** | 8091 | Background jobs (reservation expiry, abandoned carts, digests) |

<br>

## Order Lifecycle

Orders follow a strict state machine:

```
pending → confirmed → processing → shipped → delivered
   ↓          ↓           ↓
cancelled  cancelled   cancelled
```

When a customer places an order, the **order-service** creates a `pending` order and publishes an `order.created` event. The **worker** then:

1. Reserves inventory via the inventory service
2. Charges payment via the payment service
3. Sends a confirmation notification
4. Updates the order to `confirmed`

Subsequent status changes trigger further automation - shipment creation on `processing`, shipping notifications on `shipped`, and delivery notifications on `delivered`. Failures at any stage trigger compensating actions (inventory release, order cancellation, failure notifications, and refunds where applicable).

<br>

## Directory Structure

```
./
├── test-metrics.sh                    # Script to validate CloudWatch alarms and metrics
├── services/                          # Go microservices
├── terraform/
│   ├── bootstrap/                     # One-time setup (ECR, S3 state, DNS delegation)
│   │   ├── environments/
│   │   │   ├── dev/
│   │   │   └── prod/
│   │   └── modules/
│   └── deployment/                    # Application infrastructure
│       ├── environments/
│       │   ├── dev/
│       │   └── prod/
│       └── modules/
└── .github
    └── workflows/                     # CI/CD pipelines
```

<br>

## The Opinionated Bits

### Fargate over EC2-backed ECS
With Fargate there are no EC2 instances to manage. Each service gets its own isolated compute and you only pay for what it uses. For a project like this where services have very different load profiles, it's a much cleaner fit than managing a shared EC2 cluster.
 
### CloudWatch over Prometheus + Grafana
Prometheus and Grafana are great but they add operational overhead since you're running and maintaining extra infrastructure just to observe your actual infrastructure. for an AWS-native stack, you'd need exporters and additional config with Prometheus + Grafana, to get the similar coverage that CloudWatch gives you out of the box. Since everything here is already on AWS, CloudWatch is fully managed, natively integrated with ECS, RDS, ALB, and SQS, and is more straightforward to set up.
 
### VPC Endpoints over NAT Gateway
All AWS service traffic (ECR, SQS, Secrets Manager, CloudWatch) stays within the VPC rather than routing through the internet, which removes the need for a NAT Gateway and reduces both cost and attack surface.

<br>

## Setup Instructions

<br>

### Prerequisites

- Terraform (>= 1.11.0)
- AWS CLI configured with credentials
- A **Cloudflare-managed domain** - bootstrap delegates a Route53 subdomain from your root domain, so the domain must already exist in Cloudflare
- A Cloudflare API token with sufficient permissions to access that domain and create DNS records

<br>

### Configuration Steps

**Before deployment, configure the following:**

1. **Bootstrap Infrastructure** (one-time, run locally per environment)

   Bootstrap is applied locally for each environment (`dev` or `prod`). Terraform state for bootstrap is stored **locally** on your machine, not in S3.

   Update the bootstrap tfvars for your target environment (e.g. `terraform/bootstrap/environments/prod/prod-bootstrap.tfvars`):
   - `cloudflare_domain_name` - your root domain in Cloudflare (e.g. `juned.co.uk`)
   - `route53_domain_name` - the subdomain to delegate (e.g. `prod.juned.co.uk` or `dev.juned.co.uk`)
   - `aws_tags` - resource tags including `Owner`

   **Cloudflare API token**

   Create a Cloudflare API token with permissions to access the domain in `cloudflare_domain_name` and add DNS records to it, then export it:

   ```bash
   export CLOUDFLARE_API_TOKEN="your-cloudflare-api-token"
   ```

   **Bootstrap apply**

   ```bash
   cd terraform/bootstrap/environments/prod
   terraform init
   terraform apply -var-file="prod-bootstrap.tfvars"
   ```

      **Bootstrap apply**
 
```bash
   cd terraform/bootstrap/environments/prod
   terraform init
```
 
   The Route53 hosted zone must exist before Cloudflare can be updated with the delegation nameservers, so target it first:
 
```bash
   terraform apply -var-file="prod-bootstrap.tfvars" -target=module.domain.aws_route53_zone.this
```
 
   Then run the full apply:
 
```bash
   terraform apply -var-file="prod-bootstrap.tfvars"
```

   This creates ECR repositories, the S3 Terraform state bucket for deployment, and delegates the Route53 subdomain from Cloudflare.

<br>

2. **Create a GitHub Actions IAM Role (manual, one-time)**
   The CI/CD pipelines authenticate to AWS using OIDC - no static credentials needed. You need to create this manually in AWS before any CI/CD workflow can run:
   - Add GitHub as an OIDC identity provider in IAM (`https://token.actions.githubusercontent.com`)
   - Create an IAM role that trusts that provider, scoped to your repository (e.g. `repo:your-org/your-repo:*`)
   - Attach the permissions your workflows need (ECR push, ECS deploy, Terraform state access, etc.)

<br>

3. **Configure GitHub Actions Secrets**

   Go to GitHub repository → Settings → Secrets and variables → Actions:

   **Secrets:**
   - `AWS_GITHUB_ROLE_ARN` - IAM role ARN for GitHub OIDC authentication (e.g. `arn:aws:iam::123456789012:role/github-cicd-role`)
   - `ECR_REPOSITORY` - ECR registry URL (e.g. `123456789012.dkr.ecr.eu-west-2.amazonaws.com`)

<br>

4. **Update Deployment Variables**

   Edit `terraform/deployment/environments/<environment>/<environment>.tfvars` (e.g. `prod/prod.tfvars` or `dev/dev.tfvars`):
   - `route53_domain_name` - must match the subdomain created during bootstrap (this is the domain you use to access the app)
   - `cloudwatch_alarm_email_endpoint` - email address subscribed to CloudWatch alarm SNS notifications
   - `*_image` variables - ECR image URIs for each service (e.g. `123456789012.dkr.ecr.eu-west-2.amazonaws.com/prod-api-gateway:latest`)
   - `rds_username` - database username
   - `aws_tags` - resource tags

<br>

### Deployment Steps


1. **Build and Push Docker Images**
   - Go to GitHub Actions → Docker Build & Push → Run workflow
   - Choose `all` to build every service, or select an individual service
   - Choose `prod`

2. **Deploy Infrastructure**
   - Go to GitHub Actions → Terraform Plan → Run workflow
     - Choose `prod`
     - Review the plan output to ensure everything looks correct
   - Go to GitHub Actions → Terraform Apply → Run workflow
     - Choose `prod`
     - This provisions VPC, ECS services, RDS, ElastiCache, SQS, CloudWatch, SNS, ALB, WAF, and Route53 records

Similarly, to deploy to the dev environment, choose the  `dev` when carrying out the above deployment steps.

**Note for Dev Environment**: Pushing to the `dev` Git branch with changes under `services/**` automatically triggers the Docker Build & Push workflow. It detects which services changed, builds only those images, scans them with Trivy, and pushes them to the dev ECR repositories (`dev-<service>:latest`). For a first time dev environment deployment, you will still run bootstrap and Terraform Apply for `dev` manually before relying on automatic Docker image builds.

3. **Verify Deployment**
   - Check ECS services are running in the AWS Console
   - Confirm the SNS email subscription for CloudWatch alarms
   - API gateway health check: `https://<route53_domain_name>/healthz`
   - Dashboard: `https://<route53_domain_name>/dashboard`
   - Optionally run `./test-metrics.sh` to validate CloudWatch alarms and metric data (configure the script variables for your environment first)

4. **Destroy Infrastructure**
   - Go to GitHub Actions → Terraform Destroy → Run workflow
     - Choose the same environment used for deployment
     - This removes all deployment resources (bootstrap resources are unaffected)

5. **Destroy Bootstrap** (only when fully decommissioning)
   - Run locally after destroying deployment infrastructure for that environment:
   ```bash
   cd terraform/bootstrap/environments/prod
   terraform destroy -var-file="prod-bootstrap.tfvars"
   ```
   - This removes ECR repositories and the S3 state bucket for that environment

<br>

## How to Use the App

You can use the web GUI at `https://<route53_domain_name>/dashboard`. It signs in with the built-in default admin account, so you can place orders and explore the dashboard without setting up curl or JWT tokens manually.

Alternatively, use the API directly via curl. Replace `<route53_domain_name>` with the value from your deployment tfvars (e.g. `prod.juned.co.uk`).

<br>

### Authentication

Register or log in to obtain a JWT token:

```bash
# Register
curl -X POST "https://<route53_domain_name>/auth/register" \
  -H "Content-Type: application/json" \
  -d '{"email": "customer@example.com", "password": "secret", "name": "Jane Doe"}'

# Login
curl -X POST "https://<route53_domain_name>/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email": "customer@example.com", "password": "secret"}'
```

Use the returned token in subsequent requests:

```bash
export TOKEN="eyJhbGciOiJIUzI1NiIs..."
```

<br>

### API Endpoints

**Health Check** (api-gateway, no auth required)
```bash
curl "https://<route53_domain_name>/healthz"
```

**Create a Product** (required before placing an order, there is no seed data)
```bash
curl -X POST "https://<route53_domain_name>/api/inventory/products" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "id": "widget-01",
    "name": "Widget",
    "sku": "WDG-001",
    "price": 29.99,
    "stock": 100
  }'
```

**Create an Order**
```bash
curl -X POST "https://<route53_domain_name>/api/orders/" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "items": [
      {"product_id": "widget-01", "quantity": 2, "price": 29.99}
    ]
  }'
```

**List Orders**
```bash
curl "https://<route53_domain_name>/api/orders/" \
  -H "Authorization: Bearer $TOKEN"
```

**Get Order by ID**
```bash
curl "https://<route53_domain_name>/api/orders/1" \
  -H "Authorization: Bearer $TOKEN"
```

**Update Order Status** (must be a valid state transition, e.g. `confirmed` → `processing`)
```bash
curl -X PUT "https://<route53_domain_name>/api/orders/status" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"order_id": 1, "new_status": "processing"}'
```

**List Products**
```bash
curl "https://<route53_domain_name>/api/inventory/products" \
  -H "Authorization: Bearer $TOKEN"
```

**List Shipments**
```bash
curl "https://<route53_domain_name>/api/shipping/shipments" \
  -H "Authorization: Bearer $TOKEN"
```

**Track Shipment** (use the `tracking_number` from the list shipments response)
```bash
curl "https://<route53_domain_name>/api/shipping/track/<tracking_number>" \
  -H "Authorization: Bearer $TOKEN"
```

<br>

### Dashboard

Access the operations dashboard at `https://<route53_domain_name>/dashboard` for order statistics, revenue overview, inventory alerts, and shipping status.

Dashboard API endpoints are served directly by the dashboard-api service (routed via the ALB, not the API gateway):

```bash
curl "https://<route53_domain_name>/dashboard/summary"
curl "https://<route53_domain_name>/dashboard/orders/stats"
curl "https://<route53_domain_name>/dashboard/revenue"
curl "https://<route53_domain_name>/dashboard/inventory/alerts"
curl "https://<route53_domain_name>/dashboard/shipping/overview"
```

<br>

## Cleanup

**Destroy application infrastructure** (via GitHub Actions Terraform Destroy workflow, or locally):

```bash
cd terraform/deployment/environments/prod
terraform destroy -var-file="prod.tfvars"
```

**Destroy bootstrap resources** (run locally after deployment infrastructure is destroyed - only when fully decommissioning):

```bash
cd terraform/bootstrap/environments/prod
terraform destroy -var-file="prod-bootstrap.tfvars"
```

<br>

## Notes

- JWT authentication in the API gateway accepts any email/password combination for demonstration purposes. In production, integrate with a proper identity provider.
- Bootstrap must be applied before deployment. Deployment Terraform relies on the S3 backend bucket and ECR repositories created during bootstrap.
- Bootstrap and deployment each support separate `dev` and `prod` environments. Run bootstrap locally for each environment before deploying the respective environment's deployment infrastructure.

<br>

## Possible Improvements

- **Distributed tracing** - Add OpenTelemetry or AWS X-Ray across the api-gateway and microservices to trace requests end-to-end, making it easier to debug slow or failed order flows across service boundaries.
