# PHP Login Application - Load Testing Lab

A PHP-based login application designed for load testing and Dynatrace monitoring demonstrations. This application simulates different user types and intentionally generates errors for observability testing.

## 🎯 Purpose

This application demonstrates:
- **Load testing** with Locust
- **Dynatrace monitoring** with OneAgent instrumentation
- **Kubernetes deployment** with automated CI/CD
- **Error simulation** for observability validation
- **GitHub Actions** pipeline integration

## 🏗️ Architecture

- **Language**: PHP 8.4
- **Deployment**: Kubernetes (K8s)
- **Monitoring**: Dynatrace OneAgent
- **Load Testing**: Locust
- **CI/CD**: GitHub Actions

## 📋 Application Features

### User Types
The application supports three user types with different behaviors:

- **Gold**: ✅ Always successful (HTTP 200)
- **Silver**: ✅ Always successful (HTTP 200)
- **Platinum**: ⚠️ Generates 401 error when `USER_ENHANCEMENT=true`

### Feature Flag
- `USER_ENHANCEMENT=false`: All user types succeed
- `USER_ENHANCEMENT=true`: Platinum users fail with 401 Unauthorized

This intentional error generation helps demonstrate:
- Error tracking in Dynatrace
- SLO/SLA monitoring
- Alert configuration
- Performance impact of errors

## 🚀 Quick Start

### Local Development

1. **Prerequisites**
   ```bash
   # Install PHP 8.4
   brew install php
   
   # Install Locust
   pip3 install locust
   ```

2. **Run the application**
   ```bash
   # Start PHP server
   USER_ENHANCEMENT=false php -S localhost:8080
   
   # In another terminal, run load tests
   locust --host=http://localhost:8080
   ```

3. **Access**
   - Application: `http://localhost:8080/login.php?user=user1&password=pass&type=gold`
   - Locust UI: `http://localhost:8089`

### Docker Build

```bash
# Build image
docker build -t php-login:latest .

# Run container
docker run -p 8080:8080 -e USER_ENHANCEMENT=false php-login:latest

# Test
curl "http://localhost:8080/login.php?user=test&password=test&type=gold"
```

## ☸️ Kubernetes Deployment

### Prerequisites

1. **Kubernetes cluster** with Dynatrace OneAgent Operator installed
2. **Dynatrace credentials** configured as secrets

### Deploy to K8s

```bash
# Apply manifests
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# Check deployment
kubectl get pods -l app=php-login
kubectl get svc php-login-service

# Get service URL
kubectl get svc php-login-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### Dynatrace Integration

The deployment includes annotations for automatic OneAgent injection:

```yaml
annotations:
  oneagent.dynatrace.com/inject: "true"
  oneagent.dynatrace.com/technologies: "php"
  dynatrace.com/metadata: |
    app_team=platform
    app_service=php_login
    environment=pre-production
```

## 🔄 GitHub Actions CI/CD

### Pipeline Stages

1. **Build**: Creates Docker image and pushes to registry
2. **Test**: Runs Locust load tests (50 users, 2 minutes)
3. **Deploy**: Deploys to Kubernetes cluster
4. **Validate**: Triggers Dynatrace validation workflow

### Required Secrets

Configure these secrets in your GitHub repository:

```
# Docker Registry
DOCKER_REGISTRY       # e.g., ghcr.io or docker.io
DOCKER_USERNAME       # Registry username
DOCKER_PASSWORD       # Registry password/token

# Kubernetes
KUBE_CONFIG          # Base64 encoded kubeconfig file

# Dynatrace OAuth2 (for workflow triggers)
DT_CLIENT_ID         # OAuth2 client ID (e.g., dt0s02.T4USOJ3A)
DT_CLIENT_SECRET     # OAuth2 client secret
DT_WORKFLOW_ID       # Workflow ID to trigger (optional)

# Dynatrace API (for log ingestion)
DT_API_TOKEN         # API token with logs.ingest permission
DT_TENANT_URL        # Tenant URL (e.g., https://fov31014.live.dynatrace.com)
```

### Trigger Pipeline

```bash
# Push to main branch (auto-deploy)
git push origin main

# Manual trigger via GitHub UI
# Go to Actions → Build, Test and Deploy → Run workflow
```

## 🧪 Load Testing

### Locust Configuration

The `locustfile.py` simulates realistic traffic:

- **30%** Platinum users (generates errors)
- **40%** Gold users (success)
- **30%** Silver users (success)

### Run Tests Locally

```bash
# Headless mode (30 seconds)
locust --host=http://localhost:8080 \
       --users=10 \
       --spawn-rate=2 \
       --run-time=30s \
       --headless \
       --html=report.html

# Interactive UI mode
locust --host=http://localhost:8080
# Open http://localhost:8089
```

## 📊 Dynatrace Integration

### Manual Workflow Trigger

```bash
# Set credentials
export DT_CLIENT_ID="your-client-id"
export DT_CLIENT_SECRET="your-client-secret"
export DT_TENANT_URL="https://your-tenant.apps.dynatrace.com"

# Trigger validation
./scripts/trigger_dynatrace_validation.sh
```

### Send Custom Logs

```bash
export DT_API_TOKEN="your-api-token"
export DT_TENANT_URL="https://your-tenant.live.dynatrace.com"

./scripts/send_dynatrace_logs.sh \
  "INFO" \
  "Custom deployment event" \
  "deployment"
```

### Monitoring Features

- ✅ Automatic PHP instrumentation
- ✅ Request/response traces
- ✅ Error tracking (401 errors from platinum users)
- ✅ Performance metrics (response times, throughput)
- ✅ Service dependencies (simulated Redis calls)
- ✅ Custom logs and events

## 🔧 Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `USER_ENHANCEMENT` | `false` | Enable platinum user validation (errors) |
| `DT_CLUSTER_ID` | `php-login-cluster` | Dynatrace cluster identifier |
| `DT_LOG_COLLECTION` | `true` | Enable Dynatrace log collection |

### Kubernetes ConfigMap

Edit `k8s/configmap.yaml` to change runtime configuration:

```yaml
data:
  USER_ENHANCEMENT: "true"  # Enable error simulation
  STAGE: "pre-production"
  SERVICE_NAME: "php_login"
```

## 📁 Project Structure

```
.
├── .github/
│   └── workflows/
│       └── deploy.yml           # CI/CD pipeline
├── k8s/
│   ├── configmap.yaml          # K8s configuration
│   ├── deployment.yaml         # K8s deployment
│   └── service.yaml            # K8s service
├── scripts/
│   ├── trigger_dynatrace_validation.sh  # Trigger DT workflow
│   └── send_dynatrace_logs.sh          # Send logs to DT
├── Dockerfile                  # Container image
├── locustfile.py              # Load test definition
├── login.php                  # Main application
├── RedisClass.php            # Simulated Redis dependency
├── UserEnhancement.php       # User validation logic
└── README.md                 # This file
```

## 🎓 Use Cases

### Demo Scenarios

1. **Normal Operations**: Set `USER_ENHANCEMENT=false`, all requests succeed
2. **Error Simulation**: Set `USER_ENHANCEMENT=true`, 30% requests fail
3. **Load Testing**: Run Locust to generate traffic patterns
4. **SLO Validation**: Use Dynatrace workflows to validate service health
5. **Alert Testing**: Trigger alerts based on error rates

### Educational Topics

- Application Performance Monitoring (APM)
- Distributed tracing
- Error tracking and alerting
- Load testing best practices
- CI/CD pipeline design
- Kubernetes deployment strategies
- Infrastructure as Code (IaC)

## 🤝 Contributing

This is a demonstration/lab application. To modify:

1. Create a feature branch: `git checkout -b feature/your-change`
2. Make your changes
3. Test locally with Docker
4. Push and create a Pull Request
5. GitHub Actions will test automatically

## 📝 License

This is a demonstration project for Dynatrace training and labs.

## 🔗 References

- [Dynatrace Documentation](https://www.dynatrace.com/support/help/)
- [Locust Documentation](https://docs.locust.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

---

**Created for Dynatrace Solutions Engineering demonstrations**
