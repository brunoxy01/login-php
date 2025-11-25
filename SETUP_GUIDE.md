# 🚀 Guia de Setup: Kubernetes + GitHub Actions + Dynatrace

Este guia explica **onde** e **como** configurar toda a infraestrutura necessária.

---

## 📍 Onde o Kubernetes vai rodar?

### **IMPORTANTE:** O K8s NÃO roda dentro do GitHub Actions!

O GitHub Actions **apenas orquestra** o deployment. O cluster Kubernetes precisa estar rodando em algum provedor cloud:

### Opções de Cluster Kubernetes:

#### **Opção 1: AWS EKS** (Recomendado para vocês)
```bash
# Criar cluster EKS
eksctl create cluster \
  --name php-login-cluster \
  --region us-east-1 \
  --nodegroup-name standard-workers \
  --node-type t3.medium \
  --nodes 2 \
  --nodes-min 1 \
  --nodes-max 3 \
  --managed
```

#### **Opção 2: Azure AKS**
```bash
# Criar cluster AKS
az aks create \
  --resource-group myResourceGroup \
  --name php-login-cluster \
  --node-count 2 \
  --enable-addons monitoring \
  --generate-ssh-keys
```

#### **Opção 3: Google GKE**
```bash
# Criar cluster GKE
gcloud container clusters create php-login-cluster \
  --num-nodes=2 \
  --machine-type=e2-medium \
  --zone=us-central1-a
```

#### **Opção 4: Local/Dev (minikube, kind)**
⚠️ Apenas para testes locais, não para produção!
```bash
minikube start --nodes 2
```

---

## 🔄 Como funciona o fluxo?

```
┌─────────────────┐
│  Developer      │
│  git push       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ GitHub Actions  │ ◄── Roda na infraestrutura do GitHub (runners)
│ (Pipeline)      │
│  1. Build       │
│  2. Test        │
│  3. Deploy      │ ──┐
└─────────────────┘   │
                      │ kubectl apply
                      ▼
            ┌──────────────────┐
            │  Kubernetes      │ ◄── Roda no SEU cluster (AWS/Azure/GCP)
            │  Cluster (EKS)   │
            │                  │
            │  ┌────────────┐  │
            │  │ Pod: PHP   │  │
            │  │ + OneAgent │  │
            │  └────────────┘  │
            └────────┬─────────┘
                     │
                     ▼
            ┌──────────────────┐
            │  Dynatrace       │ ◄── SaaS do Dynatrace (fov31014)
            │  Tenant          │
            │  (Monitoring)    │
            └──────────────────┘
```

---

## 🔧 Setup Passo a Passo

### **PASSO 1: Criar Cluster Kubernetes**

Escolha uma das opções acima e crie seu cluster. Depois:

```bash
# Verificar se está conectado
kubectl cluster-info

# Deve mostrar algo como:
# Kubernetes control plane is running at https://xxx.eks.amazonaws.com
```

---

### **PASSO 2: Instalar Dynatrace OneAgent Operator**

O OneAgent precisa estar instalado no cluster ANTES do deploy:

```bash
# 1. Criar namespace do Dynatrace
kubectl create namespace dynatrace

# 2. Obter token da Dynatrace
# Dynatrace → Access Tokens → Generate new token
# Scopes necessários:
# - PaaS integration - Installer download
# - API v1: Read configuration
# - API v2: Read entities

# 3. Criar secret com o token
kubectl -n dynatrace create secret generic dynakube \
  --from-literal="apiToken=dt0c01.YOUR_API_TOKEN" \
  --from-literal="dataIngestToken=dt0c01.YOUR_DATA_INGEST_TOKEN"

# 4. Instalar Dynatrace Operator
kubectl apply -f https://github.com/Dynatrace/dynatrace-operator/releases/latest/download/kubernetes.yaml

# 5. Criar DynaKube (configuração do OneAgent)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: dynakube-connection
  namespace: dynatrace
type: Opaque
stringData:
  apiToken: "dt0c01.YOUR_API_TOKEN"
  dataIngestToken: "dt0c01.YOUR_DATA_INGEST_TOKEN"
---
apiVersion: dynatrace.com/v1beta1
kind: DynaKube
metadata:
  name: dynakube
  namespace: dynatrace
spec:
  apiUrl: https://fov31014.live.dynatrace.com/api
  oneAgent:
    cloudNativeFullStack:
      enabled: true
  activeGate:
    capabilities:
      - routing
      - kubernetes-monitoring
EOF

# 6. Verificar instalação
kubectl -n dynatrace get pods
# Deve mostrar pods do operator e oneagent rodando
```

---

### **PASSO 3: Configurar GitHub Secrets**

Agora vamos configurar os secrets no GitHub:

#### **3.1 Docker Registry (GitHub Container Registry)**

1. Criar Personal Access Token:
   - GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
   - Generate new token
   - Scopes: `write:packages`, `read:packages`, `delete:packages`
   - Copiar o token gerado

2. Adicionar secrets no repositório:
   - Repositório → Settings → Secrets and variables → Actions → New repository secret

```
Nome: DOCKER_REGISTRY
Valor: ghcr.io

Nome: DOCKER_USERNAME
Valor: aborigene  (seu username do GitHub)

Nome: DOCKER_PASSWORD
Valor: ghp_xxxxxxxxxxxx  (token gerado acima)
```

#### **3.2 Kubernetes Config**

```bash
# Gerar kubeconfig base64
kubectl config view --minify --flatten | base64 | tr -d '\n'

# Copiar a saída e adicionar no GitHub:
Nome: KUBE_CONFIG
Valor: (colar o base64 gerado)
```

#### **3.3 Dynatrace OAuth2 (para workflows)**

1. No Dynatrace:
   - Settings → Access Tokens → OAuth clients → Create OAuth client
   - Name: `github-actions-php-login`
   - Scopes: `automation:workflows:run`
   - Criar e copiar Client ID e Client Secret

```
Nome: DT_CLIENT_ID
Valor: dt0s02.T4USOJ3A  (do colega que você mostrou)

Nome: DT_CLIENT_SECRET
Valor: <seu Dynatrace Client Secret - OAuth2>

Nome: DT_TENANT_URL
Valor: https://fov31014.apps.dynatrace.com

Nome: DT_WORKFLOW_ID (opcional, já está hardcoded no script)
Valor: 409c00f9-c459-4bd9-9fc5-e8464542d17f
```

#### **3.4 Dynatrace API Token (para logs)**

1. No Dynatrace:
   - Settings → Access Tokens → API tokens → Generate token
   - Name: `github-actions-log-ingest`
   - Scopes: `logs.ingest`, `metrics.ingest`

```
Nome: DT_API_TOKEN
Valor: <seu Dynatrace API Token para logs>

# Obs: Pode ser o mesmo token que você já tem!
```

---

### **PASSO 4: Testar o Setup**

#### 4.1 Testar Kubernetes localmente

```bash
# Aplicar manifestos
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# Verificar pods
kubectl get pods -l app=php-login

# Verificar service
kubectl get svc php-login-service

# Testar aplicação
kubectl port-forward svc/php-login-service 8080:80
curl http://localhost:8080/login.php?user=test&password=test&type=gold
```

#### 4.2 Testar Scripts Dynatrace localmente

```bash
# Exportar variáveis (use valores reais)
export DT_CLIENT_ID="dt0s02.T4USOJ3A"
export DT_CLIENT_SECRET="<seu-dynatrace-client-secret>"
export DT_TENANT_URL="https://fov31014.apps.dynatrace.com"
export DT_API_TOKEN="<seu-dynatrace-api-token>"

# Testar trigger de workflow
./scripts/trigger_dynatrace_validation.sh

# Testar envio de logs
./scripts/send_dynatrace_logs.sh "INFO" "Teste de log" "test"
```

---

### **PASSO 5: Push e Testar Pipeline**

```bash
# Push da branch
git push -u origin feature/github-actions-k8s-deployment

# Criar Pull Request no GitHub
# Verificar se o pipeline executa (pode falhar no deploy se secrets não estão configurados)

# Após configurar TODOS os secrets, fazer merge para main
# Pipeline executará automaticamente
```

---

## ✅ Checklist Final

Antes de fazer merge para main, verificar:

- [ ] Cluster Kubernetes rodando (EKS/AKS/GKE)
- [ ] Dynatrace OneAgent Operator instalado no cluster
- [ ] Todos os GitHub Secrets configurados:
  - [ ] DOCKER_REGISTRY
  - [ ] DOCKER_USERNAME
  - [ ] DOCKER_PASSWORD
  - [ ] KUBE_CONFIG
  - [ ] DT_CLIENT_ID
  - [ ] DT_CLIENT_SECRET
  - [ ] DT_TENANT_URL
  - [ ] DT_API_TOKEN
- [ ] Manifestos K8s testados localmente
- [ ] Scripts Dynatrace testados localmente

---

## 🆘 Troubleshooting

### Pipeline falha no build
```bash
# Verificar se DOCKER_* secrets estão corretos
# Testar login manual:
echo $DOCKER_PASSWORD | docker login ghcr.io -u $DOCKER_USERNAME --password-stdin
```

### Pipeline falha no deploy
```bash
# Verificar se KUBE_CONFIG está correto
# Testar localmente:
kubectl get nodes
```

### OneAgent não injeta
```bash
# Verificar se operator está rodando
kubectl -n dynatrace get pods

# Verificar logs
kubectl -n dynatrace logs -l app.kubernetes.io/name=dynatrace-operator

# Recriar pods da aplicação
kubectl rollout restart deployment/php-login-app
```

---

## 📞 Perguntas Frequentes

**P: Posso usar meu próprio Docker Hub?**
R: Sim! Mude `DOCKER_REGISTRY=docker.io` e use suas credenciais do Docker Hub.

**P: Preciso de um cluster grande?**
R: Não! 2 nodes t3.medium (AWS) são suficientes para o lab.

**P: Quanto custa?**
R: EKS: ~$0.10/hora (cluster) + ~$0.05/hora (EC2 nodes) = ~$100-150/mês

**P: Posso usar cluster local?**
R: Para dev sim (minikube/kind), mas não para prod e o GitHub Actions não consegue acessar.

**P: Como faço rollback?**
R: `kubectl rollout undo deployment/php-login-app`

---

**Criado para o time de Solutions Engineering da Dynatrace**
