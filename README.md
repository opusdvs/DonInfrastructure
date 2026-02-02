# DonInfrastructure

Инфраструктура для развертывания Kubernetes кластеров с использованием Timeweb Cloud.

## Структура проекта

Проект содержит конфигурацию для двух типов кластеров:

- **Services кластер** (`terraform/services/`) — сервисный кластер для инфраструктурных компонентов (Argo CD, Jenkins, Vault, Grafana, Keycloak и т.д.)
- **Dev кластер** (`terraform/dev/`) — кластер для разработки и развертывания микросервисов

### Организация конфигураций

Конфигурации разделены по кластерам:

- **`helm/services/`** — Helm values для компонентов Services кластера
- **`helm/dev/`** — Helm values для компонентов Dev кластера
- **`manifests/services/`** — Kubernetes манифесты для Services кластера
- **`manifests/dev/`** — Kubernetes манифесты для Dev кластера

## Порядок установки Kubernetes кластера

Пошаговая инструкция по развертыванию полного стека инфраструктуры.

### Предварительные требования

- Установленный Terraform (версия >= 0.13)
- Настроенный `kubectl` для работы с кластером
- Установленный Helm (версия 3.x+)
- Установленный `jq` для работы с JSON (используется в инструкциях)
- Установленный `htpasswd` для создания bcrypt хешей паролей (используется для Argo CD)
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

Terraform использует S3-совместимое хранилище Timeweb Cloud для хранения state. Настройте credentials через переменные окружения:

```bash
export AWS_ACCESS_KEY_ID="your-s3-access-key"
export AWS_SECRET_ACCESS_KEY="your-s3-secret-key"
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

# Проверить план развертывания (опционально)
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

# Проверить план развертывания (опционально)
terraform plan

# Применить конфигурацию и создать кластер
# Подтвердите создание ресурсов при запросе
terraform apply

# После создания кластера, kubeconfig будет автоматически сохранен в:
# ~/kubeconfig-dev-cluster.yaml
```


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

**Создание Docker Registry в панели управления облака:**

После создания Kubernetes кластера необходимо создать Docker Registry в панели управления облака (Timeweb Cloud):

1. Войдите в панель управления Timeweb Cloud
2. Перейдите в раздел **Container Registry** или **Docker Registry**
3. Создайте новый приватный Docker Registry
4. Сохраните следующие данные (они понадобятся для настройки Jenkins):
   - **URL реестра** (домен registry, например: `buildbyte-container-registry.registry.twcstorage.ru`)
   - **Username** (имя пользователя для доступа, например: `buildbyte-container-registry`)
   - **API Token** (токен для доступа, создается в панели управления)

**Пример данных для buildbyte-container-registry:**
- Домен: `buildbyte-container-registry.registry.twcstorage.ru`
- Username: `buildbyte-container-registry`
- API Token: (создается в панели управления Container Registry)

**Важно:** 
- Для Timeweb Container Registry используется **API Token** вместо пароля
- Эти credentials будут использоваться для настройки Jenkins и доступа к приватным Docker образам из CI/CD пайплайнов
- API Token сохраняется в Vault в поле `password` (см. инструкцию в разделе 12.1)

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

### 3. Установка cert-manager

```bash
# 1. Добавить Helm репозиторий
helm repo add jetstack https://charts.jetstack.io
helm repo update

# 2. Установить cert-manager с поддержкой Gateway API
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  -f helm/services/cert-managar/cert-manager-values.yaml

# 3. Проверить установку
kubectl get pods -n cert-manager
kubectl get crd | grep cert-manager
```

**Важно:** Флаг `config.enableGatewayAPI: true` (в `helm/services/cert-managar/cert-manager-values.yaml`) **обязателен** для работы с Gateway API!

### 4. Создание ClusterIssuer

```bash
# 1. Применить ClusterIssuer (отредактируйте email перед применением!)
kubectl apply -f manifests/services/cert-manager/cluster-issuer.yaml

# 2. Проверить ClusterIssuer
kubectl get clusterissuer
kubectl describe clusterissuer letsencrypt-prod
```

**Важно:** 
- Замените `admin@buildbyte.ru` на ваш реальный email в `manifests/services/cert-manager/cluster-issuer.yaml`
- ClusterIssuer создаётся ДО Gateway

### 5. Создание Gateway

**Важно:** Для получения сертификатов через HTTP-01 challenge необходимо сначала создать HTTP redirect routes. cert-manager создаст временные HTTPRoute для `/.well-known/acme-challenge/`, которые будут иметь приоритет над redirect routes.

```bash
# 1. Создать namespace'ы для сервисов (если ещё не созданы)
kubectl create namespace keycloak --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace jenkins --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace kube-prometheus-stack --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace vault --dry-run=client -o yaml | kubectl apply -f -

# 2. Применить HTTP redirect routes (нужны для HTTP-01 challenge)
kubectl apply -f manifests/services/gateway/routes/keycloak-http-redirect.yaml
kubectl apply -f manifests/services/gateway/routes/argocd-http-redirect.yaml
kubectl apply -f manifests/services/gateway/routes/jenkins-http-redirect.yaml
kubectl apply -f manifests/services/gateway/routes/grafana-http-redirect.yaml
kubectl apply -f manifests/services/gateway/routes/vault-http-redirect.yaml

# 3. Применить Gateway с HTTPS listeners
kubectl apply -f manifests/services/gateway/gateway.yaml

# 4. Проверить статус Gateway
kubectl get gateway -n default
kubectl describe gateway service-gateway -n default

# 5. Проверить автоматически созданные сертификаты (появятся через 1-2 минуты)
kubectl get certificate -n default

# 6. Дождаться готовности сертификатов
kubectl get certificate -n default -w
```

**Примечание:** 
- Gateway содержит аннотацию `cert-manager.io/cluster-issuer: letsencrypt-prod`
- cert-manager автоматически создаёт Certificate для каждого HTTPS listener
- Сертификаты выпускаются через HTTP-01 challenge (требуется HTTP listener и HTTPRoute)
- HTTP redirect routes позволяют cert-manager обрабатывать ACME challenge запросы

### 6. Установка CSI драйвера в панели Timeweb Cloud

CSI драйвер для сетевых дисков Timeweb Cloud устанавливается через Helm chart:

```bash
# 1. Добавить Helm репозиторий (если еще не добавлен)
helm repo add <timeweb-helm-repo> <repo-url>
helm repo update

# 2. Установить CSI драйвер
helm upgrade --install csi-driver-timeweb-cloud <chart-name> \
  --namespace kube-system \
  -f helm/services/csi-tw/csi-tw-values.yaml

# 3. Проверить установку
kubectl get pods -n kube-system | grep csi-driver-timeweb-cloud
kubectl get storageclass | grep network-drives
```

**Важно:** 
- Перед установкой заполните `TW_API_SECRET` и `TW_CLUSTER_ID` в файле `helm/services/csi-tw/csi-tw-values.yaml`
- Убедитесь, что API ключ имеет права на управление сетевыми дисками

**Примечание:** Установка через панель Timeweb Cloud может отличаться. Следуйте инструкциям в документации Timeweb Cloud для установки CSI драйвера через веб-интерфейс.

### 7. Установка Vault через Helm

**Важно:** Vault должен быть установлен одним из первых, так как он используется для хранения секретов, которые будут синхронизироваться через Vault Secrets Operator.

Vault устанавливается через официальный Helm chart от HashiCorp.

#### 7.1. Установка Vault

```bash
# 1. Добавить Helm репозиторий HashiCorp
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# 2. Создать namespace для Vault (если еще не создан)
kubectl create namespace vault --dry-run=client -o yaml | kubectl apply -f -

# 3. Установить Vault через Helm с кастомными значениями
helm upgrade --install vault hashicorp/vault \
  --namespace vault \
  --create-namespace \
  -f helm/services/vault/vault-values.yaml \
  --wait

# 4. Проверить установку Vault
kubectl get pods -n vault
kubectl get statefulset -n vault
kubectl get service -n vault

# 5. Дождаться готовности Vault
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=vault -n vault --timeout=600s
```

**Важно:**
- Vault устанавливается в standalone режиме с file storage (для тестирования)
- StorageClass должен быть `nvme.network-drives.csi.timeweb.cloud`
- Vault Agent Injector включен для инъекции секретов в поды
- Standalone режим не поддерживает High Availability (HA)
- В продакшене будет настроен HA режим с Raft storage и 3 репликами

#### 7.2. Инициализация и разблокировка Vault

После установки Vault необходимо инициализировать и разблокировать его:

```bash
# 1. Инициализация Vault (выполнить один раз)
kubectl exec -n vault vault-0 -- vault operator init -key-shares=1 -key-threshold=1 -format=json > /tmp/vault-init.json

# 2. Сохранить unseal key и root token
cat /tmp/vault-init.json | jq -r '.unseal_keys_b64[0]' > /tmp/vault-unseal-key.txt
cat /tmp/vault-init.json | jq -r '.root_token' > /tmp/vault-root-token.txt

# 3. Разблокировать Vault
kubectl exec -n vault vault-0 -- vault operator unseal $(cat /tmp/vault-unseal-key.txt)

# 4. Проверить статус Vault
kubectl exec -n vault vault-0 -- vault status
```

**Получение root token:**
```bash
cat /tmp/vault-root-token.txt
```

**Важно:**
- Инициализация выполняется только один раз при первом запуске Vault
- Unseal key и root token должны быть сохранены в безопасном месте
- После перезапуска Vault потребуется повторное разблокирование (unseal)
- Для автоматического unsealing в продакшене будет настроен auto-unseal через KMS

### 8. Установка Vault Secrets Operator

**Важно:** Vault Secrets Operator должен быть установлен после Vault, так как он синхронизирует секреты из Vault в Kubernetes Secrets.

Vault Secrets Operator (VSO) — официальный оператор от HashiCorp для синхронизации секретов из Vault в Kubernetes.

```bash
# 1. Добавить Helm репозиторий HashiCorp (если еще не добавлен)
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# 2. Установить Vault Secrets Operator
helm upgrade --install vault-secrets-operator hashicorp/vault-secrets-operator \
  --version 0.10.0 \
  --namespace vault-secrets-operator \
  --create-namespace \
  -f helm/services/vault-secrets-operator/vault-secrets-operator-values.yaml

# 3. Проверить установку
kubectl get pods -n vault-secrets-operator
kubectl get crd | grep secrets.hashicorp.com

# 4. Дождаться готовности Vault Secrets Operator
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=vault-secrets-operator -n vault-secrets-operator --timeout=300s
```

**Важно:**
- Vault Secrets Operator будет использоваться для синхронизации секретов из Vault в Kubernetes
- После установки необходимо настроить VaultConnection и VaultAuth для подключения к Vault
- Все секреты в кластере должны создаваться через VaultStaticSecret, а не напрямую через `kubectl create secret`

**CRD Vault Secrets Operator:**
- `VaultConnection` — подключение к Vault серверу
- `VaultAuth` — аутентификация в Vault (Kubernetes auth, JWT и т.д.)
- `VaultStaticSecret` — синхронизация статических секретов (KV v1/v2)
- `VaultDynamicSecret` — динамические секреты (database credentials и т.д.)
- `VaultPKISecret` — PKI сертификаты

#### 8.1. Настройка Kubernetes Auth в Vault для Vault Secrets Operator

Перед созданием VaultAuth необходимо настроить Kubernetes auth в Vault.

**Краткая инструкция:**

```bash
# 0. Аутентификация в Vault (получить root token)
export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_TOKEN=$(cat /tmp/vault-root-token.txt)

# Если root token не найден, получите его:
# kubectl exec -n vault vault-0 -- vault operator init -key-shares=1 -key-threshold=1 -format=json | jq -r '.root_token' > /tmp/vault-root-token.txt

# 0.1. Включить KV v2 секретный движок (если еще не включен)
# ВАЖНО: Без этого шага вы получите ошибку 403 при создании секретов
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault secrets enable -version=2 -path=secret kv 2>&1 || echo 'Секретный движок уже включен'
"

# 1. Проверить и включить Kubernetes auth method (если еще не включен)
# ВАЖНО: Этот шаг обязателен! Без него вы получите ошибку 404 при настройке конфигурации
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault auth list | grep kubernetes || vault auth enable kubernetes
"

# 2. Настроить конфигурацию Kubernetes auth (используя CA сертификат из pod)
# Если получаете ошибку "claim 'iss' is invalid", параметр disable_iss_validation=true уже добавлен
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault write auth/kubernetes/config \
  token_reviewer_jwt=\"\$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)\" \
  kubernetes_host=\"https://kubernetes.default.svc\" \
  kubernetes_ca_cert=\"\$(cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt)\" \
  disable_iss_validation=true
"

# 3. Создать политику для Vault Secrets Operator
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault policy write vault-secrets-operator-policy - <<'EOF'
path \"secret/data/*\" {
  capabilities = [\"read\"]
}
path \"secret/metadata/*\" {
  capabilities = [\"read\", \"list\"]
}
EOF
"

# 4. Создать роль в Vault для Vault Secrets Operator
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault write auth/kubernetes/role/vault-secrets-operator \
  bound_service_account_names=default \
  bound_service_account_namespaces='*' \
  policies=vault-secrets-operator-policy \
  ttl=1h
"

# 5. Проверить настройку
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault read auth/kubernetes/role/vault-secrets-operator
"
```

#### 8.2. Проверка VaultConnection и VaultAuth

При установке Vault Secrets Operator с values файлом `helm/services/vault-secrets-operator/vault-secrets-operator-values.yaml`, default VaultConnection и VaultAuth создаются автоматически.

```bash
# 1. Проверить, что Vault Secrets Operator установлен
kubectl get pods -n vault-secrets-operator

# 2. Проверить, что CRD установлены
kubectl get crd | grep secrets.hashicorp.com

# Должны быть установлены следующие CRD:
# - vaultconnections.secrets.hashicorp.com
# - vaultauths.secrets.hashicorp.com
# - vaultstaticsecrets.secrets.hashicorp.com
# - vaultdynamicsecrets.secrets.hashicorp.com
# - vaultpkisecrets.secrets.hashicorp.com

# 3. Проверить default VaultConnection (создан автоматически Helm chart'ом)
kubectl get vaultconnection -n vault-secrets-operator
kubectl describe vaultconnection default -n vault-secrets-operator

# 4. Проверить default VaultAuth (создан автоматически Helm chart'ом)
kubectl get vaultauth -n vault-secrets-operator
kubectl describe vaultauth default -n vault-secrets-operator

# 5. Проверить статус (должен быть Valid: true)
kubectl get vaultauth default -n vault-secrets-operator -o jsonpath='{.status.valid}' && echo
```

**Примечание:** Если вам нужно создать дополнительные VaultConnection или VaultAuth (например, для других namespace), используйте следующие команды:

```bash
# Создать дополнительный VaultAuth в другом namespace (опционально)
cat <<EOF | kubectl apply -f -
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultAuth
metadata:
  name: vault-auth
  namespace: <NAMESPACE>
spec:
  vaultConnectionRef: vault-secrets-operator/default
  method: kubernetes
  mount: kubernetes
  kubernetes:
    role: vault-secrets-operator
    serviceAccount: default
EOF
```

**Важно:**
- **Vault должен быть разблокирован (unsealed)** перед использованием VaultAuth
- Kubernetes auth в Vault должен быть настроен перед использованием VaultAuth (см. раздел 8.1)
- Роль `vault-secrets-operator` в Vault должна иметь доступ к путям секретов, которые будут использоваться
- Default VaultConnection использует адрес `http://vault.vault.svc.cluster.local:8200`
- Default VaultAuth разрешает использование из всех namespace (`allowedNamespaces: ["*"]`)
- После настройки VaultAuth можно создавать VaultStaticSecret ресурсы для синхронизации секретов

#### 8.3. Пример использования VaultStaticSecret

После настройки VaultAuth можно создавать VaultStaticSecret для синхронизации секретов:

```yaml
# Пример VaultStaticSecret для синхронизации секрета из Vault
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  name: my-secret
  namespace: default
spec:
  vaultAuthRef: vault-secrets-operator/default
  mount: secret
  type: kv-v2
  path: myapp/config
  refreshAfter: 60s
  destination:
    name: my-secret
    create: true
```

**Проверка статуса Vault:**
```bash
# Проверить, что Vault разблокирован
kubectl exec -it vault-0 -n vault -- vault status

# Если Vault запечатан (Sealed: true), разблокируйте его:
# kubectl exec -it vault-0 -n vault -- vault operator unseal <unseal-key>
# 
# Получить unseal key:
# cat /tmp/vault-unseal-key.txt
```

### 9. Установка PostgreSQL

**Важно:** PostgreSQL должен быть установлен перед Keycloak, так как Keycloak использует PostgreSQL в качестве базы данных.

#### 9.1. Создание секретов в Vault для PostgreSQL

Перед установкой PostgreSQL необходимо создать секреты в Vault:

```bash
# Подключиться к Vault
export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_TOKEN=$(cat /tmp/vault-root-token.txt)

# Убедиться, что KV v2 секретный движок включен
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault secrets enable -version=2 -path=secret kv 2>&1 || echo 'Секретный движок уже включен'
"

# Сохранить секреты PostgreSQL в Vault
# ВАЖНО: Замените пароли на реальные значения
# Используйте одинарные кавычки для паролей, чтобы избежать проблем с специальными символами
#
# Ключи секрета:
#   - postgres_password: пароль для admin пользователя postgres
#   - replication_password: пароль для пользователя репликации
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault kv put secret/postgresql/admin \
  postgres_password='<ВАШ_ПАРОЛЬ_POSTGRES>' \
  replication_password='<ВАШ_ПАРОЛЬ_REPLICATION>'
"

# Проверить, что секреты сохранены правильно
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault kv get secret/postgresql/admin
"

# Проверить структуру данных в JSON формате (для отладки)
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault kv get -format=json secret/postgresql/admin | jq '.data.data'
"
```

**Важно:**
- Используйте надежные пароли для production окружения
- Пароли должны быть достаточно длинными (минимум 16 символов)
- Сохраните пароли в безопасном месте (например, в менеджере паролей)

#### 9.2. Создание VaultStaticSecret для PostgreSQL

Создайте VaultStaticSecret для синхронизации секретов из Vault:

```bash
# Создать namespace для PostgreSQL (если еще не создан)
kubectl create namespace postgresql --dry-run=client -o yaml | kubectl apply -f -

# Применить VaultStaticSecret для PostgreSQL admin credentials
kubectl apply -f manifests/services/postgresql/postgresql-admin-credentials-vaultstaticsecret.yaml

# Проверить синхронизацию секретов
kubectl get vaultstaticsecret -n postgresql
kubectl describe vaultstaticsecret postgresql-admin-credentials -n postgresql

# Проверить созданный Secret
kubectl get secret postgresql-admin-credentials -n postgresql
```

#### 9.3. Установка PostgreSQL через Helm Bitnami

```bash
# 1. Добавить Helm репозиторий Bitnami
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# 2. Установить PostgreSQL
# Настройки для использования существующего Secret уже указаны в helm/services/postgresql/postgresql-values.yaml
helm upgrade --install postgresql bitnami/postgresql \
  --namespace postgresql \
  --create-namespace \
  -f helm/services/postgresql/postgresql-values.yaml

# 3. Проверить установку
kubectl get pods -n postgresql
kubectl get statefulset -n postgresql
kubectl get pvc -n postgresql

# 5. Дождаться готовности PostgreSQL
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgresql -n postgresql --timeout=600s
```

**Важно:**
- PostgreSQL использует StorageClass `nvme.network-drives.csi.timeweb.cloud` для персистентного хранилища
- Размер хранилища по умолчанию: 8Gi (можно изменить в `helm/services/postgresql/postgresql-values.yaml`)
- Secret `postgresql-admin-credentials` должен быть создан через Vault Secrets Operator перед установкой

**Проверка подключения к PostgreSQL:**
```bash
# Получить имя pod PostgreSQL
POSTGRES_POD=$(kubectl get pods -n postgresql -l app.kubernetes.io/name=postgresql -o jsonpath='{.items[0].metadata.name}')

# Подключиться к PostgreSQL
kubectl exec -it $POSTGRES_POD -n postgresql -- psql -U postgres

# В psql выполнить:
# \l - список баз данных
# \du - список пользователей
# \q - выход
```

### 10. Установка Keycloak Operator

#### 10.1. Установка оператора

```bash
# 1. Установить CRDs Keycloak Operator
# Используем конкретную версию для стабильности (26.5.1)
kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/26.5.1/kubernetes/keycloaks.k8s.keycloak.org-v1.yml
kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/26.5.1/kubernetes/keycloakrealmimports.k8s.keycloak.org-v1.yml

# 2. Создать namespace для Keycloak Operator (если еще не создан)
kubectl create namespace keycloak --dry-run=client -o yaml | kubectl apply -f -

# 3. Установить Keycloak Operator из официального манифеста
kubectl -n keycloak apply -f https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/26.5.1/kubernetes/kubernetes.yml

# 4. Проверить установку оператора
kubectl get pods -n keycloak
kubectl wait --for=condition=available deployment/keycloak-operator -n keycloak --timeout=300s
```

#### 10.2. Подготовка PostgreSQL для Keycloak

Keycloak использует внешний PostgreSQL для хранения данных. Необходимо создать базу данных, пользователя и секреты.

**Шаг 1: Сохранить секреты Keycloak в Vault**

```bash
# Сохранить credentials для Keycloak DB в Vault
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='\$VAULT_TOKEN'
vault kv put secret/keycloak/database \
  username='keycloak' \
  password='<ПАРОЛЬ_KEYCLOAK>' \
  database='keycloak'
"

# Сохранить admin credentials для Keycloak (для входа в UI)
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='\$VAULT_TOKEN'
vault kv put secret/keycloak/admin \
  username='admin' \
  password='<ПАРОЛЬ_ADMIN_KEYCLOAK>'
"
```

**Шаг 2: Создать VaultStaticSecret для синхронизации секретов**

Манифесты VaultStaticSecret находятся в `manifests/services/keycloak/`:
- `keycloak-db-credentials-vaultstaticsecret.yaml` - credentials для подключения к PostgreSQL
- `keycloak-admin-credentials-vaultstaticsecret.yaml` - admin credentials для Keycloak

```bash
# Создать namespace для Keycloak (если еще не создан)
kubectl create namespace keycloak --dry-run=client -o yaml | kubectl apply -f -

# Применить VaultStaticSecret манифесты
kubectl apply -f manifests/services/keycloak/keycloak-db-credentials-vaultstaticsecret.yaml
kubectl apply -f manifests/services/keycloak/keycloak-admin-credentials-vaultstaticsecret.yaml

# Дождаться синхронизации секретов
kubectl wait --for=condition=SecretSynced vaultstaticsecret/keycloak-db-credentials -n keycloak --timeout=60s
kubectl wait --for=condition=SecretSynced vaultstaticsecret/keycloak-admin-credentials -n keycloak --timeout=60s

# Проверить создание Kubernetes Secret
kubectl get secret keycloak-db-credentials -n keycloak
kubectl get secret keycloak-admin-credentials -n keycloak
```

**Шаг 3: Создать базу данных и пользователя в PostgreSQL**

```bash
# Получить имя pod PostgreSQL
POSTGRES_POD=$(kubectl get pods -n postgresql -l app.kubernetes.io/name=postgresql -o jsonpath='{.items[0].metadata.name}')

# Получить пароль администратора PostgreSQL из Secret
POSTGRES_PASSWORD=$(kubectl get secret postgresql-admin-credentials -n postgresql -o jsonpath='{.data.postgres_password}' | base64 -d)

# Получить пароль Keycloak из Kubernetes Secret (синхронизирован из Vault через VaultStaticSecret)
KEYCLOAK_PASSWORD=$(kubectl get secret keycloak-db-credentials -n keycloak -o jsonpath='{.data.password}' | base64 -d)

# Проверить, что пароль получен
echo "Keycloak password length: ${#KEYCLOAK_PASSWORD}"

# Создать пользователя keycloak с паролем из Secret (до создания базы!)
kubectl exec $POSTGRES_POD -n postgresql -- sh -c "PGPASSWORD='$POSTGRES_PASSWORD' psql -U postgres -c \"CREATE USER keycloak WITH ENCRYPTED PASSWORD '$KEYCLOAK_PASSWORD';\""

# Создать базу данных keycloak с владельцем keycloak
kubectl exec $POSTGRES_POD -n postgresql -- sh -c "PGPASSWORD='$POSTGRES_PASSWORD' psql -U postgres -c 'CREATE DATABASE keycloak OWNER keycloak;'"

# Выдать права на схему public (нужно в PostgreSQL 15+)
kubectl exec $POSTGRES_POD -n postgresql -- sh -c "PGPASSWORD='$POSTGRES_PASSWORD' psql -U postgres -d keycloak -c 'GRANT ALL ON SCHEMA public TO keycloak;'"
```

**Шаг 4: Проверка создания базы данных**

```bash
# Проверить создание базы данных keycloak
kubectl exec $POSTGRES_POD -n postgresql -- sh -c "PGPASSWORD='$POSTGRES_PASSWORD' psql -U postgres -c '\l'" | grep keycloak

# Проверить создание пользователя keycloak
kubectl exec $POSTGRES_POD -n postgresql -- sh -c "PGPASSWORD='$POSTGRES_PASSWORD' psql -U postgres -c '\du'" | grep keycloak
```

**Шаг 5: Обновить конфигурацию Keycloak**

Откройте `manifests/services/keycloak/keycloak-instance.yaml` и обновите адрес PostgreSQL:

```yaml
database:
  host: postgresql.postgresql.svc.cluster.local  # Замените на ваш адрес PostgreSQL
```

**Важно:**
- Адрес PostgreSQL для Keycloak: `postgresql.postgresql.svc.cluster.local:5432`
- База данных: `keycloak`
- Пользователь: `keycloak`
- Пароль: из Kubernetes Secret `keycloak-db-credentials` (синхронизирован из Vault)
- Admin credentials: из Kubernetes Secret `keycloak-admin-credentials` (синхронизирован из Vault)

#### 10.3. Создание Keycloak инстанса

```bash
# 1. Создать Keycloak инстанс
kubectl apply -f manifests/services/keycloak/keycloak-instance.yaml

# 2. Проверить статус Keycloak
kubectl get keycloak -n keycloak
kubectl get pods -n keycloak

# 3. Проверить логи Keycloak для подтверждения подключения к PostgreSQL
kubectl logs -f keycloak-0 -n keycloak | grep -i postgres

# 4. Дождаться готовности Keycloak (может занять несколько минут)
kubectl wait --for=condition=ready pod -l app=keycloak -n keycloak --timeout=600s
```

#### 10.4. Создание HTTPRoute для Keycloak

**Важно:** HTTPRoute создаётся после готовности сертификатов. Сертификаты создаются автоматически при применении Gateway (раздел 5).

```bash
# 1. Проверить, что сертификат готов
kubectl get certificate -n default | grep keycloak

# 2. Применить HTTPRoute
kubectl apply -f manifests/services/gateway/routes/keycloak-https-route.yaml
kubectl apply -f manifests/services/gateway/routes/keycloak-http-redirect.yaml

# 3. Проверить HTTPRoute
kubectl get httproute -n keycloak
```

**Проверка доступа:**
```bash
curl -I https://keycloak.buildbyte.ru
```

После настройки HTTPRoute Keycloak будет доступен по адресу: `https://keycloak.buildbyte.ru`

#### 10.5. Создание Realm и клиентов для сервисов

После успешного развертывания Keycloak необходимо создать Realm и OIDC клиенты для сервисов.

**1. Вход в Admin Console:**
```
URL: https://keycloak.buildbyte.ru/admin
Логин: admin (из секрета keycloak-admin-credentials)
Пароль: из секрета keycloak-admin-credentials
```

**2. Создание Realm `services`:**
1. В левом верхнем углу нажмите на выпадающий список realm (по умолчанию "master")
2. Нажмите **"Create realm"**
3. Введите имя: `services`
4. Нажмите **"Create"**

**3. Создание клиента для Argo CD:**
1. Перейдите в **Clients** → **Create client**
2. **General Settings:**
   - Client type: `OpenID Connect`
   - Client ID: `argocd`
   - Name: `Argo CD`
3. **Capability config:**
   - Client authentication: `ON`
   - Authorization: `OFF`
   - Authentication flow: включите `Standard flow` и `Direct access grants`
4. **Login settings:**
   - Root URL: `https://argo.buildbyte.ru`
   - Home URL: `https://argo.buildbyte.ru`
   - Valid redirect URIs: `https://argo.buildbyte.ru/auth/callback`
   - Web origins: `https://argo.buildbyte.ru`
5. Нажмите **Save**
6. Перейдите во вкладку **Credentials** и скопируйте **Client secret**

**4. Сохранение Client Secret в Vault:**
```bash
# Сохранить client secret для Argo CD
ARGOCD_CLIENT_SECRET="<скопированный_secret>"

kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='\$(cat /tmp/vault-root-token.txt)'
vault kv put secret/argocd/oidc client-id=argocd client-secret='$ARGOCD_CLIENT_SECRET'
"
```

**5. Создание клиента для Grafana:**
1. Перейдите в **Clients** → **Create client**
2. **General Settings:**
   - Client type: `OpenID Connect`
   - Client ID: `grafana`
   - Name: `Grafana`
3. **Capability config:**
   - Client authentication: `ON`
   - Authentication flow: включите `Standard flow`
4. **Login settings:**
   - Root URL: `https://grafana.buildbyte.ru`
   - Valid redirect URIs: `https://grafana.buildbyte.ru/login/generic_oauth`
   - Web origins: `https://grafana.buildbyte.ru`
5. Нажмите **Save**
6. Сохраните Client secret в Vault:
```bash
GRAFANA_CLIENT_SECRET="<скопированный_secret>"

kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='\$(cat /tmp/vault-root-token.txt)'
vault kv put secret/grafana/oidc client-id=grafana client-secret='$GRAFANA_CLIENT_SECRET'
"
```

**6. Создание клиента для Jenkins:**
1. Перейдите в **Clients** → **Create client**
2. **General Settings:**
   - Client type: `OpenID Connect`
   - Client ID: `jenkins`
   - Name: `Jenkins`
3. **Capability config:**
   - Client authentication: `ON`
   - Authentication flow: включите `Standard flow`
4. **Login settings:**
   - Root URL: `https://jenkins.buildbyte.ru`
   - Valid redirect URIs: `https://jenkins.buildbyte.ru/securityRealm/finishLogin`
   - Web origins: `https://jenkins.buildbyte.ru`
5. Нажмите **Save**
6. Сохраните Client secret в Vault:
```bash
JENKINS_CLIENT_SECRET="<скопированный_secret>"

kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='\$(cat /tmp/vault-root-token.txt)'
vault kv put secret/jenkins/oidc client-id=jenkins client-secret='$JENKINS_CLIENT_SECRET'
"
```

**7. Создание групп и пользователей (опционально):**
1. Перейдите в **Groups** → **Create group**
2. Создайте группы: `admins`, `developers`, `viewers`
3. Перейдите в **Users** → **Add user**
4. Создайте пользователей и назначьте их в группы

**8. Настройка Group Mapper для клиентов:**
Для передачи групп в токен (необходимо для RBAC в Argo CD):
1. Перейдите в **Clients** → выберите клиент (например, `argocd`)
2. Вкладка **Client scopes** → нажмите на `argocd-dedicated`
3. **Add mapper** → **By configuration** → **Group Membership**
4. Настройки:
   - Name: `groups`
   - Token Claim Name: `groups`
   - Full group path: `OFF`
   - Add to ID token: `ON`
   - Add to access token: `ON`
5. Нажмите **Save**

**9. Создание VaultStaticSecret для OIDC клиентов:**

После сохранения client secrets в Vault, создайте VaultStaticSecret для синхронизации в Kubernetes:

```bash
# Создать namespace'ы если ещё не созданы
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace kube-prometheus-stack --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace jenkins --dry-run=client -o yaml | kubectl apply -f -

# Применить VaultStaticSecret для Argo CD OIDC
kubectl apply -f manifests/services/argocd/argocd-oidc-vaultstaticsecret.yaml

# Применить VaultStaticSecret для Grafana OIDC
kubectl apply -f manifests/services/grafana/grafana-oidc-vaultstaticsecret.yaml

# Применить VaultStaticSecret для Jenkins OIDC
kubectl apply -f manifests/services/jenkins/jenkins-oidc-vaultstaticsecret.yaml
```

**Проверка синхронизации:**
```bash
# Проверить статус VaultStaticSecret
kubectl get vaultstaticsecret -A | grep oidc

# Проверить созданные Kubernetes Secrets
kubectl get secret argocd-oidc-secret -n argocd
kubectl get secret grafana-oidc-secret -n kube-prometheus-stack
kubectl get secret jenkins-oidc-secret -n jenkins

# Проверить содержимое секрета (например, для Argo CD)
kubectl get secret argocd-oidc-secret -n argocd -o jsonpath='{.data.client-id}' | base64 -d
```

**Проверка секретов в Vault:**
```bash
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='\$(cat /tmp/vault-root-token.txt)'
vault kv get secret/argocd/oidc
vault kv get secret/grafana/oidc
vault kv get secret/jenkins/oidc
"
```

### 11. Установка Argo CD

**Важно:** Установите приложения ПЕРЕД созданием HTTPRoute, так как HTTPRoute ссылаются на сервисы этих приложений.

#### 11.1. Сохранение секрета администратора Argo CD в Vault

```bash
# Установить переменные для работы с Vault
export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_TOKEN=$(cat /tmp/vault-root-token.txt)

# Убедиться, что KV v2 секретный движок включен
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault secrets enable -version=2 -path=secret kv 2>&1 || echo 'Секретный движок уже включен'
"

# Сохранить пароль администратора Argo CD (bcrypt хеш)
# Для создания bcrypt хеша используйте: htpasswd -nbBC 10 "" <ВАШ_ПАРОЛЬ> | tr -d ':\n' | sed 's/$2y/$2a/'
ARGO_ADMIN_PASSWORD_HASH=$(htpasswd -nbBC 10 "" "<ВАШ_ПАРОЛЬ>" | tr -d ':\n' | sed 's/$2y/$2a/')
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault kv put secret/argocd/admin password='$ARGO_ADMIN_PASSWORD_HASH'
"
```

**Важно для Argo CD:**
- Пароль должен быть bcrypt хешированным
- Используйте команду: `htpasswd -nbBC 10 "" <пароль> | tr -d ':\n' | sed 's/$2y/$2a/'`
- Сохраните хеш в Vault по пути `secret/argocd/admin` с ключом `password`

#### 11.2. Создание VaultStaticSecret для Argo CD

Манифест VaultStaticSecret находится в `manifests/services/argocd/argocd-admin-credentials-vaultstaticsecret.yaml`.

```bash
# Создать namespace для Argo CD
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Применить VaultStaticSecret манифест
kubectl apply -f manifests/services/argocd/argocd-admin-credentials-vaultstaticsecret.yaml

# Проверить синхронизацию секретов
kubectl get vaultstaticsecret -n argocd
kubectl get secret argocd-initial-admin-secret -n argocd
```

#### 11.3. Установка Argo CD

```bash
# 1. Добавить Helm репозиторий
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# 2. Установить Argo CD с использованием существующего секрета
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  -f helm/services/argocd/argocd-values.yaml \
  --set configs.secret.argocdServerAdminPassword="$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d)"

# 3. Проверить установку
kubectl get pods -n argocd

# 4. Дождаться готовности сервиса
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
```

**Получение пароля:**
```bash
# Пароль администратора Argo CD (из Vault через VaultStaticSecret)
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d && echo
# Примечание: Это bcrypt хеш, для использования нужно знать исходный пароль
```

#### 11.4. Создание HTTPRoute для Argo CD

```bash
# 1. Применить HTTPRoute для HTTPS
kubectl apply -f manifests/services/gateway/routes/argocd-https-route.yaml

# 2. Применить HTTPRoute для редиректа HTTP → HTTPS
kubectl apply -f manifests/services/gateway/routes/argocd-http-redirect.yaml

# 3. Проверить HTTPRoute
kubectl get httproute -n argocd
```

**Важно:** HTTPRoute создаётся после готовности сертификатов. Сертификаты создаются автоматически при применении Gateway (раздел 5).

**Проверка:**
```bash
# Проверить статус HTTPRoute
kubectl describe httproute argocd-server -n argocd

# Проверить доступность (должен вернуть HTTP 200 или редирект на логин)
curl -I https://argo.buildbyte.ru/
```

После настройки HTTPRoute Argo CD будет доступен по адресу: `https://argo.buildbyte.ru`

### 12. Установка Jenkins

#### 12.1. Сохранение секретов Jenkins в Vault

```bash
# Установить переменные для работы с Vault
export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_TOKEN=$(cat /tmp/vault-root-token.txt)

# Сохранить credentials администратора Jenkins
# Ключи должны быть jenkins-admin-user и jenkins-admin-password (требование Jenkins Helm chart)
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault kv put secret/jenkins/admin \
  jenkins-admin-user='admin' \
  jenkins-admin-password='<ВАШ_ПАРОЛЬ>'
"

# Сохранить GitHub Personal Access Token
# Создайте токен: GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
# Scopes: repo (для приватных репозиториев) или public_repo (для публичных)
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault kv put secret/jenkins/github token='<ВАШ_GITHUB_TOKEN>'
"

# Сохранить Docker Registry credentials
# Для Timeweb Container Registry используется API Token в качестве пароля
# Данные для buildbyte-container-registry:
#   Домен: buildbyte-container-registry.registry.twcstorage.ru
#   Username: buildbyte-container-registry
#   Password: API Token из панели управления
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault kv put secret/jenkins/docker-registry \
  username='buildbyte-container-registry' \
  password='<ВАШ_API_TOKEN>'
"

# Проверить, что секреты сохранены правильно
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault kv get secret/jenkins/admin
vault kv get secret/jenkins/github
vault kv get secret/jenkins/docker-registry
"
```

#### 12.2. Создание VaultStaticSecret для Jenkins

```bash
# Создать namespace для Jenkins
kubectl create namespace jenkins --dry-run=client -o yaml | kubectl apply -f -

# Применить VaultStaticSecret для admin credentials
kubectl apply -f manifests/services/jenkins/jenkins-admin-credentials-vaultstaticsecret.yaml

# Применить VaultStaticSecret для GitHub token
kubectl apply -f manifests/services/jenkins/jenkins-github-token-vaultstaticsecret.yaml

# Применить VaultStaticSecret для Docker Registry credentials
kubectl apply -f manifests/services/jenkins/jenkins-docker-registry-vaultstaticsecret.yaml

# Проверить синхронизацию секретов
kubectl get vaultstaticsecret -n jenkins
kubectl get secret -n jenkins

# Дождаться синхронизации Docker Registry credentials
kubectl wait --for=jsonpath='{.status.secretMAC}'='' vaultstaticsecret/jenkins-docker-registry -n jenkins --timeout=60s 2>/dev/null || sleep 5

# Проверить значения Docker Registry credentials (должны быть реальные значения)
kubectl get secret jenkins-docker-registry -n jenkins -o jsonpath='{.data.username}' | base64 -d && echo
kubectl get secret jenkins-docker-registry -n jenkins -o jsonpath='{.data.password}' | base64 -d && echo
```

#### 12.3. Установка Jenkins

```bash
# 1. Добавить Helm репозиторий
helm repo add jenkins https://charts.jenkins.io
helm repo update

# 2. Установить Jenkins (admin credentials уже настроены в helm/services/jenkins/jenkins-values.yaml)
helm upgrade --install jenkins jenkins/jenkins \
  --namespace jenkins \
  --create-namespace \
  -f helm/services/jenkins/jenkins-values.yaml

# 3. Проверить установку
kubectl get pods -n jenkins

# 4. Дождаться готовности сервиса
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=jenkins-controller -n jenkins --timeout=300s
```

**Получение пароля:**
```bash
# Пароль администратора Jenkins (из Vault через VaultStaticSecret)
kubectl get secret jenkins-admin-credentials -n jenkins -o jsonpath='{.data.jenkins-admin-password}' | base64 -d && echo
```

#### 12.4. Создание HTTPRoute для Jenkins

```bash
# Применить HTTPRoute для HTTPS доступа
kubectl apply -f manifests/services/gateway/routes/jenkins-https-route.yaml

# Применить HTTPRoute для HTTP→HTTPS редиректа
kubectl apply -f manifests/services/gateway/routes/jenkins-http-redirect.yaml

# Проверить
kubectl get httproute -n jenkins
```

После настройки HTTPRoute Jenkins будет доступен по адресу: `https://jenkins.buildbyte.ru`

#### 12.5. Проверка GitHub credentials в Jenkins

GitHub credentials настроены в `helm/services/jenkins/jenkins-values.yaml` через JCasC и автоматически загружаются при установке.

**Проверка:**

1. Откройте Jenkins: `https://jenkins.buildbyte.ru`
2. Перейдите в **Manage Jenkins** → **Credentials** → **System** → **Global credentials**
3. Должен быть создан credential с ID `github-token` типа "Secret text"
4. Этот credential можно использовать в Pipeline jobs для доступа к GitHub репозиториям

```bash
# Проверить секрет GitHub token
kubectl get secret jenkins-github-token -n jenkins
kubectl get secret jenkins-github-token -n jenkins -o jsonpath='{.data.token}' | base64 -d && echo
```

#### 12.6. Проверка и использование Docker Registry credentials в Jenkins

Docker Registry credentials синхронизируются из Vault через VaultStaticSecret и автоматически загружаются в Jenkins через JCasC при установке.

Для Timeweb Container Registry используется **API Token** вместо пароля. API Token сохраняется в Vault в поле `password`.

**Проверка Docker Registry credentials в Jenkins:**

1. Откройте Jenkins: `https://jenkins.buildbyte.ru`
2. Перейдите в **Manage Jenkins** → **Credentials** → **System** → **Global credentials**
3. Должен быть создан credential с ID `docker-registry` типа "Username with password"
4. Этот credential можно использовать в Pipeline jobs для доступа к приватному Docker Registry

**Важно:**
- GitHub token синхронизируется из Vault через Vault Secrets Operator в секрет `jenkins-github-token`
- Секрет монтируется в Jenkins через `additionalExistingSecrets` и используется в JCasC через переменную `${jenkins-github-token-token}`
- GitHub credentials автоматически создаются в Jenkins через JCasC с ID `github-token`
- Для использования в Pipeline jobs укажите `credentialsId: "github-token"` в конфигурации SCM

### 13. Установка Loki (централизованное хранение логов)

Loki разворачивается в services кластере и используется для централизованного хранения логов из dev кластера через Fluent Bit.

**Важно:** 
- **Loki должен быть развернут ДО установки Prometheus Kube Stack** (раздел 15), так как Loki настроен как источник данных в Grafana через `additionalDataSources`. Если Prometheus Kube Stack развернется раньше Loki, источник данных Loki не будет автоматически настроен при первом развертывании.
- Loki должен быть развернут перед установкой Fluent Bit в services кластере (раздел 14) и перед настройкой Fluent Bit в dev кластере, так как Fluent Bit будет отправлять логи в Loki.

#### 13.1. Установка Loki через Helm

Loki устанавливается через Helm chart в services кластере:

```bash
# Переключиться на services кластер
export KUBECONFIG=$HOME/kubeconfig-services-cluster.yaml

# 1. Добавить Helm репозиторий Grafana
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# 2. Создать namespace для Loki (если еще не создан)
kubectl create namespace logging --dry-run=client -o yaml | kubectl apply -f -

# 3. Установить Loki
helm upgrade --install loki grafana/loki \
  --namespace logging \
  --create-namespace \
  -f helm/services/loki/loki-values.yaml

# 4. Проверить установку Loki
kubectl get pods -n logging -l app.kubernetes.io/name=loki
kubectl get services -n logging -l app.kubernetes.io/name=loki

# 5. Дождаться готовности Loki
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=loki -n logging --timeout=300s
```

**Важно:**
- Loki использует StorageClass `nvme.network-drives.csi.timeweb.cloud` для персистентного хранилища (50Gi по умолчанию)
- Конфигурация Loki находится в `helm/services/loki/loki-values.yaml`
- Loki использует файловую систему для хранения (filesystem storage type)
- Период хранения логов: 720 часов (30 дней) по умолчанию

#### 13.2. Получение внешнего IP адреса LoadBalancer Service

После установки Loki через Helm chart автоматически создается LoadBalancer Service для gateway. Получите внешний IP адрес:

```bash
# Переключиться на services кластер
export KUBECONFIG=$HOME/kubeconfig-services-cluster.yaml

# Дождаться получения внешнего IP адреса LoadBalancer Service
kubectl wait --for=jsonpath='{.status.loadBalancer.ingress[0].ip}' svc loki-gateway -n logging --timeout=300s

# Получить внешний IP адрес Loki
LOKI_EXTERNAL_IP=$(kubectl get svc loki-gateway -n logging -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Loki доступен по адресу: $LOKI_EXTERNAL_IP:3100"
```

**Важно:**
- LoadBalancer Service создается автоматически при установке Loki через Helm chart (настроено в `helm/services/loki/loki-values.yaml`)
- Имя сервиса: `loki-gateway` (если release name = `loki`)
- Запишите внешний IP адрес Loki - он понадобится для настройки Fluent Bit в dev кластере
- Убедитесь, что firewall разрешает подключения к порту 3100 с IP адресов dev кластера

#### 13.3. Проверка доступности Loki

```bash
# Переключиться на services кластер
export KUBECONFIG=$HOME/kubeconfig-services-cluster.yaml

# Получить внешний IP адрес Loki
LOKI_EXTERNAL_IP=$(kubectl get svc loki-gateway -n logging -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Проверить доступность Loki через HTTP API
curl -v http://$LOKI_EXTERNAL_IP:3100/ready

# Проверить метрики Loki
curl http://$LOKI_EXTERNAL_IP:3100/metrics | head -20
```

**Важно:**
- Endpoint `/ready` должен вернуть статус `200 OK`
- Если Loki недоступен, проверьте:
  - Статус подов Loki: `kubectl get pods -n logging -l app.kubernetes.io/name=loki`
  - Логи Loki: `kubectl logs -n logging -l app.kubernetes.io/name=loki --tail=50`
  - Статус LoadBalancer Service: `kubectl describe svc loki-gateway -n logging`

### 14. Установка Fluent Bit (сбор логов) в services кластере

Fluent Bit разворачивается как DaemonSet и собирает логи контейнеров с каждого узла services кластера, отправляя их в Loki.

**Важно:**
- Loki должен быть развернут перед установкой Fluent Bit (см. раздел 13)
- Fluent Bit настроен для отправки логов в Loki через внутренний сервис `loki-gateway.logging.svc.cluster.local:3100` (не требуется внешний IP, так как оба компонента в одном кластере)
- Конфигурация находится в `helm/services/fluent-bit/fluent-bit-values.yaml`

#### 14.1. Установка Fluent Bit через Helm

```bash
# Переключиться на services кластер
export KUBECONFIG=$HOME/kubeconfig-services-cluster.yaml

# 1. Добавить Helm репозиторий Fluent
helm repo add fluent https://fluent.github.io/helm-charts
helm repo update

# 2. Создать namespace для Fluent Bit (если еще не создан)
kubectl create namespace logging --dry-run=client -o yaml | kubectl apply -f -

# 3. Установить Fluent Bit
helm upgrade --install fluent-bit fluent/fluent-bit \
  --namespace logging \
  --create-namespace \
  -f helm/services/fluent-bit/fluent-bit-values.yaml

# 4. Проверить установку
kubectl get pods -n logging -l app.kubernetes.io/name=fluent-bit
kubectl get daemonset -n logging fluent-bit

# 5. Дождаться готовности Fluent Bit
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=fluent-bit -n logging --timeout=300s
```

#### 14.2. Проверка установки Fluent Bit

```bash
# Переключиться на services кластер
export KUBECONFIG=$HOME/kubeconfig-services-cluster.yaml

# 1. Проверить установку Fluent Bit
kubectl get pods -n logging -l app.kubernetes.io/name=fluent-bit
kubectl get daemonset -n logging fluent-bit

# 2. Проверить, что Fluent Bit запущен на всех узлах
kubectl get pods -n logging -l app.kubernetes.io/name=fluent-bit -o wide

# 3. Посмотреть логи Fluent Bit (должны быть записи о запуске и отправке логов в Loki)
kubectl logs -n logging -l app.kubernetes.io/name=fluent-bit --tail=100

# 4. Проверить, что Fluent Bit успешно отправляет логи в Loki
# В логах не должно быть ошибок подключения к Loki
kubectl logs -n logging -l app.kubernetes.io/name=fluent-bit | grep -i "loki\|error\|failed"
```

**Важно:**
- Fluent Bit разворачивается как DaemonSet, по одному поду на каждом узле services кластера
- Логи отправляются в Loki через внутренний сервис `loki-gateway.logging.svc.cluster.local:3100` (ClusterIP)
- Если Fluent Bit не может подключиться к Loki, проверьте:
  - Доступность Loki: `kubectl get svc loki-gateway -n logging`
  - Логи Loki: `kubectl logs -n logging -l app.kubernetes.io/name=loki --tail=50`
  - Логи Fluent Bit: `kubectl logs -n logging -l app.kubernetes.io/name=fluent-bit --tail=50`

### 15. Установка Prometheus Kube Stack (Prometheus + Grafana)

**Важно:** 
- Перед установкой Prometheus Kube Stack необходимо создать секрет с паролем администратора Grafana через Vault Secrets Operator.
- **Loki должен быть развернут ДО установки Prometheus Kube Stack** (см. раздел 13), так как Loki настроен как источник данных в Grafana (`additionalDataSources` в `helm/services/prom-kube-stack/prom-kube-stack-values.yaml`). Если Prometheus Kube Stack развернется раньше Loki, источник данных Loki не будет автоматически настроен.

#### 15.1. Создание секрета в Vault и VaultStaticSecret для Grafana admin credentials

Секрет для Grafana должен быть создан перед установкой Prometheus Kube Stack:

**Шаг 1: Сохранить секреты в Vault**

```bash
# Установить переменные для работы с Vault
export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_TOKEN=$(cat /tmp/vault-root-token.txt)

# Убедиться, что KV v2 секретный движок включен
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault secrets enable -version=2 -path=secret kv 2>&1 || echo 'Секретный движок уже включен'
"

# Сохранить credentials администратора Grafana
# Замените <ВАШ_ПАРОЛЬ> на реальный пароль
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault kv put secret/grafana/admin \
  admin_user='admin' \
  admin_password='<ВАШ_ПАРОЛЬ>'
"

# Проверить, что секреты сохранены правильно
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault kv get secret/grafana/admin
"
```

**Шаг 2: Создать VaultStaticSecret для синхронизации секретов**

```bash
# Создать namespace для Prometheus Kube Stack (если еще не создан)
kubectl create namespace kube-prometheus-stack --dry-run=client -o yaml | kubectl apply -f -

# Применить VaultStaticSecret для admin credentials
kubectl apply -f manifests/services/grafana/grafana-admin-vaultstaticsecret.yaml

# Проверить синхронизацию секретов
kubectl get vaultstaticsecret -n kube-prometheus-stack
kubectl describe vaultstaticsecret grafana-admin-credentials -n kube-prometheus-stack

# Проверить созданный Secret
kubectl get secret grafana-admin -n kube-prometheus-stack
```

#### 15.2. Настройка OIDC для Grafana через Keycloak

**Важно:** OIDC секрет должен быть создан ДО установки Prometheus Kube Stack, чтобы Grafana сразу использовала OIDC аутентификацию.

**Шаг 1: Создать клиент в Keycloak**

1. Войдите в Keycloak Admin Console: `https://keycloak.buildbyte.ru/admin`
2. Выберите Realm (например, `services`)
3. Перейдите в **Clients** → **Create client**
4. Настройте клиент:
   - **Client ID:** `grafana`
   - **Client protocol:** `openid-connect`
   - **Access Type:** `confidential`
   - **Valid Redirect URIs:** 
     - `https://grafana.buildbyte.ru/login/generic_oauth`
   - **Web Origins:** `https://grafana.buildbyte.ru`
5. Сохраните клиент и перейдите на вкладку **Credentials**
6. Скопируйте **Secret** (Client Secret)

**Шаг 2: Сохранить Client Secret в Vault**

```bash
# Сохранить Client Secret для Grafana OIDC
# Замените <ВАШ_CLIENT_SECRET> на реальный Client Secret из Keycloak
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault kv put secret/grafana/oidc \
  client_secret='<ВАШ_CLIENT_SECRET>'
"

# Проверить, что секрет сохранен правильно
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault kv get secret/grafana/oidc
"
```

**Шаг 3: Создать VaultStaticSecret для синхронизации Client Secret**

```bash
# Применить VaultStaticSecret для OIDC credentials
kubectl apply -f manifests/services/grafana/grafana-oidc-vaultstaticsecret.yaml

# Проверить статус VaultStaticSecret
kubectl get vaultstaticsecret -n kube-prometheus-stack
kubectl describe vaultstaticsecret grafana-oidc-credentials -n kube-prometheus-stack

# Проверить созданный Secret
kubectl get secret grafana-oidc-secret -n kube-prometheus-stack

# Проверить значение Client Secret (должно быть реальное значение)
kubectl get secret grafana-oidc-secret -n kube-prometheus-stack -o jsonpath='{.data.client_secret}' | base64 -d && echo
```

#### 15.3. Установка Prometheus Kube Stack

**Важно:** Убедитесь, что Loki развернут (см. раздел 13) перед установкой Prometheus Kube Stack, так как Loki настроен как источник данных в Grafana.

```bash
# 1. Добавить Helm репозиторий Prometheus Community
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# 2. Установить Prometheus Kube Stack
# Admin credentials уже настроены в helm/services/prom-kube-stack/prom-kube-stack-values.yaml
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace kube-prometheus-stack \
  --create-namespace \
  -f helm/services/prom-kube-stack/prom-kube-stack-values.yaml

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
- Секреты `grafana-admin` и `grafana-oidc-secret` должны быть созданы через Vault Secrets Operator перед установкой
- **Loki должен быть развернут ДО установки Prometheus Kube Stack** (см. раздел 13), так как Loki настроен как источник данных в Grafana через `additionalDataSources`

**Получение пароля администратора Grafana:**
```bash
# Имя администратора Grafana (из Vault через VaultStaticSecret)
kubectl get secret grafana-admin -n kube-prometheus-stack -o jsonpath='{.data.admin-user}' | base64 -d && echo

# Пароль администратора Grafana (из Vault через VaultStaticSecret)
kubectl get secret grafana-admin -n kube-prometheus-stack -o jsonpath='{.data.admin-password}' | base64 -d && echo
```

**Проверка OIDC:**

1. Откройте Grafana: `https://grafana.buildbyte.ru`
2. Должна появиться кнопка **"LOG IN VIA KEYCLOAK"** или **"LOG IN VIA OIDC"**
3. Выполните вход через Keycloak
4. Проверьте, что пользователь успешно аутентифицирован

**Примечание:** Роли настраиваются на основе групп из Keycloak:
- Группа `GrafanaAdmins` получает роль `Admin`
- Группа `GrafanaEditors` получает роль `Editor`
- Остальные пользователи получают роль `Viewer`

#### 15.4. Создание HTTPRoute для Grafana

```bash
# Применить HTTPRoute для HTTPS доступа
kubectl apply -f manifests/services/gateway/routes/grafana-https-route.yaml

# Применить HTTPRoute для HTTP→HTTPS редиректа
kubectl apply -f manifests/services/gateway/routes/grafana-http-redirect.yaml

# Проверить
kubectl get httproute -n kube-prometheus-stack
```

После настройки HTTPRoute Grafana будет доступна по адресу: `https://grafana.buildbyte.ru`

## Развертывание и настройка Dev кластера

Пошаговая инструкция по развертыванию и настройке dev кластера для разработки и развертывания микросервисов.

**Важно:** Dev кластер должен быть развернут после настройки Services кластера, так как он использует Vault из Services кластера для хранения секретов.

**GitOps (Argo CD):** развертка базовых компонентов dev кластера (**cert-manager**, **vault-secrets-operator**, **fluent-bit**) выполняется через Argo CD `Application` в services кластере.

**Важно:** Перед применением Application необходимо создать AppProject для организации Application:

```bash
# Переключиться на services кластер
export KUBECONFIG=$HOME/kubeconfig-services-cluster.yaml

# 1. Применить AppProject (должны быть созданы до Application)
kubectl apply -f manifests/services/argocd/appprojects/

# 2. Применить Application для инфраструктурных сервисов
kubectl apply -f manifests/services/argocd/applications/dev/
```

**AppProject:**
- `manifests/services/argocd/appprojects/dev-infrastructure-project.yaml` — для инфраструктурных сервисов
- `manifests/services/argocd/appprojects/dev-microservices-project.yaml` — для микросервисов

**Application для инфраструктурных сервисов:**
- `manifests/services/argocd/applications/dev/application-cert-manager.yaml`
- `manifests/services/argocd/applications/dev/application-vault-secrets-operator.yaml`
- `manifests/services/argocd/applications/dev/application-fluent-bit.yaml`

Подробнее о AppProject см. раздел "Создание AppProject для организации Application".

### Шаг 1: Развертывание кластера через Terraform

```bash
# 1. Перейти в директорию dev
cd terraform/dev

# 2. Инициализировать Terraform (загрузит провайдеры и настроит backend)
terraform init

# 3. Проверить план развертывания (опционально)
terraform plan

# 4. Применить конфигурацию и создать кластер
# Подтвердите создание ресурсов при запросе
terraform apply

# 5. После создания кластера, kubeconfig будет автоматически сохранен в:
# ~/kubeconfig-dev-cluster.yaml
```

**Важно:** После создания кластера настройте kubectl для работы с dev кластером:

```bash
# Настроить kubeconfig для dev кластера
export KUBECONFIG=$HOME/kubeconfig-dev-cluster.yaml

# Проверить подключение к кластеру
kubectl get nodes
kubectl get pods -A

# Проверить версию кластера
kubectl version --short
```

### Шаг 2: Установка CSI драйвера Timeweb Cloud

CSI драйвер необходим для работы с Persistent Volumes (сетевыми дисками):

```bash
# 1. Получить Cluster ID dev кластера
# Cluster ID можно найти в панели управления Timeweb Cloud
# Или получить из Terraform state:
cd terraform/dev
terraform show | grep -i "id.*=" | head -1

# 2. Отредактировать helm/dev/csi-tw/csi-tw-values.yaml:
#    - Указать TW_API_SECRET (API токен Timeweb Cloud)
#    - Указать TW_CLUSTER_ID (ID dev кластера, будет отличаться от services кластера)

# 3. Установить CSI драйвер
# Примечание: Проверьте актуальный способ установки в документации Timeweb Cloud
# Возможно, установка выполняется через панель управления, а не через Helm

# Если установка через Helm доступна:
helm repo add timeweb-cloud https://charts.timeweb.cloud  # Проверьте актуальный URL
helm repo update
helm upgrade --install csi-driver-timeweb-cloud timeweb-cloud/csi-driver \
  --namespace kube-system \
  -f helm/dev/csi-tw/csi-tw-values.yaml

# 4. Проверить установку
kubectl get pods -n kube-system | grep csi-driver
kubectl get storageclass
```

**Важно:** 
- Убедитесь, что API ключ имеет права на управление сетевыми дисками
- Cluster ID для dev кластера будет отличаться от services кластера
- Проверьте актуальную документацию Timeweb Cloud для установки CSI драйвера

### Шаг 3: Установка Gateway API с NGINX Gateway Fabric

Gateway API необходим для управления ingress трафиком:

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

# 5. Дождаться готовности контроллера
kubectl wait --for=condition=ready pod -l app=nginx-gateway-fabric -n nginx-gateway --timeout=300s
```

### Шаг 4: Установка cert-manager

cert-manager необходим для автоматического управления TLS сертификатами через Let's Encrypt.

**Важно:** cert-manager должен быть установлен ДО создания Gateway, так как Gateway использует аннотацию `cert-manager.io/cluster-issuer` для автоматического получения сертификатов.

```bash
# 1. Добавить Helm репозиторий
helm repo add jetstack https://charts.jetstack.io
helm repo update

# 2. Установить cert-manager с поддержкой Gateway API
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  -f helm/dev/cert-manager/cert-manager-values.yaml

# 3. Проверить установку
kubectl get pods -n cert-manager
kubectl get crd | grep cert-manager

# 4. Дождаться готовности cert-manager
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s
```

**Важно:** 
- Флаг `config.enableGatewayAPI: true` (в `helm/dev/cert-manager/cert-manager-values.yaml`) **обязателен** для работы с Gateway API!

### Шаг 5: Создание ClusterIssuer

```bash
# 1. Применить ClusterIssuer (отредактируйте email перед применением!)
kubectl apply -f manifests/dev/cert-manager/cluster-issuer.yaml

# 2. Проверить ClusterIssuer
kubectl get clusterissuer
kubectl describe clusterissuer letsencrypt-prod
```

**Важно:** Замените `admin@buildbyte.ru` на ваш реальный email в `manifests/dev/cert-manager/cluster-issuer.yaml`

### Шаг 6: Создание Gateway

После установки cert-manager и ClusterIssuer создайте Gateway. cert-manager автоматически создаст сертификаты для каждого HTTPS listener благодаря аннотации `cert-manager.io/cluster-issuer`.

```bash
# 1. Применить Gateway
kubectl apply -f manifests/dev/gateway/gateway.yaml

# 2. Проверить статус Gateway
kubectl get gateway -n default
kubectl describe gateway dev-gateway -n default

# 3. Проверить, что Gateway получил IP адрес
kubectl get gateway dev-gateway -n default -o jsonpath='{.status.addresses[0].value}'

# 4. Проверить автоматически созданные сертификаты
kubectl get certificate -n default

# 5. Дождаться готовности сертификатов (может занять 1-2 минуты)
kubectl get certificate -n default -w
```

**Важно:** 
- Имя Gateway: `dev-gateway`
- Gateway создается в namespace `default`
- cert-manager автоматически создаёт Certificate для каждого HTTPS listener
- После создания Gateway получите его IP адрес и настройте DNS записи для ваших доменов

**Автоматически создаваемые сертификаты:**
| Hostname | Secret |
|----------|--------|
| donweather.dev.buildbyte.ru | donweather-tls-cert |
| api.donweather.dev.buildbyte.ru | donweather-api-tls-cert |

### Шаг 7: Установка и настройка Vault Secrets Operator для работы с внешним Vault

Vault Secrets Operator будет подключаться к Vault, который находится в services кластере.

#### 7.1. Установка Vault Secrets Operator

```bash
# 1. Добавить Helm репозиторий HashiCorp (если еще не добавлен)
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# 2. Установить Vault Secrets Operator
helm upgrade --install vault-secrets-operator hashicorp/vault-secrets-operator \
  --version 0.10.0 \
  --namespace vault-secrets-operator \
  --create-namespace \
  -f helm/services/vault-secrets-operator/vault-secrets-operator-values.yaml

# 3. Проверить установку
kubectl get pods -n vault-secrets-operator
kubectl get crd | grep secrets.hashicorp.com

# 4. Дождаться готовности Vault Secrets Operator
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=vault-secrets-operator -n vault-secrets-operator --timeout=300s
```

#### 7.2. Проверка HTTPRoute для Vault в services кластере

Vault доступен через HTTPRoute в services кластере по адресу `https://vault.buildbyte.ru`.

**Проверка HTTPRoute:**

```bash
# Переключиться на services кластер
export KUBECONFIG=$HOME/kubeconfig-services-cluster.yaml

# Проверить HTTPRoute для Vault
kubectl get httproute vault-server -n vault
kubectl describe httproute vault-server -n vault

# Проверить, что HTTPRoute правильно настроен
kubectl get httproute vault-server -n vault -o yaml
```

**Текущий HTTPRoute для Vault:**
- **Имя:** `vault-server`
- **Namespace:** `vault`
- **Hostname:** `vault.buildbyte.ru`
- **Gateway:** `service-gateway` (HTTPS listener)
- **Backend:** сервис `vault:8200` в namespace `vault`

**Файл манифеста:** `manifests/services/gateway/routes/vault-https-route.yaml`

**Важно:** 
- Убедитесь, что DNS запись для `vault.buildbyte.ru` указывает на IP адрес Gateway в services кластере
- Убедитесь, что TLS сертификат для `vault.buildbyte.ru` создан и валиден
- HTTPRoute должен быть применен в services кластере: `kubectl apply -f manifests/services/gateway/routes/vault-https-route.yaml`

**Адрес Vault для подключения из dev кластера:**
- **HTTPS:** `https://vault.buildbyte.ru:443` (рекомендуется)
- **HTTP:** `http://vault.buildbyte.ru:80` (будет редиректить на HTTPS)

#### 7.3. Настройка Kubernetes Auth в Vault для dev кластера

Vault должен быть настроен для аутентификации ServiceAccount из dev кластера. Это позволит Vault Secrets Operator в dev кластере получать секреты из Vault в services кластере.

**Пункт 1: Подготовка переменных для работы с Vault**

```bash
# Переключиться на services кластер (где находится Vault)
export KUBECONFIG=$HOME/kubeconfig-services-cluster.yaml

# Получить токен Vault
export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_TOKEN=$(cat /tmp/vault-root-token.txt)
```

**Пункт 2: Создание ServiceAccount для token reviewer в dev кластере**

Token reviewer — это ServiceAccount, который Vault использует для проверки JWT токенов, приходящих из dev кластера.

```bash
# Переключиться на dev кластер
export KUBECONFIG=$HOME/kubeconfig-dev-cluster.yaml

# Создать namespace (если еще не создан)
kubectl create namespace vault-secrets-operator --dry-run=client -o yaml | kubectl apply -f -

# Создать ServiceAccount для token reviewer
kubectl create serviceaccount vault-token-reviewer -n vault-secrets-operator --dry-run=client -o yaml | kubectl apply -f -
```

**Пункт 3: Создание ClusterRoleBinding для token reviewer**

Даём ServiceAccount права на выполнение TokenReview запросов к Kubernetes API.

```bash
# В dev кластере
kubectl create clusterrolebinding vault-token-reviewer-auth-delegator \
  --clusterrole=system:auth-delegator \
  --serviceaccount=vault-secrets-operator:vault-token-reviewer \
  --dry-run=client -o yaml | kubectl apply -f -
```

**Пункт 4: Получение данных dev кластера для настройки Vault**

Собираем данные, которые нужны Vault для проверки токенов из dev кластера.

```bash
# В dev кластере

# 4.1. Получить токен ServiceAccount (действует 1 год)
DEV_TOKEN_REVIEWER_JWT=$(kubectl create token vault-token-reviewer -n vault-secrets-operator --duration=8760h)

# 4.2. Получить CA сертификат dev кластера
DEV_CA_CERT=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.certificate-authority-data}' | base64 -d)

# 4.3. Получить адрес Kubernetes API dev кластера
DEV_K8S_HOST=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.server}')

# Проверить полученные значения
echo "DEV_K8S_HOST: $DEV_K8S_HOST"
echo "DEV_TOKEN_REVIEWER_JWT длина: ${#DEV_TOKEN_REVIEWER_JWT}"
echo "DEV_CA_CERT длина: ${#DEV_CA_CERT}"
```

**Пункт 5: Включение Kubernetes auth в Vault для dev кластера**

```bash
# Переключиться на services кластер
export KUBECONFIG=$HOME/kubeconfig-services-cluster.yaml

# Включить Kubernetes auth method с путём kubernetes-dev
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault auth enable -path=kubernetes-dev kubernetes 2>&1 || echo 'Kubernetes auth уже включен'
"
```

**Пункт 6: Настройка конфигурации Kubernetes auth**

Передаём Vault данные dev кластера для проверки токенов.

```bash
# В services кластере
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault write auth/kubernetes-dev/config \
  token_reviewer_jwt='$DEV_TOKEN_REVIEWER_JWT' \
  kubernetes_host='$DEV_K8S_HOST' \
  kubernetes_ca_cert='$DEV_CA_CERT' \
  disable_iss_validation=true
"
```

**Пункт 7: Создание политики доступа для dev кластера**

Политика определяет, какие секреты могут читать приложения из dev кластера.

```bash
# В services кластере
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault policy write vault-secrets-operator-dev-policy - <<'EOF'
# Политика для Vault Secrets Operator из dev кластера
# Разрешает чтение всех секретов
path \"secret/data/*\" {
  capabilities = [\"read\"]
}
path \"secret/metadata/*\" {
  capabilities = [\"read\", \"list\"]
}
EOF
"
```

**Пункт 8: Создание роли в Vault для Vault Secrets Operator**

Роль связывает ServiceAccount из dev кластера с политикой доступа.

```bash
# В services кластере
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault write auth/kubernetes-dev/role/vault-secrets-operator \
  bound_service_account_names=default \
  bound_service_account_namespaces='*' \
  policies=vault-secrets-operator-dev-policy \
  ttl=1h
"
```

**Пункт 9: Проверка настройки**

```bash
# В services кластере
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'

# Проверить auth method
vault auth list | grep kubernetes-dev

# Проверить конфигурацию
vault read auth/kubernetes-dev/config

# Проверить политику
vault policy read vault-secrets-operator-dev-policy

# Проверить роль
vault read auth/kubernetes-dev/role/vault-secrets-operator
"
```

**Важно:** 
- Token reviewer JWT должен быть получен из **dev кластера**
- CA сертификат и адрес Kubernetes API должны соответствовать **dev кластеру**
- Токен действует 1 год (`--duration=8760h`), после истечения нужно обновить

#### 7.4. Создание VaultConnection и VaultAuth для подключения к внешнему Vault

VaultConnection и VaultAuth с именем `default` уже созданы при установке Vault Secrets Operator. Нужно обновить их для подключения к Vault в services кластере.

```bash
# Переключиться на dev кластер
export KUBECONFIG=$HOME/kubeconfig-dev-cluster.yaml

# Применить VaultConnection
kubectl apply -f manifests/dev/vault-secrets-operator/vault-connection.yaml

# Применить VaultAuth
kubectl apply -f manifests/dev/vault-secrets-operator/vault-auth.yaml

# Проверить VaultConnection и VaultAuth
kubectl get vaultconnection -n vault-secrets-operator
kubectl get vaultauth -n vault-secrets-operator
kubectl describe vaultauth default -n vault-secrets-operator
```

**Важно:** 
- VaultConnection и VaultAuth используют имя `default` — это стандартное имя, на которое ссылаются VaultStaticSecret
- Адрес Vault: `https://vault.buildbyte.ru` (через HTTPRoute в services кластере)
- Auth method mount: `kubernetes-dev` (отдельный от services кластера)
- VaultStaticSecret ссылаются на VaultAuth через `vaultAuthRef: vault-secrets-operator/default`

### Шаг 8: Настройка Argo CD для управления dev кластером

Для развертывания приложений в dev кластере через Argo CD необходимо добавить dev кластер и создать AppProject.

#### 8.1. Добавление dev кластера в Argo CD

Добавление кластера выполняется через создание Secret с kubeconfig:

```bash
# Переключиться на services кластер
export KUBECONFIG=$HOME/kubeconfig-services-cluster.yaml

# Получить адрес API сервера dev кластера
DEV_CLUSTER_SERVER=$(kubectl config view --kubeconfig=$HOME/kubeconfig-dev-cluster.yaml --raw --minify --flatten -o jsonpath='{.clusters[].cluster.server}')

# Получить CA сертификат dev кластера (base64)
DEV_CA_DATA=$(kubectl config view --kubeconfig=$HOME/kubeconfig-dev-cluster.yaml --raw --minify --flatten -o jsonpath='{.clusters[].cluster.certificate-authority-data}')

# Получить токен для аутентификации (из kubeconfig или создать ServiceAccount)
# Вариант: использовать токен из kubeconfig
DEV_TOKEN=$(kubectl config view --kubeconfig=$HOME/kubeconfig-dev-cluster.yaml --raw --minify --flatten -o jsonpath='{.users[].user.token}')

# Создать Secret для Argo CD
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: dev-cluster-secret
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
type: Opaque
stringData:
  name: dev-cluster
  server: "$DEV_CLUSTER_SERVER"
  config: |
    {
      "bearerToken": "$DEV_TOKEN",
      "tlsClientConfig": {
        "insecure": false,
        "caData": "$DEV_CA_DATA"
      }
    }
EOF

# Проверить, что Secret создан
kubectl get secret dev-cluster-secret -n argocd

# Проверить статус кластера в Argo CD
# Откройте https://argo.buildbyte.ru → Settings → Clusters
# Должен отображаться кластер dev-cluster
```

**Важно:** Подробная инструкция и диагностика в разделе "Добавление dev кластера в Argo CD".

#### 8.2. Создание AppProject для dev кластера

AppProject организует Application и определяет права доступа:

```bash
# Переключиться на services кластер
export KUBECONFIG=$HOME/kubeconfig-services-cluster.yaml

# Применить AppProject для инфраструктурных сервисов dev кластера
kubectl apply -f manifests/services/argocd/appprojects/dev-infrastructure-project.yaml

# Применить AppProject для микросервисов dev кластера
kubectl apply -f manifests/services/argocd/appprojects/dev-microservices-project.yaml

# Проверить, что AppProject созданы
kubectl get appproject -n argocd
kubectl describe appproject dev-infrastructure -n argocd
kubectl describe appproject dev-microservices -n argocd
```

**AppProject:**
- `dev-infrastructure` — для инфраструктурных сервисов (cert-manager, vault-secrets-operator, fluent-bit)
- `dev-microservices` — для микросервисов (donweather и другие приложения)

### Шаг 9: Установка Fluent Bit (сбор логов) в dev кластере

Fluent Bit разворачивается как DaemonSet и собирает логи контейнеров с каждого узла dev кластера, отправляя их в Loki, который развернут в services кластере.

**Важно:**
- Перед установкой Fluent Bit убедитесь, что Loki развернут в services кластере и LoadBalancer Service `loki-gateway` получил внешний IP адрес (см. раздел 13)
- Fluent Bit настроен для отправки логов в Loki через HTTP API
- AppProject `dev-infrastructure` должен быть создан (см. Шаг 8)

#### 9.1. Настройка Fluent Bit для отправки логов в Loki

Перед установкой Fluent Bit проверьте, что IP адрес Loki указан правильно в конфигурации:

```bash
# 1. Переключиться на services кластер и получить внешний IP адрес Loki
export KUBECONFIG=$HOME/kubeconfig-services-cluster.yaml
LOKI_EXTERNAL_IP=$(kubectl get svc loki-gateway -n logging -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Внешний IP адрес Loki: $LOKI_EXTERNAL_IP"

# 2. Проверить текущий IP адрес в конфигурации Fluent Bit
grep "Host" helm/dev/fluent-bit/fluent-bit-values.yaml | grep -v "#"

# 3. Если IP адрес отличается, обновить вручную в файле:
# helm/dev/fluent-bit/fluent-bit-values.yaml
# Найти секцию [OUTPUT] и заменить Host на актуальный IP адрес Loki
```

**Важно:**
- IP адрес Loki указывается в секции `config.outputs` файла `helm/dev/fluent-bit/fluent-bit-values.yaml`
- IP адрес можно получить командой: `kubectl get svc loki-gateway -n logging -o jsonpath='{.status.loadBalancer.ingress[0].ip}'`
- Если LoadBalancer еще не получил IP адрес, дождитесь его назначения перед настройкой Fluent Bit

#### 9.2. Развертывание Fluent Bit через Argo CD Application

Fluent Bit разворачивается через Argo CD Application в services кластере:

```bash
# Переключиться на services кластер
export KUBECONFIG=$HOME/kubeconfig-services-cluster.yaml

# 1. Применить Argo CD Application для Fluent Bit
kubectl apply -f manifests/services/argocd/applications/dev/application-fluent-bit.yaml

# 2. Проверить статус Application в Argo CD
kubectl get application fluent-bit-dev -n argocd
kubectl describe application fluent-bit-dev -n argocd

# 3. Дождаться синхронизации (Application должна быть в статусе Synced)
kubectl wait --for=condition=Synced application fluent-bit-dev -n argocd --timeout=300s
```

#### 9.3. Проверка установки Fluent Bit

```bash
# Переключиться на dev кластер
export KUBECONFIG=$HOME/kubeconfig-dev-cluster.yaml

# 1. Проверить установку Fluent Bit
kubectl get pods -n logging -l app.kubernetes.io/name=fluent-bit
kubectl get daemonset -n logging fluent-bit

# 2. Проверить, что Fluent Bit запущен на всех узлах
kubectl get pods -n logging -l app.kubernetes.io/name=fluent-bit -o wide

# 3. Посмотреть логи Fluent Bit (должны быть записи о запуске и отправке логов в Loki)
kubectl logs -n logging -l app.kubernetes.io/name=fluent-bit --tail=100

# 4. Проверить, что Fluent Bit успешно отправляет логи в Loki
# В логах не должно быть ошибок подключения к Loki
kubectl logs -n logging -l app.kubernetes.io/name=fluent-bit | grep -i "loki\|error\|failed"
```

**Важно:**
- Fluent Bit разворачивается как DaemonSet, по одному поду на каждом узле dev кластера
- Логи отправляются в Loki через HTTP API на порт 3100
- Если Fluent Bit не может подключиться к Loki, проверьте:
  - Внешний IP адрес Loki в конфигурации Fluent Bit
  - Доступность Loki из dev кластера: `curl http://<LOKI_EXTERNAL_IP>:3100/ready`
  - Firewall правила для порта 3100

### Создание базовых Namespaces

Namespaces для сервисов будут создаваться вручную позже в зависимости от названий сервисов.

```bash
# Пример создания namespace для сервиса:
kubectl create namespace <название-сервиса> --dry-run=client -o yaml | kubectl apply -f -

# Проверить созданные namespaces
kubectl get namespaces
```

### Добавление dev кластера в Argo CD

Argo CD в services кластере должен быть настроен для управления приложениями в dev кластере.

**Пункт 1: Получить данные dev кластера**

```bash
# Адрес API сервера dev кластера
DEV_CLUSTER_SERVER=$(kubectl config view --kubeconfig=$HOME/kubeconfig-dev-cluster.yaml --raw --minify -o jsonpath='{.clusters[].cluster.server}')
echo "Server: $DEV_CLUSTER_SERVER"

# CA сертификат (base64)
DEV_CA_DATA=$(kubectl config view --kubeconfig=$HOME/kubeconfig-dev-cluster.yaml --raw --minify -o jsonpath='{.clusters[].cluster.certificate-authority-data}')
echo "CA Data: ${DEV_CA_DATA:0:50}..."

# Токен (если есть в kubeconfig)
DEV_TOKEN=$(kubectl config view --kubeconfig=$HOME/kubeconfig-dev-cluster.yaml --raw --minify -o jsonpath='{.users[].user.token}')
echo "Token: ${DEV_TOKEN:0:20}..."
```

**Пункт 2: Заполнить manifest файл**

Отредактируйте файл `manifests/services/argocd/dev-cluster-secret.yaml`:
- Замените `<DEV_CLUSTER_SERVER>` на адрес API сервера
- Замените `<DEV_BEARER_TOKEN>` на токен
- Замените `<DEV_CA_DATA_BASE64>` на CA сертификат (base64)

**Пункт 3: Применить Secret**

```bash
# Переключиться на services кластер
export KUBECONFIG=$HOME/kubeconfig-services-cluster.yaml

# Применить Secret
kubectl apply -f manifests/services/argocd/dev-cluster-secret.yaml

# Проверить, что Secret создан
kubectl get secret dev-cluster-secret -n argocd
```

**Пункт 4: Проверить в Argo CD**

1. Откройте https://argo.buildbyte.ru
2. Авторизуйтесь через Keycloak
3. Перейдите в **Settings** → **Clusters**
4. Должен отображаться кластер `dev-cluster` со статусом "Connected"

**Диагностика, если кластер не отображается:**

```bash
# Проверить Secret
kubectl get secret dev-cluster-secret -n argocd -o yaml

# Проверить логи Argo CD
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --tail=50 | grep -i cluster

# Проверить доступность API сервера
kubectl cluster-info

# 4. Проверить формат kubeconfig
# Убедитесь, что kubeconfig содержит все необходимые поля:
kubectl config view --kubeconfig=$HOME/kubeconfig-dev-cluster.yaml --raw --minify --flatten

# 5. Пересоздать Secret с правильным форматом (если нужно)
# Удалить существующий Secret
kubectl delete secret dev-cluster-secret -n argocd

# Создать Secret заново (см. шаг 2 выше)

# 6. Проверить логи Argo CD для детальной информации об ошибке
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --tail=100 | grep -i "dev-cluster\|unmarshal\|cluster secret"

# 7. Альтернативный способ: создать Secret через kubectl create с правильным форматом
# Если предыдущий способ не работает, попробуйте:
export KUBECONFIG=$HOME/kubeconfig-services-cluster.yaml
DEV_CLUSTER_SERVER=$(kubectl config view --kubeconfig=$HOME/kubeconfig-dev-cluster.yaml --raw --minify --flatten -o jsonpath='{.clusters[].cluster.server}')

# Создать Secret напрямую через kubectl (без временных файлов)
kubectl create secret generic dev-cluster-secret \
  --from-literal=name=dev-cluster \
  --from-literal=server="$DEV_CLUSTER_SERVER" \
  --from-file=config=$HOME/kubeconfig-dev-cluster.yaml \
  -n argocd \
  --dry-run=client -o yaml | \
  kubectl label --local -f - argocd.argoproj.io/secret-type=cluster -o yaml | \
  kubectl apply -f -
```

**Типичные проблемы:**

1. **Secret не содержит правильные ключи:**
   - Убедитесь, что Secret содержит `name`, `server` и `config`
   - `config` должен быть полным kubeconfig в формате YAML

2. **Неправильный формат kubeconfig:**
   - Убедитесь, что kubeconfig содержит `clusters`, `users`, `contexts`
   - Проверьте, что все сертификаты и токены валидны

3. **Argo CD не может подключиться к API серверу:**
   - Проверьте сетевую доступность между кластерами
   - Убедитесь, что API сервер dev кластера доступен из services кластера

4. **Метка отсутствует:**
   - Убедитесь, что Secret имеет метку `argocd.argoproj.io/secret-type: cluster`

**Важно:**
- Argo CD должен иметь доступ к API серверу dev кластера
- Если кластеры находятся в разных сетях, убедитесь, что сетевые правила разрешают доступ
- После добавления кластера может потребоваться несколько секунд для его появления в интерфейсе
- После добавления кластера можно создавать Application в Argo CD, которые будут развертываться в dev кластер

#### Добавление dev кластера в Argo CD через Vault Secrets Operator

Альтернативный способ добавления dev кластера в Argo CD через Vault Secrets Operator, который синхронизирует kubeconfig из Vault.

**Преимущества:**
- Централизованное хранение kubeconfig в Vault
- Автоматическая синхронизация при изменении kubeconfig
- Управление через Git (VaultStaticSecret манифест)

**Шаг 1: Подготовить kubeconfig для Argo CD**

Argo CD ожидает упрощенный формат config с `bearerToken` и `tlsClientConfig`:

```bash
# Переключиться на dev кластер
export KUBECONFIG=$HOME/kubeconfig-dev-cluster.yaml

# Получить адрес API сервера
DEV_CLUSTER_SERVER=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.server}')

# Получить токен (если используется токен для аутентификации)
# Для ServiceAccount токена:
DEV_TOKEN=$(kubectl create token dashboard-user -n kube-system --duration=8760h)

# Получить CA сертификат (base64)
DEV_CA_DATA=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.certificate-authority-data}')

# Извлечь serverName из URL (убрать https:// и порт)
DEV_SERVER_NAME=$(echo $DEV_CLUSTER_SERVER | sed 's|https://||' | sed 's|:.*||')

# Создать config в формате JSON
CONFIG_JSON=$(cat <<EOF | jq -c .
{
  "bearerToken": "$DEV_TOKEN",
  "tlsClientConfig": {
    "serverName": "$DEV_SERVER_NAME",
    "caData": "$DEV_CA_DATA"
  }
}
EOF
)

# Вывести config для проверки
echo "Config JSON:"
echo $CONFIG_JSON | jq .
```

**Шаг 2: Сохранить kubeconfig в Vault**

```bash
# Переключиться на services кластер
export KUBECONFIG=$HOME/kubeconfig-services-cluster.yaml

# Установить переменные для работы с Vault
export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_TOKEN=$(cat /tmp/vault-root-token.txt)

# Убедиться, что KV v2 секретный движок включен
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault secrets enable -version=2 -path=secret kv 2>&1 || echo 'Секретный движок уже включен'
"

# Сохранить kubeconfig в Vault
# ВАЖНО: Замените <DEV_CLUSTER_SERVER>, <CONFIG_JSON> на реальные значения из шага 1
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault kv put secret/argocd/dev-cluster \
  name='dev-cluster' \
  server='<DEV_CLUSTER_SERVER>' \
  config='<CONFIG_JSON>'
"

# Или сохранить через переменные окружения (более безопасно)
# Сначала установите переменные из шага 1, затем:
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault kv put secret/argocd/dev-cluster \
  name='dev-cluster' \
  server='$DEV_CLUSTER_SERVER' \
  config='$CONFIG_JSON'
"

# Проверить, что секрет сохранен правильно
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault kv get secret/argocd/dev-cluster
"
```

**Шаг 3: Создать VaultStaticSecret манифест**

```bash
# Переключиться на services кластер
export KUBECONFIG=$HOME/kubeconfig-services-cluster.yaml

# Создать VaultStaticSecret для синхронизации dev cluster credentials
cat <<EOF | kubectl apply -f -
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  name: dev-cluster-secret
  namespace: argocd
  labels:
    app: argocd
    component: cluster-config
spec:
  vaultAuthRef: vault-secrets-operator/default
  mount: secret
  type: kv-v2
  path: argocd/dev-cluster
  refreshAfter: 60s
  destination:
    name: dev-cluster
    create: true
    labels:
      argocd.argoproj.io/secret-type: cluster
EOF

# Проверить статус VaultStaticSecret
kubectl get vaultstaticsecret dev-cluster-secret -n argocd
kubectl describe vaultstaticsecret dev-cluster-secret -n argocd

# Проверить созданный Secret
kubectl get secret dev-cluster -n argocd
kubectl describe secret dev-cluster -n argocd

# Проверить, что Secret содержит правильные ключи
kubectl get secret dev-cluster -n argocd -o jsonpath='{.data.name}' | base64 -d && echo
kubectl get secret dev-cluster -n argocd -o jsonpath='{.data.server}' | base64 -d && echo
kubectl get secret dev-cluster -n argocd -o jsonpath='{.data.config}' | base64 -d | jq .

# Проверить метку
kubectl get secret dev-cluster -n argocd -o jsonpath='{.metadata.labels}' | jq .
```

**Шаг 5: Проверить статус кластера в Argo CD**

```bash
# Проверить логи Argo CD Application Controller
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --tail=50 | grep -i "dev-cluster\|cluster secret"

# Проверить статус кластера в Argo CD через веб-интерфейс
# Откройте https://argo.buildbyte.ru
# Авторизуйтесь через Keycloak
# Перейдите в Settings > Clusters
# Должен отображаться кластер dev-cluster со статусом "Connected"
```

**Важно:**
- VaultStaticSecret создает Secret с именем `dev-cluster` (указано в `destination.name`)
- Secret автоматически получает метку `argocd.argoproj.io/secret-type: cluster` через `destination.labels`
- Config должен быть в формате JSON строки (как в примере выше)
- Токен должен иметь достаточные права для доступа к API серверу dev кластера
- После обновления kubeconfig в Vault, VaultStaticSecret автоматически синхронизирует изменения (с интервалом `refreshAfter: 60s`)

**Диагностика, если кластер не отображается:**

```bash
# 1. Проверить статус VaultStaticSecret
kubectl get vaultstaticsecret dev-cluster-secret -n argocd
kubectl describe vaultstaticsecret dev-cluster-secret -n argocd

# Проверить события VaultStaticSecret
kubectl get events -n argocd --field-selector involvedObject.name=dev-cluster-secret

# 2. Проверить логи Vault Secrets Operator
kubectl logs -n vault-secrets-operator -l app.kubernetes.io/name=vault-secrets-operator --tail=50 | grep -i "dev-cluster\|argocd"

# 3. Проверить, что секрет существует в Vault
export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_TOKEN=$(cat /tmp/vault-root-token.txt)
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault kv get secret/argocd/dev-cluster
"

# 4. Проверить формат Secret
kubectl get secret dev-cluster -n argocd -o yaml

# Убедитесь, что Secret содержит:
# - name: dev-cluster (в data)
# - server: адрес API сервера dev кластера (в data)
# - config: JSON строка с bearerToken и tlsClientConfig (в data)
# - метка: argocd.argoproj.io/secret-type: cluster

# 5. Проверить декодированные значения
kubectl get secret dev-cluster -n argocd -o jsonpath='{.data.name}' | base64 -d && echo
kubectl get secret dev-cluster -n argocd -o jsonpath='{.data.server}' | base64 -d && echo
kubectl get secret dev-cluster -n argocd -o jsonpath='{.data.config}' | base64 -d | jq .

# 6. Проверить логи Argo CD Application Controller
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --tail=100 | grep -i "dev-cluster\|unmarshal\|cluster secret"
```

### Создание AppProject для организации Application

AppProject в Argo CD используются для организации Application и управления доступом к ресурсам. В инфраструктуре настроены два проекта:

1. **`dev-infrastructure`** — для инфраструктурных сервисов dev кластера (cert-manager, vault-secrets-operator, fluent-bit и т.д.)
2. **`dev-microservices`** — для микросервисов dev кластера (donweather-ms-weather, donweather-front и т.д.)

**Применение AppProject:**

```bash
# Переключиться на services кластер
export KUBECONFIG=$HOME/kubeconfig-services-cluster.yaml

# Применить AppProject
kubectl apply -f manifests/services/argocd/appprojects/

# Проверить создание проектов
kubectl get appproject -n argocd

# Проверить детали проектов
kubectl describe appproject dev-infrastructure -n argocd
kubectl describe appproject dev-microservices -n argocd
```

**Описание проектов:**

- **`dev-infrastructure`**: 
  - Разрешает репозитории: Helm charts (jetstack, hashicorp, fluent) и DonInfrastructure
  - Разрешает namespaces: `cert-manager`, `vault-secrets-operator`, `logging` в dev кластере
  - Роли: `infrastructure-admin` (группа `InfrastructureAdmins`), `infrastructure-operator` (группа `InfrastructureOperators`)

- **`dev-microservices`**:
  - Разрешает репозитории: DonWeather-* репозитории и DonInfrastructure
  - Разрешает namespaces: `donweather` и все остальные в dev кластере
  - Роли: `microservices-admin` (группа `MicroservicesAdmins`), `developer` (группа `Developers`), `operator` (группа `Operators`)

**Важно:**
- AppProject должны быть созданы **до** создания Application
- Все Application автоматически используют соответствующий проект (указан в поле `spec.project`)
- RBAC роли привязаны к группам из Keycloak (нужно создать соответствующие группы в Keycloak)

### Создание Argo CD Application для развертывания приложений

После добавления dev кластера в Argo CD и создания AppProject можно создавать Application для развертывания приложений в dev кластере.

**Важно:** Перед созданием Application убедитесь, что:
- Dev кластер добавлен в Argo CD и имеет статус "Connected"
- AppProject созданы (`dev-infrastructure` и `dev-microservices`)
- Git репозиторий с Helm chart приложения доступен
- Docker Registry credentials настроены в dev кластере (если используются приватные образы)

**Пример: Создание Application для donweather-ms-weather**

Создайте файл `manifests/services/argocd/applications/donweather/application-ms-weather.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: donweather-ms-weather-dev
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: dev-microservices
  
  source:
    repoURL: https://github.com/opusdvs/DonWeather-ms-weather.git
    targetRevision: dev
    path: .helm/donweather-ms-weather
    helm:
      valueFiles:
        - values.yaml
      # Переопределение значений через параметры (опционально)
      # values: |
      #   replicaCount: 2
      #   image:
      #     repository: buildbyte-container-registry.registry.twcstorage.ru/donweather-ms-weather
      #     tag: latest
  
  destination:
    name: dev-cluster
    namespace: donweather
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
      - PruneLast=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

**Применить Application:**

```bash
# Переключиться на services кластер
export KUBECONFIG=$HOME/kubeconfig-services-cluster.yaml

# Создать директорию для Application (если еще не создана)
mkdir -p manifests/services/argocd/applications/donweather

# Применить Application
kubectl apply -f manifests/services/argocd/applications/donweather/application-ms-weather.yaml

# Проверить статус Application
kubectl get application donweather-ms-weather-dev -n argocd
kubectl describe application donweather-ms-weather-dev -n argocd

# Проверить статус синхронизации
kubectl get application donweather-ms-weather-dev -n argocd -o jsonpath='{.status.sync.status}' && echo
kubectl get application donweather-ms-weather-dev -n argocd -o jsonpath='{.status.health.status}' && echo

# Проверить логи синхронизации
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --tail=50 | grep -i "donweather-ms-weather"
```

**Проверка Application в веб-интерфейсе Argo CD:**

1. Откройте Argo CD: `https://argo.buildbyte.ru`
2. Авторизуйтесь через Keycloak
3. Перейдите в раздел **Applications**
4. Должно отображаться приложение `donweather-ms-weather-dev`
5. Проверьте статус синхронизации и health статус

**Важно:**
- `destination.name: dev-cluster` указывает на кластер, добавленный в Argo CD
- `destination.namespace: donweather` - namespace в dev кластере, где будет развернуто приложение
- `syncPolicy.automated` включает автоматическую синхронизацию при изменениях в Git
- `syncOptions: CreateNamespace=true` автоматически создает namespace, если он не существует
- Если приложение использует приватные Docker образы, убедитесь, что Docker Registry credentials настроены в namespace `donweather` (см. раздел 12.6)

**Диагностика, если Application не синхронизируется:**

```bash
# 1. Проверить статус Application
kubectl get application donweather-ms-weather-dev -n argocd -o yaml

# 2. Проверить условия Application
kubectl get application donweather-ms-weather-dev -n argocd -o jsonpath='{.status.conditions}' | jq .

# 3. Проверить логи Argo CD Application Controller
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --tail=100 | grep -i "donweather-ms-weather"

# 4. Проверить доступность Git репозитория
# Убедитесь, что репозиторий доступен и содержит Helm chart по указанному пути

# 5. Проверить доступность dev кластера
kubectl get application donweather-ms-weather-dev -n argocd -o jsonpath='{.status.conditions[?(@.type=="ConnectionError")]}' | jq .

# 6. Проверить ресурсы в dev кластере
export KUBECONFIG=$HOME/kubeconfig-dev-cluster.yaml
kubectl get all -n donweather
```

### Настройка доступа к PostgreSQL из dev кластера

PostgreSQL находится в services кластере, но должен быть доступен для приложений в dev кластере. Для обеспечения доступа создайте LoadBalancer Service для PostgreSQL в services кластере:

```bash
# Переключиться на services кластер
export KUBECONFIG=$HOME/kubeconfig-services-cluster.yaml

# Создать LoadBalancer Service для PostgreSQL
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: postgresql-external
  namespace: postgresql
spec:
  type: LoadBalancer
  ports:
    - port: 5432
      targetPort: 5432
      protocol: TCP
      name: postgresql
  selector:
    app.kubernetes.io/name: postgresql
EOF

# Проверить создание Service
kubectl get svc postgresql-external -n postgresql

# Дождаться получения внешнего IP адреса
kubectl wait --for=jsonpath='{.status.loadBalancer.ingress[0].ip}' svc postgresql-external -n postgresql --timeout=300s

# Получить внешний IP адрес
POSTGRES_EXTERNAL_IP=$(kubectl get svc postgresql-external -n postgresql -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "PostgreSQL доступен по адресу: $POSTGRES_EXTERNAL_IP:5432"
```

**Использование внешнего адреса в приложении:**

В Helm chart приложения используйте внешний IP адрес вместо Service DNS:

```yaml
env:
  - name: DB_HOST
    value: "<ВНЕШНИЙ_IP_АДРЕС_POSTGRESQL>"
  - name: DB_PORT
    value: "5432"
```

**Важно:**
- Убедитесь, что firewall разрешает подключения к порту 5432 с IP адресов dev кластера
- Для production рекомендуется использовать VPN или приватную сеть вместо публичного LoadBalancer
- Рассмотрите использование TLS для шифрования соединения

#### Проверка подключения к PostgreSQL из dev кластера

После настройки доступа проверьте подключение:

```bash
# Переключиться на dev кластер
export KUBECONFIG=$HOME/kubeconfig-dev-cluster.yaml

# Получить внешний IP адрес PostgreSQL из services кластера
export KUBECONFIG=$HOME/kubeconfig-services-cluster.yaml
POSTGRES_EXTERNAL_IP=$(kubectl get svc postgresql-external -n postgresql -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Переключиться на dev кластер
export KUBECONFIG=$HOME/kubeconfig-dev-cluster.yaml

# Создать временный pod для проверки подключения
kubectl run postgresql-test --image=postgres:15 -n donweather --rm -it --restart=Never -- sh -c "
  PGHOST=$POSTGRES_EXTERNAL_IP
  PGPORT=5432
  PGUSER=ms_weather
  PGPASSWORD=\$(kubectl get secret ms-weather-postgresql-credentials -n donweather -o jsonpath='{.data.password}' | base64 -d)
  PGDATABASE=ms_weather
  psql -h \$PGHOST -p \$PGPORT -U \$PGUSER -d \$PGDATABASE -c 'SELECT version();'
"
```

**Важно:**
- Замените `$POSTGRES_EXTERNAL_IP` на реальный внешний IP адрес LoadBalancer Service
- Убедитесь, что LoadBalancer Service получил внешний IP адрес перед проверкой подключения

### Проверка установки

После выполнения всех шагов проверьте установку:

```bash
# 1. Проверить CSI драйвер
kubectl get pods -n kube-system | grep csi-driver
kubectl get storageclass

# 2. Проверить Gateway API
kubectl get pods -n nginx-gateway
kubectl get gatewayclass

# 3. Проверить Gateway
kubectl get gateway -n default
kubectl describe gateway dev-gateway -n default
kubectl get gateway dev-gateway -n default -o jsonpath='{.status.addresses[0].value}' && echo

# 4. Проверить cert-manager
kubectl get pods -n cert-manager
kubectl get crd | grep cert-manager

# 5. Проверить Vault Secrets Operator
kubectl get pods -n vault-secrets-operator
kubectl get clustersecretstore vault

# 6. Проверить namespaces
kubectl get namespaces
```

### Следующие шаги

После настройки dev кластера:

1. **Настроить доступ к кластеру для разработчиков**
2. **Настроить CI/CD интеграцию** (Jenkins для развертывания в dev кластер)
3. **Настроить Argo CD** для управления приложениями в dev кластере (из services кластера)
4. **Развернуть тестовые приложения** через Argo CD или Helm

## Полный чек-лист установки

### Services кластер (инфраструктурные компоненты)

- [ ] Services кластер Kubernetes развернут через Terraform (`terraform/services/`)
- [ ] `kubectl` настроен и подключен к Services кластеру
- [ ] Gateway API с NGINX Gateway Fabric установлен
- [ ] CSI драйвер Timeweb Cloud установлен и работает
- [ ] Vault установлен, инициализирован и разблокирован
- [ ] Vault Secrets Operator установлен и работает
- [ ] VaultConnection и VaultAuth для Vault настроены
- [ ] Kubernetes auth в Vault настроен для Vault Secrets Operator
- [ ] cert-manager установлен с поддержкой Gateway API
- [ ] Gateway создан (HTTP listener работает)
- [ ] ClusterIssuer создан и готов (Status: Ready)
- [ ] Certificate создан и Secret `gateway-tls-cert` существует
- [ ] HTTPS listener Gateway активирован (после создания Secret)
- [ ] Секреты PostgreSQL сохранены в Vault (путь: `secret/postgresql/admin` с ключами: `postgres_password`, `replication_password`)
- [ ] VaultStaticSecret `postgresql-admin-credentials` создан и синхронизирован
- [ ] Secret `postgresql-admin-credentials` создан Vault Secrets Operator
- [ ] PostgreSQL установлен через Helm Bitnami и доступен
- [ ] База данных `keycloak` и пользователь `keycloak` созданы вручную в PostgreSQL
- [ ] Credentials для Keycloak DB сохранены в Vault (путь: `secret/keycloak/database`)
- [ ] Admin credentials для Keycloak сохранены в Vault (путь: `secret/keycloak/admin`)
- [ ] VaultStaticSecret `keycloak-db-credentials` создан и синхронизирован в namespace `keycloak`
- [ ] VaultStaticSecret `keycloak-admin-credentials` создан и синхронизирован в namespace `keycloak`
- [ ] Secret `keycloak-db-credentials` создан Vault Secrets Operator
- [ ] Secret `keycloak-admin-credentials` создан Vault Secrets Operator
- [ ] Адрес PostgreSQL обновлен в `keycloak-instance.yaml`
- [ ] Keycloak Operator установлен и Keycloak инстанс готов
- [ ] Keycloak успешно подключен к PostgreSQL (проверено в логах)
- [ ] Argo CD установлен и сервисы готовы
- [ ] Клиент `argocd` создан в Keycloak с правильными redirect URIs
- [ ] Client Secret для Argo CD сохранен в Vault (путь: `secret/argocd/oidc` с ключом `client_secret`)
- [ ] VaultStaticSecret `argocd-oidc-secret` создан и синхронизирован в namespace `argocd`
- [ ] Ключ `oidc.keycloak.clientSecret` добавлен в секрет `argocd-secret` с реальным значением (не строка с `$`)
- [ ] Argo CD обновлен с OIDC конфигурацией
- [ ] OIDC аутентификация через Keycloak работает (проверено в браузере)
- [ ] RBAC настроен для использования групп из Keycloak (опционально)
- [ ] Jenkins установлен и сервисы готовы
- [ ] GitHub Personal Access Token создан в GitHub
- [ ] GitHub token сохранен в Vault (путь: `secret/jenkins/github` с ключом `token`)
- [ ] VaultStaticSecret `jenkins-github-token` создан и синхронизирован в namespace `jenkins`
- [ ] Secret `jenkins-github-token` создан Vault Secrets Operator с ключом `token`
- [ ] Jenkins обновлен с конфигурацией GitHub credentials через JCasC
- [ ] GitHub credentials доступны в Jenkins (ID: `github-token`)
- [ ] Admin credentials для Grafana сохранены в Vault (путь: `secret/grafana/admin`)
- [ ] VaultStaticSecret `grafana-admin-credentials` создан и синхронизирован в namespace `kube-prometheus-stack`
- [ ] Secret `grafana-admin` создан Vault Secrets Operator
- [ ] Prometheus Kube Stack установлен и сервисы готовы
- [ ] Клиент `grafana` создан в Keycloak с правильными redirect URIs
- [ ] Client Secret для Grafana сохранен в Vault (путь: `secret/grafana/oidc` с ключом `client_secret`)
- [ ] VaultStaticSecret `grafana-oidc-secret` создан и синхронизирован в namespace `kube-prometheus-stack`
- [ ] Secret `grafana-oidc-secret` создан Vault Secrets Operator с ключом `client_secret`
- [ ] Переменная окружения `GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET` установлена в поде Grafana (через `envValueFrom`)
- [ ] OIDC аутентификация через Keycloak работает в Grafana (проверено в браузере)
- [ ] RBAC настроен для использования групп из Keycloak (GrafanaAdmins → Admin, GrafanaEditors → Editor)
- [ ] Jaeger установлен и сервисы готовы
- [ ] HTTPRoute для Argo CD созданы и привязаны к Gateway
- [ ] HTTPRoute для Jenkins созданы и привязаны к Gateway
- [ ] HTTPRoute для Grafana созданы и привязаны к Gateway
- [ ] HTTPRoute для Keycloak созданы и привязаны к Gateway
- [ ] Keycloak настроен и доступен через HTTPS

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
# Grafana: https://grafana.buildbyte.ru
# Keycloak: https://keycloak.buildbyte.ru

# Проверить редиректы HTTP -> HTTPS
curl -I http://argo.buildbyte.ru  # Должен вернуть 301 на https://
curl -I http://jenkins.buildbyte.ru  # Должен вернуть 301 на https://
curl -I http://grafana.buildbyte.ru  # Должен вернуть 301 на https://
curl -I http://keycloak.buildbyte.ru  # Должен вернуть 301 на https://
```

## Дополнительная документация

- **Настройка Kubernetes Auth в Vault для Vault Secrets Operator:** см. раздел 8.1 в этом документе
- **Настройка Keycloak Authentication для Jenkins:** [`helm/services/jenkins/JENKINS_KEYCLOAK_SETUP.md`](helm/services/jenkins/JENKINS_KEYCLOAK_SETUP.md)

## Важные замечания

1. **Порядок установки критичен:**
   - **Vault должен быть установлен одним из первых** (для хранения секретов)
   - **Vault Secrets Operator должен быть установлен после Vault** (для синхронизации секретов)
   - **VaultConnection и VaultAuth должны быть настроены после Vault Secrets Operator** (для подключения к Vault)
   - **PostgreSQL должен быть установлен перед Keycloak** (Keycloak использует PostgreSQL в качестве базы данных)
   - **Loki должен быть установлен перед Prometheus Kube Stack** (Loki настроен как источник данных в Grafana через `additionalDataSources`)
   - Gateway должен быть создан перед ClusterIssuer (ClusterIssuer ссылается на Gateway для HTTP-01 challenge)
   - Приложения должны быть установлены перед созданием HTTPRoute (HTTPRoute ссылаются на их сервисы)
   - Secret для TLS создается cert-manager автоматически, но HTTPS listener не будет работать до его создания
   - Keycloak Operator требует установки CRDs перед установкой оператора
   - Vault использует file storage в standalone режиме, убедитесь, что CSI драйвер работает корректно
   - **Все секреты должны создаваться через Vault Secrets Operator (VaultStaticSecret)**, а не напрямую через `kubectl create secret`

2. **Зависимости компонентов:**
   - **Vault Secrets Operator** → требует **Vault** (для синхронизации секретов)
   - **VaultAuth** → требует **Vault**, **VaultConnection** и **Kubernetes auth в Vault** (для аутентификации)
   - **VaultStaticSecret** → требует **VaultAuth** и **секреты в Vault** (для синхронизации)
   - **PostgreSQL** → требует **секреты через Vault Secrets Operator** (для паролей администратора и репликации)
   - **Приложения** → требуют **секреты через Vault Secrets Operator** (Keycloak, Grafana и т.д.)
   - **Keycloak** → требует **PostgreSQL** (в качестве базы данных)
   - **Prometheus Kube Stack (Grafana)** → требует **Loki** (Loki настроен как источник данных в Grafana)
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
Vault Secrets Operator (синхронизирует секреты из Vault)
  ↓
VaultConnection + VaultAuth (настройка подключения)
  ↓
PostgreSQL (использует секреты из Vault Secrets Operator)
  ↓
Keycloak Operator → Keycloak (использует PostgreSQL и секреты из Vault Secrets Operator)
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
  - Jaeger
  ↓
HTTPRoute (ссылаются на Gateway и сервисы приложений)
```

**Важно:**
- **Vault** должен быть установлен до Vault Secrets Operator
- **Vault Secrets Operator** должен быть установлен до приложений, которые используют секреты
- Все секреты создаются через Vault Secrets Operator (VaultStaticSecret), который синхронизирует их из Vault
- Секреты для Keycloak, Grafana и других приложений должны быть сохранены в Vault перед установкой приложений

## Планы на будущее

1. **Написать модули для Terraform**
   - Создать переиспользуемые Terraform модули для стандартизации развертывания компонентов
   - Упростить конфигурацию и уменьшить дублирование кода
   - Обеспечить единообразие развертывания в разных окружениях

2. **Сделать кластеризацию PostgreSQL, Keycloak, Vault**
   - Настроить PostgreSQL в режиме высокой доступности (HA) с репликацией
   - Настроить Keycloak в кластерном режиме с несколькими инстансами
   - Настроить Vault в HA режиме с Raft storage backend и несколькими репликами
   - Обеспечить отказоустойчивость критических компонентов инфраструктуры

3. **Ввести разграничение по ролям Keycloak**
   - Настроить детальное разграничение доступа на основе ролей и групп в Keycloak
   - Реализовать RBAC для различных компонентов (Argo CD, Jenkins, Grafana)
   - Настроить политики доступа для разных команд и окружений

4. **Занести создание кластера в pipeline**
   - Автоматизировать развертывание Kubernetes кластеров через CI/CD pipeline
   - Интегрировать Terraform в процесс сборки и развертывания
   - Обеспечить автоматическое тестирование и валидацию конфигурации

5. **Настроить централизованное логирование**
   - Развернуть систему централизованного сбора логов (Loki, ELK Stack или аналоги)
   - Настроить сбор логов со всех компонентов инфраструктуры
   - Интегрировать логирование с Grafana для визуализации и анализа
   - Настроить ротацию и хранение логов

6. **Реализовать стратегию бэкапов**
   - Настроить автоматические бэкапы для PostgreSQL (базы данных Keycloak и других сервисов)
   - Настроить бэкапы для Vault (unseal keys, policies, secrets)
   - Настроить бэкапы для конфигураций Kubernetes (etcd, манифесты)
   - Реализовать процедуры восстановления из бэкапов
   - Настроить тестирование восстановления

7. **Настроить алертинг и мониторинг**
   - Настроить AlertManager для Prometheus
   - Создать правила алертинга для критических компонентов (Vault, PostgreSQL, Keycloak)
   - Настроить интеграцию с системами уведомлений (Slack, Email, PagerDuty)
   - Настроить мониторинг доступности сервисов и SLA

8. **Внедрить GitOps для всей инфраструктуры**
   - Настроить Argo CD для управления всей инфраструктурой через Git
   - Автоматизировать развертывание изменений через Git-коммиты
   - Настроить автоматическую синхронизацию конфигураций
   - Реализовать процесс code review для изменений инфраструктуры

9. **Усилить безопасность**
   - Внедрить Pod Security Standards для всех namespace
   - Настроить Network Policies для изоляции трафика между компонентами
   - Настроить OPA Gatekeeper или Kyverno для политик безопасности
   - Реализовать сканирование образов контейнеров на уязвимости
   - Настроить регулярное обновление компонентов и патчей безопасности

10. **Оптимизировать использование ресурсов**
    - Настроить Horizontal Pod Autoscaler (HPA) для автоматического масштабирования
    - Настроить Vertical Pod Autoscaler (VPA) для оптимизации запросов ресурсов
    - Провести аудит использования ресурсов и оптимизацию
    - Настроить лимиты и квоты для namespace

11. **Настроить Jenkins через JCasC (Jenkins Configuration as Code)**
    - Перенести все настройки Jenkins из init scripts в JCasC конфигурацию
    - Настроить security realm, authorization strategy и другие компоненты через JCasC
    - Обеспечить полное управление конфигурацией Jenkins через код
    - Упростить процесс обновления и версионирования конфигурации Jenkins
