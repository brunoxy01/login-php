# GitHub Secrets Configuration

Configure os seguintes secrets no repositório GitHub: `aborigene/somephp`

Vá em: **Settings → Secrets and variables → Actions → New repository secret**

## Secrets Necessários

### 1. Docker Registry
```
Name: DOCKER_REGISTRY
Value: ghcr.io
```

```
Name: DOCKER_USERNAME
Value: aborigene
```

```
Name: DOCKER_PASSWORD
Value: <seu GitHub Personal Access Token com permissão packages:write>
```

### 2. Kubernetes
```
Name: KUBE_CONFIG
Value: <conteúdo do arquivo /tmp/kubeconfig_base64.txt>
```

Para copiar: `cat /tmp/kubeconfig_base64.txt | pbcopy`

### 3. Dynatrace - OAuth Credentials
```
Name: DT_CLIENT_ID
Value: dt0s02.T4USOJ3A
```

```
Name: DT_CLIENT_SECRET
Value: <seu Dynatrace Client Secret - OAuth2>
```

### 4. Dynatrace - API Token
```
Name: DT_API_TOKEN
Value: <seu Dynatrace API Token para logs>
```

### 5. Dynatrace - Tenant URL
```
Name: DT_TENANT_URL
Value: https://fov31014.apps.dynatrace.com
```

### 6. Dynatrace - Workflow ID
```
Name: DT_WORKFLOW_ID
Value: 409c00f9-c459-4bd9-9fc5-e8464542d17f
```

## Total: 9 Secrets

Após configurar todos os secrets, você pode fazer o commit e push do código para acionar o pipeline!
