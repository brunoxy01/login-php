# PHP Login Application - CI/CD with Dynatrace

Pipeline CI/CD completo para aplicação PHP com validação automática via Dynatrace Site Reliability Guardian.

## 🚀 Pipeline Flow

```
git push → Build Docker Image → Deploy to AKS → Load Tests → Dynatrace Validation ✅
```

## 🏗️ Stack

- **App**: PHP 8.4-FPM Alpine + Redis simulation
- **Registry**: GitHub Container Registry (ghcr.io)
- **K8s**: Azure AKS (3 nodes, East US)
- **Monitoring**: Dynatrace OneAgent + Guardian
- **CI/CD**: GitHub Actions + Self-hosted Runner (AKS)

## 📋 GitHub Secrets Required

```
DOCKER_USERNAME       # GitHub username
DOCKER_PASSWORD       # GitHub Personal Access Token
DOCKER_REGISTRY       # ghcr.io
DT_CLIENT_ID         # Dynatrace OAuth2 Client ID
DT_CLIENT_SECRET     # Dynatrace OAuth2 Client Secret  
DT_WORKFLOW_ID       # Guardian Workflow ID
KUBE_CONFIG          # AKS kubeconfig (base64)
```

## 🎯 Features

- ✅ Automated Docker build & push
- ✅ Zero-downtime deployment
- ✅ Load testing with Locust
- ✅ Dynatrace Four Golden Signals validation
- ✅ Self-hosted runner in Kubernetes

## 📊 Monitoring

**Dynatrace**: https://fov31014.apps.dynatrace.com  
**Guardian**: Site Reliability Guardian → php_login

---

**Status**: ✅ Production Ready  
**Last Update**: December 01, 2025
