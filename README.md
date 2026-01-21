# DonInfrastructure

Инфраструктура для развертывания Kubernetes кластеров с использованием Timeweb Cloud.

## Структура проекта

Проект содержит конфигурацию для двух типов кластеров:

- **Services кластер** (`terraform/services/`) — сервисный кластер для инфраструктурных компонентов (Argo CD, Jenkins, Vault, Grafana, Keycloak и т.д.)
- **Dev кластер** (`terraform/dev/`) — кластер для разработки и развертывания микросервисов

## Порядок установки Kubernetes кластера

Пошаговая инструкция по развертыванию полного стека инфраструктуры.

### Предварительные требования

- Установленный Terraform (версия >= 0.13)
- Настроенный `kubectl` для работы с кластером
- Установленный Helm (версия 3.x+)
- Доступ к панели управления Timeweb Cloud
- API ключ Timeweb Cloud с правами на создание ресурсов
- Доступ к Timeweb Cloud S3 Storage для хранения Terraform state

### 1. Настройка Terraform

#### 1.1. Настройка провайдера Timeweb Cloud

Terraform использует провайдер Timeweb Cloud. Настройте переменные окружения для аутентификации:

```bash
# Установить API токен Timeweb Cloud
export TWC_TOKEN="your-timeweb-cloud-api-token"

# Или создать файл terraform/.terraformrc с настройками провайдера
```

**Важно:** API токен должен иметь права на:
- Создание и управление Kubernetes кластерами
- Создание и управление виртуальными машинами
- Доступ к проектам

#### 1.2. Настройка Backend для Terraform State

Terraform использует S3-совместимое хранилище Timeweb Cloud для хранения state. Настройте credentials:

**Вариант 1: Переменные окружения (рекомендуется)**

```bash
export AWS_ACCESS_KEY_ID="your-s3-access-key"
export AWS_SECRET_ACCESS_KEY="your-s3-secret-key"
```

**Вариант 2: Файл backend.hcl (не коммитьте в git!)**

Создайте файл `terraform/backend.hcl`:

```hcl
access_key = "your-s3-access-key"
secret_key = "your-s3-secret-key"
```

И используйте при инициализации:

```bash
terraform init -backend-config=backend.hcl
```

**Важно:** 
- Backend использует bucket: `2d25c8ae-service-terraform-state`
- Endpoint: `https://s3.twcstorage.ru`
- Регион: `ru-1` (используется только для валидации)
- State файлы хранятся в разных путях:
  - Services: `services/terraform.tfstate`
  - Dev: `dev/terraform.tfstate`

#### 1.3. Выбор окружения

Выберите окружение для развертывания:

- **Services кластер** — для инфраструктурных компонентов (Argo CD, Jenkins, Vault, Grafana, Keycloak)
- **Dev кластер** — для разработки и развертывания микросервисов

#### 1.4. Настройка переменных (опционально)

При необходимости измените переменные в соответствующей директории:

**Для Services кластера** (`terraform/services/variables.tf`):
```hcl
variable "cluster_name" {
  default = "services-cluster"  # Имя кластера
}

variable "node_group_node_count" {
  default = 3  # Количество воркер нод
}

variable "project_name" {
  default = "services"  # Имя проекта в Timeweb Cloud
}
```

**Для Dev кластера** (`terraform/dev/variables.tf`):
```hcl
variable "cluster_name" {
  default = "dev-cluster"  # Имя кластера
}

variable "node_group_node_count" {
  default = 2  # Количество воркер нод (меньше для dev)
}

variable "project_name" {
  default = "dev"  # Имя проекта в Timeweb Cloud
}
```

#### 1.5. Развертывание Services кластера

```bash
# Перейти в директорию services
cd terraform/services

# Инициализировать Terraform (загрузит провайдеры и настроит backend)
terraform init

# Проверить план развертывания (опционально, но рекомендуется)
terraform plan

# Применить конфигурацию и создать кластер
# Подтвердите создание ресурсов при запросе
terraform apply

# После создания кластера, kubeconfig будет автоматически сохранен в:
# ~/kubeconfig-services-cluster.yaml
```

#### 1.6. Развертывание Dev кластера

```bash
# Перейти в директорию dev
cd terraform/dev

# Инициализировать Terraform (загрузит провайдеры и настроит backend)
terraform init

# Проверить план развертывания (опционально, но рекомендуется)
terraform plan

# Применить конфигурацию и создать кластер
# Подтвердите создание ресурсов при запросе
terraform apply

# После создания кластера, kubeconfig будет автоматически сохранен в:
# ~/kubeconfig-dev-cluster.yaml
```

**Подробная инструкция для Dev кластера:** [`terraform/dev/README.md`](terraform/dev/README.md)

**Важно:** После создания кластера убедитесь, что `kubectl` настроен для работы с кластером:

```bash
# Настроить kubeconfig (замените <cluster-name> на имя вашего кластера)
export KUBECONFIG=~/kubeconfig-<cluster-name>.yaml

# Или использовать абсолютный путь
export KUBECONFIG=$HOME/kubeconfig-services-cluster.yaml

# Проверить подключение к кластеру
kubectl get nodes
kubectl get pods -A

# Проверить версию кластера
kubectl version --short
```

**Конфигурация Services кластера по умолчанию:**
- **Регион:** `ru-1` (можно изменить в `terraform/services/variables.tf`)
- **Проект:** `services` (можно изменить в `terraform/services/variables.tf`)
- **Версия Kubernetes:** `v1.34.3+k0s.0` (можно изменить в `terraform/services/variables.tf`)
- **Сетевой драйвер:** `calico` (можно изменить в `terraform/services/variables.tf`)
- **Мастер нода:** 4 CPU (настроено в `terraform/services/data.tf`)
- **Воркер ноды:** 2 CPU, количество узлов: 3 (настраивается в `terraform/services/variables.tf`)
- **Группы нод:** 2 группы воркеров (настроено в `terraform/services/main.tf`)

**Конфигурация Dev кластера по умолчанию:**
- **Регион:** `ru-1` (можно изменить в `terraform/dev/variables.tf`)
- **Проект:** `dev` (можно изменить в `terraform/dev/variables.tf`)
- **Версия Kubernetes:** `v1.34.3+k0s.0` (можно изменить в `terraform/dev/variables.tf`)
- **Сетевой драйвер:** `calico` (можно изменить в `terraform/dev/variables.tf`)
- **Мастер нода:** 4 CPU (настроено в `terraform/dev/data.tf`)
- **Воркер ноды:** 2 CPU, количество узлов: 2 (настраивается в `terraform/dev/variables.tf`)
- **Группы нод:** 2 группы воркеров (настроено в `terraform/dev/main.tf`)

**Управление кластером:**

```bash
# Просмотр информации о кластере
terraform show

# Просмотр outputs
terraform output

# Удаление кластера (осторожно!)
terraform destroy
```

## Развертывание Services кластера (инфраструктурные компоненты)

Следующие шаги относятся к развертыванию инфраструктурных компонентов на Services кластере.

### 2. Установка Gateway API с NGINX Gateway Fabric

```bash
# 1. Установить CRDs Gateway API (стандартная версия)
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v2.3.0" | kubectl apply -f -

# 2. Установить CRDs NGINX Gateway Fabric
kubectl apply --server-side -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v2.3.0/deploy/crds.yaml

# 3. Установить контроллер NGINX Gateway Fabric
kubectl apply -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v2.3.0/deploy/default/deploy.yaml

# 4. Проверить установку
kubectl get pods -n nginx-gateway
kubectl get gatewayclass
```

**Подробная инструкция:** `manifests/gateway/README.md`

### 3. Установка CSI драйвера в панели Timeweb Cloud

CSI драйвер для сетевых дисков Timeweb Cloud устанавливается через Helm chart:

```bash
# 1. Добавить Helm репозиторий (если еще не добавлен)
helm repo add <timeweb-helm-repo> <repo-url>
helm repo update

# 2. Установить CSI драйвер
helm upgrade --install csi-driver-timeweb-cloud <chart-name> \
  --namespace kube-system \
  -f helm/csi-tw/csi-tw-values.yaml

# 3. Проверить установку
kubectl get pods -n kube-system | grep csi-driver-timeweb-cloud
kubectl get storageclass | grep network-drives
```

**Важно:** 
- Перед установкой заполните `TW_API_SECRET` и `TW_CLUSTER_ID` в файле `helm/csi-tw/csi-tw-values.yaml`
- Убедитесь, что API ключ имеет права на управление сетевыми дисками

**Примечание:** Установка через панель Timeweb Cloud может отличаться. Следуйте инструкциям в документации Timeweb Cloud для установки CSI драйвера через веб-интерфейс.

### 4. Установка Vault

**Важно:** Vault должен быть установлен одним из первых, так как он используется для хранения секретов, которые будут синхронизироваться через External Secrets Operator.

```bash
# 1. Добавить Helm репозиторий HashiCorp
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# 2. Установить Vault
helm upgrade --install vault hashicorp/vault \
  --namespace vault \
  --create-namespace \
  -f helm/vault/vault-values.yaml

# 3. Проверить установку
kubectl get pods -n vault
kubectl get statefulset -n vault

# 4. Дождаться готовности Vault
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=vault -n vault --timeout=600s
```

**Важно:**
- Vault использует Raft storage backend (настроен в `helm/vault/vault-values.yaml`)
- StorageClass должен быть `nvme.network-drives.csi.timeweb.cloud`
- Vault Agent Injector включен для инъекции секретов в поды

**Инициализация и разблокировка Vault:**
```bash
# Инициализация Vault (выполнить один раз)
kubectl exec -n vault vault-0 -- vault operator init -key-shares=1 -key-threshold=1 -format=json > /tmp/vault-init.json

# Сохранить unseal key и root token
cat /tmp/vault-init.json | jq -r '.unseal_keys_b64[0]' > /tmp/vault-unseal-key.txt
cat /tmp/vault-init.json | jq -r '.root_token' > /tmp/vault-root-token.txt

# Разблокировать Vault
kubectl exec -n vault vault-0 -- vault operator unseal $(cat /tmp/vault-unseal-key.txt)
```

**Получение root token:**
```bash
# См. инструкцию: helm/vault/VAULT_TOKEN.md
cat /tmp/vault-root-token.txt
```

**Подробная документация:**
- `helm/vault/VAULT_TOKEN.md` - получение root token
- `helm/vault/VAULT_AUTH_METHODS.md` - настройка методов аутентификации
- `helm/vault/VAULT_SECRETS_INJECTION.md` - инъекция секретов в поды
- `helm/vault/CSI_TROUBLESHOOTING.md` - устранение проблем с CSI
- `helm/vault/RAFT_TROUBLESHOOTING.md` - устранение проблем с Raft storage

### 5. Установка External Secrets Operator

**Важно:** External Secrets Operator должен быть установлен после Vault, так как он синхронизирует секреты из Vault в Kubernetes Secrets.

```bash
# 1. Добавить Helm репозиторий External Secrets
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

# 2. Установить External Secrets Operator
helm upgrade --install external-secrets external-secrets/external-secrets \
  --namespace external-secrets-system \
  --create-namespace \
  -f helm/external-secrets/external-secrets-values.yaml

# 3. Проверить установку
kubectl get pods -n external-secrets-system
kubectl get crd | grep external-secrets

# 4. Дождаться готовности External Secrets Operator
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=external-secrets -n external-secrets-system --timeout=300s
```

**Важно:**
- External Secrets Operator будет использоваться для синхронизации секретов из Vault в Kubernetes
- После установки необходимо настроить ClusterSecretStore или SecretStore для подключения к Vault
- Все секреты в кластере должны создаваться через External Secrets Operator, а не напрямую через `kubectl create secret`

**Подробная документация:**
- См. конфигурацию в `helm/external-secrets/external-secrets-values.yaml`

#### 5.1. Настройка ClusterSecretStore для Vault

После установки External Secrets Operator необходимо настроить ClusterSecretStore для подключения к Vault:

```bash
# 1. Настроить Kubernetes auth в Vault для External Secrets Operator
# См. инструкцию по настройке Kubernetes auth в Vault (раздел 4.1 или отдельная инструкция)

# 2. Создать роль в Vault для External Secrets Operator
kubectl exec -it vault-0 -n vault -- vault write auth/kubernetes/role/external-secrets-operator \
  bound_service_account_names=external-secrets \
  bound_service_account_namespaces=external-secrets-system \
  policies=external-secrets-policy \
  ttl=1h

# 3. Создать политику для External Secrets Operator
kubectl exec -it vault-0 -n vault -- vault policy write external-secrets-policy - <<EOF
path "secret/data/*" {
  capabilities = ["read"]
}
EOF

# 4. Применить ClusterSecretStore
kubectl apply -f manifests/external-secrets/vault-cluster-secret-store.yaml

# 5. Проверить ClusterSecretStore
kubectl get clustersecretstore
kubectl describe clustersecretstore vault-backend
```

**Важно:**
- Kubernetes auth в Vault должен быть настроен перед созданием ClusterSecretStore
- ServiceAccount `external-secrets` должен существовать в namespace `external-secrets-system` (создается автоматически при установке)
- Роль в Vault должна иметь доступ к путям секретов, которые будут использоваться
- После настройки ClusterSecretStore можно создавать ExternalSecret ресурсы для синхронизации секретов

### 6. Установка cert-manager

```bash
# 1. Добавить Helm репозиторий
helm repo add jetstack https://charts.jetstack.io
helm repo update

# 2. Установить cert-manager с поддержкой Gateway API
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  -f helm/cert-managar/cert-manager-values.yaml

# 3. Проверить установку
kubectl get pods -n cert-manager
kubectl get crd | grep cert-manager
```

**Важно:** Флаг `config.enableGatewayAPI: true` (в `helm/cert-managar/cert-manager-values.yaml`) **обязателен** для работы с Gateway API!

**Подробная инструкция:** `manifests/cert-manager/README.md`

### 7. Создание Gateway

```bash
# 1. Применить Gateway
kubectl apply -f manifests/gateway/gateway.yaml

# 2. Проверить статус Gateway
kubectl get gateway -n default
kubectl describe gateway service-gateway -n default
```

**Примечание:** 
- HTTP listener будет работать сразу после создания Gateway
- HTTPS listener не будет работать до создания Secret `gateway-tls-cert` (это будет сделано на шаге 7)
- Gateway должен быть создан перед ClusterIssuer, так как ClusterIssuer ссылается на Gateway для HTTP-01 challenge

**Устранение неполадок:** `manifests/gateway/TROUBLESHOOTING.md`

### 8. Создание ClusterIssuer и сертификата

```bash
# 1. Применить ClusterIssuer (отредактируйте email перед применением!)
# ВАЖНО: Gateway должен быть создан, так как ClusterIssuer ссылается на него для HTTP-01 challenge
kubectl apply -f manifests/cert-manager/cluster-issuer.yaml

# 2. Проверить ClusterIssuer
kubectl get clusterissuer
kubectl describe clusterissuer letsencrypt-prod

# 3. Применить Certificate
kubectl apply -f manifests/cert-manager/gateway-certificate.yaml

# 4. Проверить статус Certificate
kubectl get certificate -n default
kubectl describe certificate gateway-tls-cert -n default

# 5. Дождаться создания Secret (может занять несколько минут)
# Cert-manager автоматически создаст Secret gateway-tls-cert после успешной выдачи сертификата
watch kubectl get secret gateway-tls-cert -n default
```

**Важно:** 
- Замените `admin@buildbyte.ru` на ваш реальный email в `manifests/cert-manager/cluster-issuer.yaml`
- Gateway должен быть создан до ClusterIssuer, так как ClusterIssuer использует Gateway для HTTP-01 challenge
- После создания Secret `gateway-tls-cert`, HTTPS listener Gateway автоматически активируется
- Certificate уже содержит все hostnames: `argo.buildbyte.ru`, `jenkins.buildbyte.ru`, `vault.buildbyte.ru`, `grafana.buildbyte.ru`, `keycloak.buildbyte.ru`
- При добавлении новых приложений обновите `dnsNames` в `manifests/cert-manager/gateway-certificate.yaml` и пересоздайте Certificate

**Подробная инструкция:** `manifests/cert-manager/README.md`

### 9. Установка Jenkins и Argo CD

**Важно:** Установите приложения ПЕРЕД созданием HTTPRoute, так как HTTPRoute ссылаются на сервисы этих приложений.

```bash
# 1. Добавить Helm репозитории
helm repo add argo https://argoproj.github.io/argo-helm
helm repo add jenkins https://charts.jenkins.io
helm repo update

# 2. Установить Argo CD
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  -f helm/argocd/argocd-values.yaml

# 3. Установить Jenkins
helm upgrade --install jenkins jenkins/jenkins \
  --namespace jenkins \
  --create-namespace \
  -f helm/jenkins/jenkins-values.yaml

# 4. Проверить установку
kubectl get pods -n argocd
kubectl get pods -n jenkins

# 5. Дождаться готовности сервисов
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=jenkins-controller -n jenkins --timeout=300s
```

**Подробная инструкция:** См. документацию в соответствующих директориях

**Получение паролей:**
```bash
# Пароль администратора Argo CD
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo

# Пароль администратора Jenkins
kubectl exec --namespace jenkins -it svc/jenkins -c jenkins -- /bin/cat /run/secrets/additional/chart-admin-password && echo
```

### 10. Установка Prometheus Kube Stack (Prometheus + Grafana)

```bash
# 1. Добавить Helm репозиторий Prometheus Community
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# 2. Установить Prometheus Kube Stack
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace kube-prometheus-stack \
  --create-namespace \
  -f helm/prom-kube-stack/prom-kube-stack-values.yaml

# 3. Проверить установку
kubectl get pods -n kube-prometheus-stack
kubectl get prometheus -n kube-prometheus-stack
kubectl get grafana -n kube-prometheus-stack

# 4. Дождаться готовности компонентов
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n kube-prometheus-stack --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n kube-prometheus-stack --timeout=300s
```

**Важно:**
- Prometheus и Grafana используют StorageClass `nvme.network-drives.csi.timeweb.cloud` для персистентного хранилища
- Пароль администратора Grafana можно изменить (см. `helm/prom-kube-stack/GRAFANA_ADMIN_PASSWORD.md`)

**Получение пароля администратора Grafana:**
```bash
# Пароль по умолчанию хранится в Secret
kubectl get secret kube-prometheus-stack-grafana -n kube-prometheus-stack -o jsonpath='{.data.admin-password}' | base64 -d && echo

# Или если используется кастомный Secret
kubectl get secret grafana-admin -n kube-prometheus-stack -o jsonpath='{.data.admin-password}' | base64 -d && echo
```

**Подробная документация:**
- `helm/prom-kube-stack/GRAFANA_ADMIN_PASSWORD.md` - изменение пароля администратора Grafana

### 11. Установка Keycloak Operator

#### 10.1. Установка оператора

```bash
# 1. Установить CRDs Keycloak Operator
kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/main/kubernetes/keycloaks.k8s.keycloak.org-v1.yml
kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/main/kubernetes/keycloakrealmimports.k8s.keycloak.org-v1.yml
kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/main/kubernetes/keycloakclients.k8s.keycloak.org-v1.yml

# 2. Установить Keycloak Operator
kubectl apply -f manifests/keycloak/keycloak-operator-install.yaml

# 3. Проверить установку оператора
kubectl get pods -n keycloak-system
kubectl wait --for=condition=available deployment/keycloak-operator -n keycloak-system --timeout=300s
```

#### 10.2. Подготовка PostgreSQL для Keycloak

Keycloak настроен для использования внешнего PostgreSQL. Перед созданием Keycloak инстанса необходимо:

**Шаг 1: Определить адрес PostgreSQL**

```bash
# Найти адрес PostgreSQL сервиса
kubectl get svc -A | grep postgresql

# Формат адреса: <service-name>.<namespace>.svc.cluster.local
# Пример: postgresql.postgresql.svc.cluster.local
```

**Шаг 2: Создать базу данных и пользователя в PostgreSQL**

```bash
# Найти pod PostgreSQL
kubectl get pods -A | grep postgresql

# Скопировать SQL скрипт в pod
kubectl cp manifests/keycloak/create-keycloak-database.sql \
  <postgresql-pod-name>:/tmp/create-keycloak-database.sql \
  -n <postgresql-namespace>

# Отредактировать пароль в скрипте (замените на безопасный пароль!)
kubectl exec -it <postgresql-pod-name> -n <postgresql-namespace> -- \
  sed -i "s/change-me-please/<ВАШ_ПАРОЛЬ>/g" /tmp/create-keycloak-database.sql

# Выполнить скрипт
kubectl exec -it <postgresql-pod-name> -n <postgresql-namespace> -- \
  psql -U postgres -f /tmp/create-keycloak-database.sql
```

**Шаг 3: Обновить конфигурацию Keycloak**

Откройте `manifests/keycloak/keycloak-instance.yaml` и обновите адрес PostgreSQL:

```yaml
database:
  host: postgresql.postgresql.svc.cluster.local  # Замените на ваш адрес PostgreSQL
```

**Шаг 4: Создать секреты через External Secrets Operator**

**Важно:** Все секреты в кластере должны создаваться через External Secrets Operator, который синхронизирует их из Vault.

**4.1. Настроить ClusterSecretStore для Vault (если еще не настроен)**

Создайте ClusterSecretStore для подключения External Secrets Operator к Vault:

```bash
# Пример манифеста ClusterSecretStore для Vault
# См. manifests/external-secrets/vault-cluster-secret-store.yaml
kubectl apply -f manifests/external-secrets/vault-cluster-secret-store.yaml
```

**4.2. Сохранить секреты в Vault**

Сохраните credentials PostgreSQL в Vault:

```bash
# Подключиться к Vault
export VAULT_ADDR="http://vault.vault.svc.cluster.local:8200"
export VAULT_TOKEN="<ваш-root-token>"

# Сохранить секреты PostgreSQL для Keycloak
vault kv put secret/keycloak/postgresql \
  username=keycloak \
  password='<ВАШ_ПАРОЛЬ>' \
  database=keycloak
```

**4.3. Создать ExternalSecret**

Создайте ExternalSecret для синхронизации секретов из Vault:

```bash
# Применить ExternalSecret манифест
kubectl apply -f manifests/keycloak/postgresql-credentials-externalsecret.yaml
```

**Проверка синхронизации:**

```bash
# Проверить статус ExternalSecret
kubectl get externalsecret -n keycloak
kubectl describe externalsecret postgresql-keycloak-credentials -n keycloak

# Проверить созданный Secret
kubectl get secret postgresql-keycloak-credentials -n keycloak
```

**Альтернатива (только для первоначальной настройки):**

Если External Secrets Operator еще не настроен, можно временно создать Secret напрямую:

```bash
kubectl create secret generic postgresql-keycloak-credentials \
  --from-literal=username=keycloak \
  --from-literal=password='<ВАШ_ПАРОЛЬ>' \
  --from-literal=database=keycloak \
  -n keycloak
```

**Важно:** После настройки External Secrets Operator все секреты должны управляться через него.

#### 10.3. Создание Keycloak инстанса

```bash
# 1. Создать Keycloak инстанс
kubectl apply -f manifests/keycloak/keycloak-instance.yaml

# 2. Проверить статус Keycloak
kubectl get keycloak -n keycloak
kubectl get pods -n keycloak

# 3. Проверить логи Keycloak для подтверждения подключения к PostgreSQL
kubectl logs -f keycloak-0 -n keycloak | grep -i postgres

# 4. Дождаться готовности Keycloak (может занять несколько минут)
kubectl wait --for=condition=ready pod -l app=keycloak -n keycloak --timeout=600s
```

**Проверка подключения к PostgreSQL:**

В логах Keycloak должны быть сообщения:
```
INFO  [org.hibernate.dialect.Dialect] Using dialect: org.hibernate.dialect.PostgreSQLDialect
INFO  [org.keycloak.connections.jpa.updater.liquibase.Connector] Initializing database schema
```

**Важно:**
- Keycloak настроен для использования внешнего PostgreSQL (не H2)
- Убедитесь, что PostgreSQL доступен по адресу, указанному в `keycloak-instance.yaml`
- Secret `postgresql-keycloak-credentials` должен быть создан перед созданием Keycloak инстанса
- Hostname настроен на `keycloak.buildbyte.ru`

**Получение пароля администратора Keycloak:**
```bash
# Пароль хранится в Secret, созданном оператором
kubectl get secret credential-keycloak -n keycloak -o jsonpath='{.data.ADMIN_PASSWORD}' 2>/dev/null | base64 -d && echo

# Или найти Secret с паролем
kubectl get secrets -n keycloak -o json | jq -r '.items[] | select(.data.ADMIN_PASSWORD != null) | .metadata.name'
```

**Подробная документация:**
- `manifests/keycloak/README.md` - полная инструкция по установке и настройке
- `manifests/keycloak/POSTGRESQL_SETUP.md` - подробная инструкция по подключению к PostgreSQL

### 12. Установка Jaeger

```bash
# 1. Добавить Helm репозиторий Jaeger
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo update

# 2. Установить Jaeger
helm upgrade --install jaeger jaegertracing/jaeger \
  --namespace jaeger \
  --create-namespace \
  -f helm/jaeger/jaeger-values.yaml

# 3. Проверить установку
kubectl get pods -n jaeger
kubectl get services -n jaeger

# 4. Дождаться готовности Jaeger
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=jaeger -n jaeger --timeout=300s
```

**Важно:**
- Jaeger настроен для приема трейсов через Jaeger и Zipkin протоколы
- OpenTelemetry Collector настроен для приема и обработки трейсов
- Конфигурация находится в `helm/jaeger/jaeger-values.yaml`

**Доступ к Jaeger UI:**
- Jaeger UI доступен через порт-форвардинг или через Ingress/HTTPRoute (если настроен)

**Подробная документация:**
- См. конфигурацию в `helm/jaeger/jaeger-values.yaml`

### 13. Создание HTTPRoute для приложений

**Важно:** HTTPRoute должны создаваться ПОСЛЕ установки приложений, так как они ссылаются на сервисы Argo CD и Jenkins.

```bash
# 1. Применить HTTPRoute для Argo CD
kubectl apply -f manifests/gateway/routes/argocd-https-route.yaml
kubectl apply -f manifests/gateway/routes/argocd-http-redirect.yaml

# 2. Применить HTTPRoute для Jenkins
kubectl apply -f manifests/gateway/routes/jenkins-https-route.yaml
kubectl apply -f manifests/gateway/routes/jenkins-http-redirect.yaml

# 3. Применить HTTPRoute для Vault
kubectl apply -f manifests/gateway/routes/vault-https-route.yaml
kubectl apply -f manifests/gateway/routes/vault-http-redirect.yaml

# 4. Применить HTTPRoute для Grafana
kubectl apply -f manifests/gateway/routes/grafana-https-route.yaml
kubectl apply -f manifests/gateway/routes/grafana-http-redirect.yaml

# 5. Применить HTTPRoute для Keycloak
kubectl apply -f manifests/gateway/routes/keycloak-https-route.yaml
kubectl apply -f manifests/gateway/routes/keycloak-http-redirect.yaml

# 6. Проверить HTTPRoute
kubectl get httproute -A
kubectl describe httproute argocd-server -n argocd
kubectl describe httproute jenkins-server -n jenkins
kubectl describe httproute vault-server -n vault
kubectl describe httproute grafana-server -n kube-prometheus-stack
kubectl describe httproute keycloak-server -n keycloak

# 7. Проверить, что HTTPRoute привязаны к Gateway
kubectl describe gateway service-gateway -n default | grep -A 20 "Listeners:"
```

### 14. Настройка SSO (Single Sign-On) с Keycloak

После установки всех компонентов можно настроить единый вход (SSO) для всех приложений через Keycloak.

#### 14.1. Предварительные требования

- Keycloak установлен и доступен по адресу `https://keycloak.buildbyte.ru`
- Получен пароль администратора Keycloak (см. раздел 10)
- Все приложения установлены и доступны через HTTPS

#### 14.2. Настройка клиентов в Keycloak

1. Войдите в Keycloak Admin Console: `https://keycloak.buildbyte.ru/admin`
2. Создайте Realm (если еще не создан) или используйте существующий (например, `services`)
3. Для каждого приложения создайте отдельного клиента:
   - **Argo CD** — клиент `argocd`
   - **Jenkins** — клиент `jenkins`
   - **Grafana** — клиент `grafana`
   - **Vault** — клиент `vault`

#### 14.3. Настройка приложений

**Argo CD:**
- Настройка OIDC в `helm/argocd/argocd-values.yaml`
- Создание Secret с Client Secret

**Grafana:**
- Настройка Generic OAuth в `grafana.ini` (уже настроено в `helm/prom-kube-stack/prom-kube-stack-values.yaml`)
- Создание Secret: `kubectl apply -f manifests/grafana/grafana-oidc-secret.yaml`
- Обновление Helm chart: `helm upgrade kube-prometheus-stack ...`

**Vault:**
- Использование скрипта настройки: `helm/vault/setup-oidc-keycloak.sh`
- Создание политики для группы `VaultCDAdmins`

**Jenkins:**
- Настройка через JCasC или UI Jenkins
- Использование плагина Keycloak Authentication Plugin

#### 14.4. Создание групп и пользователей

1. В Keycloak создайте группы:
   - `GrafanaAdmin` — администраторы Grafana
   - `VaultCDAdmins` — администраторы Vault
   - `viewer` — пользователи с правами просмотра
   - Другие группы по необходимости

2. Назначьте пользователей в соответствующие группы

#### 14.5. Применение изменений

```bash
# Обновить Grafana (если изменили конфигурацию)
helm upgrade kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace kube-prometheus-stack \
  -f helm/prom-kube-stack/prom-kube-stack-values.yaml

# Настроить Vault (выполнить скрипт)
cd helm/vault
./setup-oidc-keycloak.sh

# Обновить Argo CD (если изменили конфигурацию)
helm upgrade argocd argo/argo-cd \
  --namespace argocd \
  -f helm/argocd/argocd-values.yaml
```

#### 14.6. Проверка SSO

1. Откройте приложения в браузере:
   - `https://grafana.buildbyte.ru` — должна появиться кнопка "Sign in with Keycloak"
   - `https://vault.buildbyte.ru` — должен быть доступен метод аутентификации OIDC
   - `https://argo.buildbyte.ru` — должен быть доступен вход через Keycloak

2. Выполните вход через Keycloak и проверьте права доступа

**Подробная инструкция:** См. [`docs/keycloak-sso-setup.md`](docs/keycloak-sso-setup.md)

**Дополнительная документация:**
- [`helm/vault/VAULT_KEYCLOAK_OIDC.md`](helm/vault/VAULT_KEYCLOAK_OIDC.md) — подробная инструкция по настройке Vault с Keycloak

## Полный чек-лист установки

### Services кластер (инфраструктурные компоненты)

- [ ] Services кластер Kubernetes развернут через Terraform (`terraform/services/`)
- [ ] `kubectl` настроен и подключен к Services кластеру
- [ ] Gateway API с NGINX Gateway Fabric установлен
- [ ] CSI драйвер Timeweb Cloud установлен и работает
- [ ] Vault установлен, инициализирован и разблокирован
- [ ] External Secrets Operator установлен и работает
- [ ] ClusterSecretStore для Vault настроен
- [ ] Kubernetes auth в Vault настроен для External Secrets Operator
- [ ] cert-manager установлен с поддержкой Gateway API
- [ ] Gateway создан (HTTP listener работает)
- [ ] ClusterIssuer создан и готов (Status: Ready)
- [ ] Certificate создан и Secret `gateway-tls-cert` существует
- [ ] HTTPS listener Gateway активирован (после создания Secret)
- [ ] Argo CD установлен и сервисы готовы
- [ ] Jenkins установлен и сервисы готовы
- [ ] Prometheus Kube Stack установлен и сервисы готовы
- [ ] PostgreSQL установлен и доступен
- [ ] База данных и пользователь для Keycloak созданы в PostgreSQL
- [ ] Секреты PostgreSQL для Keycloak сохранены в Vault (путь: `secret/keycloak/postgresql`)
- [ ] ExternalSecret `postgresql-keycloak-credentials` создан и синхронизирован
- [ ] Secret `postgresql-keycloak-credentials` создан External Secrets Operator
- [ ] Адрес PostgreSQL обновлен в `keycloak-instance.yaml`
- [ ] Keycloak Operator установлен и Keycloak инстанс готов
- [ ] Keycloak успешно подключен к PostgreSQL (проверено в логах)
- [ ] Jaeger установлен и сервисы готовы
- [ ] HTTPRoute для Argo CD созданы и привязаны к Gateway
- [ ] HTTPRoute для Jenkins созданы и привязаны к Gateway
- [ ] HTTPRoute для Vault созданы и привязаны к Gateway
- [ ] HTTPRoute для Grafana созданы и привязаны к Gateway
- [ ] HTTPRoute для Keycloak созданы и привязаны к Gateway
- [ ] Keycloak настроен и доступен через HTTPS
- [ ] Клиенты созданы в Keycloak для всех приложений (argocd, jenkins, grafana, vault)
- [ ] Secret для Grafana OIDC создан (`grafana-oidc-secret`)
- [ ] Grafana настроена для работы с Keycloak через Generic OAuth
- [ ] Vault настроен для работы с Keycloak через OIDC (скрипт `setup-oidc-keycloak.sh` выполнен)
- [ ] Группы созданы в Keycloak (GrafanaAdmin, VaultCDAdmins, viewer)
- [ ] Пользователи назначены в соответствующие группы
- [ ] SSO протестирован для всех приложений

### Dev кластер (для микросервисов)

- [ ] Dev кластер Kubernetes развернут через Terraform (`terraform/dev/`)
- [ ] `kubectl` настроен и подключен к Dev кластеру
- [ ] Проект `dev` создан в Timeweb Cloud
- [ ] Необходимые компоненты установлены на Dev кластере (если требуются)

## Проверка работоспособности

```bash
# Проверить статус всех компонентов
kubectl get nodes
kubectl get pods -A
kubectl get gateway -A
kubectl get httproute -A
kubectl get certificate -A
kubectl get clusterissuer

# Проверить доступность через браузер
# Argo CD: https://argo.buildbyte.ru
# Jenkins: https://jenkins.buildbyte.ru
# Vault: https://vault.buildbyte.ru
# Grafana: https://grafana.buildbyte.ru
# Keycloak: https://keycloak.buildbyte.ru

# Проверить редиректы HTTP -> HTTPS
curl -I http://argo.buildbyte.ru  # Должен вернуть 301 на https://
curl -I http://jenkins.buildbyte.ru  # Должен вернуть 301 на https://
curl -I http://vault.buildbyte.ru  # Должен вернуть 301 на https://
curl -I http://grafana.buildbyte.ru  # Должен вернуть 301 на https://
curl -I http://keycloak.buildbyte.ru  # Должен вернуть 301 на https://

# Проверить SSO (если настроен)
# Откройте приложения в браузере и проверьте наличие кнопок входа через Keycloak:
# - Grafana: https://grafana.buildbyte.ru (должна быть кнопка "Sign in with Keycloak")
# - Vault: https://vault.buildbyte.ru (должен быть метод аутентификации OIDC)
# - Argo CD: https://argo.buildbyte.ru (должен быть вход через Keycloak)
```

## Дополнительная документация

- **Gateway API:** `manifests/gateway/README.md`
- **Устранение неполадок Gateway:** `manifests/gateway/TROUBLESHOOTING.md`
- **cert-manager:** `manifests/cert-manager/README.md`
- **Vault:** `helm/vault/VAULT_TOKEN.md`, `helm/vault/VAULT_AUTH_METHODS.md`, `helm/vault/VAULT_SECRETS_INJECTION.md`
- **Prometheus Kube Stack:** `helm/prom-kube-stack/GRAFANA_ADMIN_PASSWORD.md`
- **Keycloak:** `manifests/keycloak/README.md`
- **Подключение Keycloak к PostgreSQL:** `manifests/keycloak/POSTGRESQL_SETUP.md`
- **Настройка SSO с Keycloak:** `docs/keycloak-sso-setup.md`
- **Argo CD курс:** `docs/argocd-course/`
- **Vault курс:** `docs/vault-course/`

## Важные замечания

1. **Порядок установки критичен:**
   - **Vault должен быть установлен одним из первых** (для хранения секретов)
   - **External Secrets Operator должен быть установлен после Vault** (для синхронизации секретов)
   - **ClusterSecretStore должен быть настроен после External Secrets Operator** (для подключения к Vault)
   - Gateway должен быть создан перед ClusterIssuer (ClusterIssuer ссылается на Gateway для HTTP-01 challenge)
   - Приложения должны быть установлены перед созданием HTTPRoute (HTTPRoute ссылаются на их сервисы)
   - Secret для TLS создается cert-manager автоматически, но HTTPS listener не будет работать до его создания
   - Keycloak Operator требует установки CRDs перед установкой оператора
   - Vault использует Raft storage, убедитесь, что CSI драйвер работает корректно
   - **Все секреты должны создаваться через External Secrets Operator**, а не напрямую через `kubectl create secret`

2. **Зависимости компонентов:**
   - **External Secrets Operator** → требует **Vault** (для синхронизации секретов)
   - **ClusterSecretStore** → требует **Vault** и **Kubernetes auth в Vault** (для подключения External Secrets Operator)
   - **ExternalSecret** → требует **ClusterSecretStore** и **секреты в Vault** (для синхронизации)
   - **Приложения** → требуют **секреты через External Secrets Operator** (Keycloak, Grafana и т.д.)
   - **ClusterIssuer** → требует **Gateway** (для HTTP-01 challenge через Gateway API)
   - **Certificate** → требует **ClusterIssuer** и **Gateway** (для HTTP-01 challenge)
   - **HTTPRoute** → требует **Gateway** и **сервисы приложений** (backendRefs ссылаются на сервисы)

3. **Secret для TLS:** Gateway не будет работать с HTTPS, пока Secret `gateway-tls-cert` не создан cert-manager

4. **Зоны доступности:** Убедитесь, что CSI драйвер и кластер находятся в одной зоне доступности

5. **API ключи:** Заполните все необходимые API ключи и секреты перед установкой компонентов

## Порядок зависимостей

```
Terraform (K8s кластер)
  ↓
Gateway API
  ↓
CSI драйвер (независимо)
  ↓
Vault (установка и инициализация)
  ↓
External Secrets Operator (синхронизирует секреты из Vault)
  ↓
ClusterSecretStore для Vault (настройка подключения)
  ↓
cert-manager (независимо)
  ↓
Gateway (HTTP listener работает сразу)
  ↓
ClusterIssuer (ссылается на Gateway)
  ↓
Certificate (ссылается на ClusterIssuer, создает Secret)
  ↓
HTTPS listener Gateway активируется (после создания Secret)
  ↓
Приложения (установка):
  - Jenkins & Argo CD
  - Prometheus Kube Stack (Prometheus + Grafana)
  - Keycloak Operator → Keycloak (использует секреты из External Secrets Operator)
  - Jaeger
  ↓
HTTPRoute (ссылаются на Gateway и сервисы приложений)
```

**Важно:**
- **Vault** должен быть установлен до External Secrets Operator
- **External Secrets Operator** должен быть установлен до приложений, которые используют секреты
- Все секреты создаются через External Secrets Operator, который синхронизирует их из Vault
- Секреты для Keycloak, Grafana и других приложений должны быть сохранены в Vault перед установкой приложений
