# Инжекция секретов из Vault в Kubernetes и Jenkins CI/CD

## Содержание

1. [Инжекция секретов в поды Kubernetes](#1-инжекция-секретов-в-поды-kubernetes)
2. [Доставка секретов в Jenkins CI/CD пайплайн](#2-доставка-секретов-в-jenkins-cicd-пайплайн)

---

## 1. Инжекция секретов в поды Kubernetes

### Проверка Vault Agent Injector

Vault Agent Injector уже включен в вашей конфигурации (`injector.enabled: true`). Проверьте:

```bash
# Проверить, что injector работает
kubectl get pods -n vault | grep injector

# Проверить webhook
kubectl get mutatingwebhookconfiguration vault-agent-injector-webhook-config
```

### Как работает Vault Agent Injector

Vault Agent Injector - это Kubernetes Mutating Admission Webhook, который:
1. Перехватывает создание подов с специальными аннотациями
2. Добавляет sidecar контейнер с Vault Agent
3. Vault Agent аутентифицируется в Vault и получает секреты
4. Записывает секреты в файлы или переменные окружения в основной контейнер

### Настройка Vault для инжекции

#### 1. Создать политику для чтения секретов

```bash
# Подключиться к Vault
kubectl exec -it vault-0 -n vault -- sh

# Создать политику для приложения
vault policy write myapp-policy - <<EOF
# Доступ к секретам KV v2 (только чтение)
path "secret/data/myapp/*" {
  capabilities = ["read"]
}

# Доступ к метаданным для листинга
path "secret/metadata/myapp/*" {
  capabilities = ["list", "read"]
}
EOF
```

#### 2. Настроить Kubernetes Auth Method

```bash
# Включить Kubernetes auth (если еще не включен)
vault auth enable kubernetes

# Настроить Kubernetes auth (в поде Vault уже есть токен SA)
vault write auth/kubernetes/config \
  token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
  kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443" \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

# Создать роль для namespace default (или вашего namespace)
vault write auth/kubernetes/role/myapp \
  bound_service_account_names=default \
  bound_service_account_namespaces=default \
  policies=myapp-policy \
  ttl=1h
```

#### 3. Сохранить секреты в Vault

```bash
# Сохранить секреты (KV v2)
vault kv put secret/myapp/config \
  username=admin \
  password=secret-password \
  api_key=api-key-123

# Или через JSON файл
vault kv put secret/myapp/config @config.json
```

### Пример: Инжекция секретов через аннотации

#### Вариант 1: Инжекция в файлы

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp
  namespace: default
  annotations:
    # Включить Vault Agent Injector
    vault.hashicorp.com/agent-inject: "true"
    
    # Адрес Vault (внутренний адрес в Kubernetes)
    vault.hashicorp.com/agent-inject-secret-config: "secret/data/myapp/config"
    
    # Формат шаблона для файла
    vault.hashicorp.com/agent-inject-template-config: |
      {{- with secret "secret/data/myapp/config" }}
      {{ range $k, $v := .Data.data }}
      {{ $k }}={{ $v }}
      {{ end }}
      {{- end }}
    
    # Путь, куда сохранить секреты (в поде)
    vault.hashicorp.com/agent-inject-file-config: "/vault/secrets/config.env"
    
    # Kubernetes Auth Role
    vault.hashicorp.com/role: "myapp"
spec:
  serviceAccountName: default
  containers:
    - name: myapp
      image: nginx:alpine
      volumeMounts:
        - name: vault-secrets
          mountPath: /vault/secrets
  volumes:
    - name: vault-secrets
      emptyDir: {}
```

#### Вариант 2: Инжекция в переменные окружения

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp-env
  namespace: default
  annotations:
    vault.hashicorp.com/agent-inject: "true"
    vault.hashicorp.com/agent-inject-secret-config: "secret/data/myapp/config"
    
    # Шаблон для переменных окружения
    vault.hashicorp.com/agent-inject-template-config: |
      {{- with secret "secret/data/myapp/config" }}
      {{ range $k, $v := .Data.data }}
      export {{ $k }}="{{ $v }}"
      {{ end }}
      {{- end }}
    
    # Загрузить переменные в основной контейнер
    vault.hashicorp.com/agent-inject-command: "/bin/sh -c 'source /vault/secrets/config && /entrypoint.sh'"
    
    vault.hashicorp.com/role: "myapp"
spec:
  serviceAccountName: default
  containers:
    - name: myapp
      image: nginx:alpine
      volumeMounts:
        - name: vault-secrets
          mountPath: /vault/secrets
  volumes:
    - name: vault-secrets
      emptyDir: {}
```

#### Вариант 3: Инжекция JSON конфигурации

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp-json
  namespace: default
  annotations:
    vault.hashicorp.com/agent-inject: "true"
    vault.hashicorp.com/agent-inject-secret-config: "secret/data/myapp/config"
    
    # JSON формат
    vault.hashicorp.com/agent-inject-template-config: |
      {{- with secret "secret/data/myapp/config" }}
      {
        {{- range $k, $v := .Data.data }}
        "{{ $k }}": "{{ $v }}",
        {{- end }}
      }
      {{- end }}
    
    vault.hashicorp.com/agent-inject-file-config: "/vault/secrets/config.json"
    vault.hashicorp.com/role: "myapp"
spec:
  serviceAccountName: default
  containers:
    - name: myapp
      image: nginx:alpine
      volumeMounts:
        - name: vault-secrets
          mountPath: /vault/secrets
  volumes:
    - name: vault-secrets
      emptyDir: {}
```

#### Вариант 4: Несколько секретов

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp-multi
  namespace: default
  annotations:
    vault.hashicorp.com/agent-inject: "true"
    
    # Первый секрет - конфигурация
    vault.hashicorp.com/agent-inject-secret-config: "secret/data/myapp/config"
    vault.hashicorp.com/agent-inject-template-config: |
      {{- with secret "secret/data/myapp/config" }}
      {{ .Data.data | toJSON }}
      {{- end }}
    vault.hashicorp.com/agent-inject-file-config: "/vault/secrets/config.json"
    
    # Второй секрет - API ключи
    vault.hashicorp.com/agent-inject-secret-api-keys: "secret/data/myapp/api-keys"
    vault.hashicorp.com/agent-inject-template-api-keys: |
      {{- with secret "secret/data/myapp/api-keys" }}
      {{ range $k, $v := .Data.data }}
      {{ $k }}={{ $v }}
      {{ end }}
      {{- end }}
    vault.hashicorp.com/agent-inject-file-api-keys: "/vault/secrets/api-keys.env"
    
    vault.hashicorp.com/role: "myapp"
spec:
  serviceAccountName: default
  containers:
    - name: myapp
      image: nginx:alpine
      volumeMounts:
        - name: vault-secrets
          mountPath: /vault/secrets
  volumes:
    - name: vault-secrets
      emptyDir: {}
```

### Аннотации Vault Agent Injector

Основные аннотации:

| Аннотация | Описание | Пример |
|-----------|----------|--------|
| `vault.hashicorp.com/agent-inject` | Включить инжекцию | `"true"` |
| `vault.hashicorp.com/role` | Kubernetes Auth Role | `"myapp"` |
| `vault.hashicorp.com/agent-inject-secret-<name>` | Путь к секрету в Vault | `"secret/data/myapp/config"` |
| `vault.hashicorp.com/agent-inject-template-<name>` | Шаблон для форматирования | См. примеры выше |
| `vault.hashicorp.com/agent-inject-file-<name>` | Путь к файлу в поде | `"/vault/secrets/config.env"` |
| `vault.hashicorp.com/auth-path` | Путь auth method | `"auth/kubernetes"` (по умолчанию) |
| `vault.hashicorp.com/agent-pre-populate` | Предзагрузка секретов | `"true"` |
| `vault.hashicorp.com/agent-pre-populate-only` | Только предзагрузка (без обновления) | `"true"` |

### Пример: Deployment с инжекцией секретов

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/agent-inject-secret-config: "secret/data/myapp/config"
        vault.hashicorp.com/agent-inject-template-config: |
          {{- with secret "secret/data/myapp/config" }}
          DB_HOST={{ .Data.data.db_host }}
          DB_USER={{ .Data.data.db_user }}
          DB_PASS={{ .Data.data.db_pass }}
          {{- end }}
        vault.hashicorp.com/agent-inject-file-config: "/vault/secrets/db.env"
        vault.hashicorp.com/role: "myapp"
    spec:
      serviceAccountName: default
      containers:
        - name: myapp
          image: myapp:latest
          volumeMounts:
            - name: vault-secrets
              mountPath: /vault/secrets
      volumes:
        - name: vault-secrets
          emptyDir: {}
```

### Проверка инжекции

```bash
# Проверить поды
kubectl get pods

# Проверить логи Vault Agent sidecar
kubectl logs <pod-name> -c vault-agent

# Проверить секреты в поде
kubectl exec -it <pod-name> -c <main-container> -- cat /vault/secrets/config.env

# Проверить процессы
kubectl exec -it <pod-name> -- ps aux
```

---

## 2. Доставка секретов в Jenkins CI/CD пайплайн

Для доставки секретов в Jenkins CI/CD пайплайн рекомендуется использовать **AppRole Auth Method**.

### Настройка AppRole в Vault

#### 1. Включить AppRole

```bash
# Подключиться к Vault
kubectl exec -it vault-0 -n vault -- sh

# Включить AppRole (если еще не включен)
vault auth enable approle
```

#### 2. Создать политику для Jenkins

```bash
# Создать политику для Jenkins (чтение секретов для CI/CD)
vault policy write jenkins-policy - <<EOF
# Доступ к секретам для CI/CD
path "secret/data/jenkins/*" {
  capabilities = ["read", "list"]
}

# Доступ к секретам приложений (для деплоя)
path "secret/data/apps/*" {
  capabilities = ["read", "list"]
}

# Доступ к метаданным
path "secret/metadata/*" {
  capabilities = ["list"]
}
EOF
```

#### 3. Создать AppRole для Jenkins

```bash
# Создать AppRole
vault write auth/approle/role/jenkins \
  token_policies="jenkins-policy" \
  token_ttl=1h \
  token_max_ttl=4h \
  bind_secret_id=true \
  secret_id_ttl=8760h  # 1 год (для CI/CD)

# Получить Role ID (публичный - можно хранить в Jenkins credentials)
vault read auth/approle/role/jenkins/role-id

# Создать Secret ID (приватный - хранить в Jenkins credentials)
vault write -f auth/approle/role/jenkins/secret-id
```

### Настройка Jenkins

#### Вариант 1: Jenkins Plugin "HashiCorp Vault Plugin"

1. **Установить плагин:**
   - Jenkins → Manage Jenkins → Manage Plugins
   - Установить "HashiCorp Vault Plugin"

2. **Настроить Vault в Jenkins:**
   - Jenkins → Manage Jenkins → Configure System
   - Найти секцию "HashiCorp Vault"
   - Добавить Vault Server:
     - Name: `vault`
     - URL: `https://vault.buildbyte.ru` (или `http://vault.vault.svc.cluster.local:8200` изнутри K8s)
     - Credentials: AppRole credentials (Role ID и Secret ID)

3. **Создать Credentials для AppRole:**
   - Jenkins → Manage Jenkins → Manage Credentials
   - Добавить "Vault App Role Credential":
     - Role ID: `<role-id-from-vault>`
     - Secret ID: `<secret-id-from-vault>`

#### Вариант 2: Использование Vault CLI в Jenkins Pipeline

Пример Jenkinsfile:

```groovy
pipeline {
    agent any
    
    environment {
        // Vault адрес
        VAULT_ADDR = 'https://vault.buildbyte.ru'
        // Или изнутри K8s кластера:
        // VAULT_ADDR = 'http://vault.vault.svc.cluster.local:8200'
        
        // Role ID и Secret ID (хранить в Jenkins Credentials)
        VAULT_ROLE_ID = credentials('vault-role-id')
        VAULT_SECRET_ID = credentials('vault-secret-id')
    }
    
    stages {
        stage('Get Secrets from Vault') {
            steps {
                script {
                    // Аутентификация в Vault через AppRole
                    sh '''
                        export VAULT_TOKEN=$(vault write -field=token auth/approle/login \
                            role_id=${VAULT_ROLE_ID} \
                            secret_id=${VAULT_SECRET_ID})
                        
                        # Получить секреты
                        export DB_PASSWORD=$(vault kv get -field=password secret/jenkins/database)
                        export API_KEY=$(vault kv get -field=api_key secret/jenkins/api)
                        
                        # Использовать секреты
                        echo "Database password retrieved"
                        echo "API key retrieved"
                    '''
                }
            }
        }
        
        stage('Build') {
            steps {
                // Секреты доступны в этом stage
                sh '''
                    echo "Building with secrets..."
                    # Ваш build процесс
                '''
            }
        }
        
        stage('Deploy') {
            steps {
                sh '''
                    # Использовать секреты для деплоя
                    echo "Deploying with secrets..."
                '''
            }
        }
    }
}
```

#### Вариант 3: Использование withVault для Jenkinsfile

С использованием Vault Plugin:

```groovy
pipeline {
    agent any
    
    stages {
        stage('Get Secrets from Vault') {
            steps {
                // Использование Vault Plugin
                withVault(configuration: [vaultUrl: 'https://vault.buildbyte.ru',
                                         vaultCredentialId: 'vault-approle-credential']) {
                    
                    script {
                        // Получить секреты через Vault Plugin
                        def secrets = [
                            [path: 'secret/jenkins/database', engineVersion: 2, secretValues: [
                                [envVar: 'DB_PASSWORD', vaultKey: 'password'],
                                [envVar: 'DB_USER', vaultKey: 'username']
                            ]],
                            [path: 'secret/jenkins/api', engineVersion: 2, secretValues: [
                                [envVar: 'API_KEY', vaultKey: 'api_key']
                            ]]
                        ]
                        
                        vaultSecret(secrets: secrets)
                    }
                }
            }
        }
        
        stage('Build and Deploy') {
            steps {
                sh '''
                    # Переменные окружения DB_PASSWORD, DB_USER, API_KEY доступны
                    echo "Database: ${DB_USER}@${DB_PASSWORD}"
                    echo "API Key: ${API_KEY}"
                    # Ваш build/deploy процесс
                '''
            }
        }
    }
}
```

#### Вариант 4: Kubernetes Jenkins Pod с инжекцией секретов

Если Jenkins запущен в Kubernetes, можно использовать Vault Agent Injector:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jenkins
  namespace: jenkins
spec:
  template:
    metadata:
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/agent-inject-secret-jenkins: "secret/data/jenkins/config"
        vault.hashicorp.com/agent-inject-template-jenkins: |
          {{- with secret "secret/data/jenkins/config" }}
          {{ range $k, $v := .Data.data }}
          export {{ $k }}="{{ $v }}"
          {{ end }}
          {{- end }}
        vault.hashicorp.com/agent-inject-file-jenkins: "/vault/secrets/jenkins.env"
        vault.hashicorp.com/role: "jenkins"
    spec:
      serviceAccountName: jenkins
      containers:
        - name: jenkins
          image: jenkins/jenkins:lts
          volumeMounts:
            - name: vault-secrets
              mountPath: /vault/secrets
      volumes:
        - name: vault-secrets
          emptyDir: {}
```

И в Jenkinsfile использовать файл с секретами:

```groovy
pipeline {
    agent any
    
    stages {
        stage('Load Secrets') {
            steps {
                sh '''
                    # Загрузить секреты из файла (инжектированного Vault Agent)
                    source /vault/secrets/jenkins.env
                    
                    # Теперь переменные доступны
                    echo "Using secrets from Vault..."
                '''
            }
        }
    }
}
```

### Пример: Сохранение секретов для Jenkins

```bash
# Сохранить секреты для Jenkins CI/CD
vault kv put secret/jenkins/database \
  host=db.example.com \
  username=jenkins \
  password=secure-password \
  port=5432

vault kv put secret/jenkins/api \
  api_key=api-key-123 \
  api_secret=api-secret-456

# Сохранить секреты для деплоя приложений
vault kv put secret/apps/myapp \
  deployment_key=deploy-key-123 \
  docker_registry_password=registry-pass
```

### Безопасность AppRole для CI/CD

1. **Хранить Role ID и Secret ID в Jenkins Credentials:**
   - Не коммитить в Git
   - Использовать Jenkins Credentials Store
   - Ротация Secret ID при необходимости

2. **Ограничить политику:**
   - Минимальные права доступа
   - Только чтение секретов, необходимых для CI/CD
   - Разделение секретов по приложениям

3. **Ротация Secret ID:**
   ```bash
   # Создать новый Secret ID
   vault write -f auth/approle/role/jenkins/secret-id
   
   # Обновить в Jenkins Credentials
   # Удалить старый Secret ID (опционально)
   ```

---

## Примеры шаблонов Vault Agent

### Шаблон для .env файла

```hcl
{{- with secret "secret/data/myapp/config" }}
{{ range $k, $v := .Data.data }}
{{ $k }}={{ $v }}
{{ end }}
{{- end }}
```

### Шаблон для JSON

```hcl
{{- with secret "secret/data/myapp/config" }}
{{ .Data.data | toJSON }}
{{- end }}
```

### Шаблон для YAML

```hcl
{{- with secret "secret/data/myapp/config" }}
{{ range $k, $v := .Data.data }}
{{ $k }}: {{ $v | quote }}
{{ end }}
{{- end }}
```

### Шаблон с условиями

```hcl
{{- with secret "secret/data/myapp/config" }}
{{- if .Data.data.environment }}
ENV={{ .Data.data.environment }}
{{- end }}
{{- end }}
```

---

## Проверка и отладка

### Проверить Vault Agent Injector

```bash
# Проверить webhook
kubectl get mutatingwebhookconfiguration vault-agent-injector-webhook-config -o yaml

# Проверить логи injector
kubectl logs -n vault -l app.kubernetes.io/name=vault-agent-injector

# Проверить поды с инжекцией
kubectl get pods -o jsonpath='{.items[*].metadata.annotations.vault\.hashicorp\.com/agent-inject}'
```

### Отладка инжекции секретов

```bash
# Проверить логи Vault Agent sidecar
kubectl logs <pod-name> -c vault-agent

# Проверить логи основного контейнера
kubectl logs <pod-name> -c <main-container>

# Проверить файлы с секретами в поде
kubectl exec -it <pod-name> -c <main-container> -- ls -la /vault/secrets/

# Проверить содержимое секретов (осторожно!)
kubectl exec -it <pod-name> -c <main-container> -- cat /vault/secrets/config.env
```

---

## Ссылки

- [Vault Agent Injector](https://developer.hashicorp.com/vault/docs/platform/k8s/injector)
- [Vault Agent Templates](https://developer.hashicorp.com/vault/docs/agent-and-proxy/agent/template)
- [AppRole Auth Method](https://developer.hashicorp.com/vault/docs/auth/approle)
- [HashiCorp Vault Jenkins Plugin](https://plugins.jenkins.io/hashicorp-vault-plugin/)
