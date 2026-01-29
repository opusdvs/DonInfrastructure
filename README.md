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
- API Token должен быть сохранен в Vault в поле `api_token` (см. инструкцию в разделе 10.6)

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


### 3. Установка CSI драйвера в панели Timeweb Cloud

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

### 4. Установка Vault через Helm

**Важно:** Vault должен быть установлен одним из первых, так как он используется для хранения секретов, которые будут синхронизироваться через Vault Secrets Operator.

Vault устанавливается через официальный Helm chart от HashiCorp.

#### 4.1. Установка Vault

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

#### 4.2. Инициализация и разблокировка Vault

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

### 5. Установка Vault Secrets Operator

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

#### 5.1. Настройка Kubernetes Auth в Vault для Vault Secrets Operator

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

#### 5.2. Проверка VaultConnection и VaultAuth

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
- Kubernetes auth в Vault должен быть настроен перед использованием VaultAuth (см. раздел 5.1)
- Роль `vault-secrets-operator` в Vault должна иметь доступ к путям секретов, которые будут использоваться
- Default VaultConnection использует адрес `http://vault.vault.svc.cluster.local:8200`
- Default VaultAuth разрешает использование из всех namespace (`allowedNamespaces: ["*"]`)
- После настройки VaultAuth можно создавать VaultStaticSecret ресурсы для синхронизации секретов

#### 5.3. Пример использования VaultStaticSecret

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

### 6. Установка PostgreSQL

**Важно:** PostgreSQL должен быть установлен перед Keycloak, так как Keycloak использует PostgreSQL в качестве базы данных.

#### 6.1. Создание секретов в Vault для PostgreSQL

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
# ВАЖНО: Замените <ВАШ_ПАРОЛЬ_POSTGRES> и <ВАШ_ПАРОЛЬ_REPLICATION> на реальные пароли
# Используйте одинарные кавычки для паролей, чтобы избежать проблем с специальными символами
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

# Сохранить секреты для Keycloak (будет использоваться позже)
# Замените <ВАШ_ПАРОЛЬ_KEYCLOAK> на безопасный пароль для пользователя keycloak
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault kv put secret/keycloak/postgresql \
  username=keycloak \
  password='<ВАШ_ПАРОЛЬ_KEYCLOAK>' \
  database=keycloak
"

# Сохранить credentials администратора Keycloak
# Замените <ВАШ_ИМЯ_АДМИНИСТРАТОРА> и <ВАШ_ПАРОЛЬ_АДМИНИСТРАТОРА> на реальные значения
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault kv put secret/keycloak/admin \
  username='<ВАШ_ИМЯ_АДМИНИСТРАТОРА>' \
  password='<ВАШ_ПАРОЛЬ_АДМИНИСТРАТОРА>'
"
```

**Важно:**
- Используйте надежные пароли для production окружения
- Пароли должны быть достаточно длинными (минимум 16 символов)
- Сохраните пароли в безопасном месте (например, в менеджере паролей)

#### 6.2. Создание VaultStaticSecret для PostgreSQL

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

#### 6.3. Установка PostgreSQL через Helm Bitnami

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

#### 6.4. Создание базы данных и пользователя для Keycloak

После установки PostgreSQL создайте базу данных и пользователя для Keycloak:

```bash
# Получить имя pod PostgreSQL
POSTGRES_POD=$(kubectl get pods -n postgresql -l app.kubernetes.io/name=postgresql -o jsonpath='{.items[0].metadata.name}')

# Получить пароль администратора PostgreSQL из Secret
POSTGRES_PASSWORD=$(kubectl get secret postgresql-admin-credentials -n postgresql -o jsonpath='{.data.postgres_password}' | base64 -d)

# Получить пароль для Keycloak из Vault
export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_TOKEN=$(cat /tmp/vault-root-token.txt)
KEYCLOAK_PASSWORD=$(kubectl exec vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault kv get -field=password secret/keycloak/postgresql
")

# Создать базу данных и пользователя
# Используем PGPASSWORD для аутентификации через sh -c для корректной передачи переменной
kubectl exec $POSTGRES_POD -n postgresql -- sh -c "PGPASSWORD='$POSTGRES_PASSWORD' psql -U postgres -c 'CREATE DATABASE keycloak;'"

kubectl exec $POSTGRES_POD -n postgresql -- sh -c "PGPASSWORD='$POSTGRES_PASSWORD' psql -U postgres -c \"CREATE USER keycloak WITH PASSWORD '${KEYCLOAK_PASSWORD}';\""

kubectl exec $POSTGRES_POD -n postgresql -- sh -c "PGPASSWORD='$POSTGRES_PASSWORD' psql -U postgres -c 'GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak;'"

kubectl exec $POSTGRES_POD -n postgresql -- sh -c "PGPASSWORD='$POSTGRES_PASSWORD' psql -U postgres -d keycloak -c 'GRANT ALL ON SCHEMA public TO keycloak;'"
```

**Проверка создания базы данных:**
```bash
# Получить имя pod PostgreSQL
POSTGRES_POD=$(kubectl get pods -n postgresql -l app.kubernetes.io/name=postgresql -o jsonpath='{.items[0].metadata.name}')

# Получить пароль администратора PostgreSQL из Secret
POSTGRES_PASSWORD=$(kubectl get secret postgresql-admin-credentials -n postgresql -o jsonpath='{.data.postgres_password}' | base64 -d)

# Проверить создание базы данных
kubectl exec $POSTGRES_POD -n postgresql -- sh -c "PGPASSWORD='$POSTGRES_PASSWORD' psql -U postgres -c '\l'" | grep keycloak

# Проверить создание пользователя
kubectl exec $POSTGRES_POD -n postgresql -- sh -c "PGPASSWORD='$POSTGRES_PASSWORD' psql -U postgres -c '\du'" | grep keycloak
```

**Важно:**
- Адрес PostgreSQL для Keycloak: `postgresql.postgresql.svc.cluster.local:5432`
- База данных: `keycloak`
- Пользователь: `keycloak`
- Пароль: из Secret `postgresql-keycloak-credentials` (синхронизируется из Vault)

### 7. Установка Keycloak Operator

#### 7.1. Установка оператора

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

#### 7.2. Подготовка PostgreSQL для Keycloak

Keycloak настроен для использования внешнего PostgreSQL. База данных и пользователь для Keycloak уже созданы в разделе 6.4.

**Адрес PostgreSQL для Keycloak:**
- Host: `postgresql.postgresql.svc.cluster.local`
- Port: `5432`
- Database: `keycloak`
- Username: `keycloak`
- Password: из Secret `postgresql-keycloak-credentials` (синхронизируется из Vault по пути `secret/keycloak/postgresql`)

```bash
# Проверить доступность PostgreSQL
kubectl get svc -n postgresql
```

**Шаг 2: Обновить конфигурацию Keycloak**

Откройте `manifests/services/keycloak/keycloak-instance.yaml` и обновите адрес PostgreSQL:

```yaml
database:
  host: postgresql.postgresql.svc.cluster.local  # Замените на ваш адрес PostgreSQL
```

**Шаг 3: Создать VaultStaticSecret для PostgreSQL credentials в namespace keycloak**

Секреты PostgreSQL для Keycloak должны быть созданы в namespace `keycloak`, где будет развернут Keycloak:

```bash
# Создать namespace для Keycloak (если еще не создан)
kubectl create namespace keycloak --dry-run=client -o yaml | kubectl apply -f -

# Создать VaultStaticSecret для синхронизации секретов PostgreSQL из Vault
cat <<EOF | kubectl apply -f -
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  name: postgresql-keycloak-credentials
  namespace: keycloak
spec:
  vaultAuthRef: vault-secrets-operator/default
  mount: secret
  type: kv-v2
  path: keycloak/postgresql
  refreshAfter: 60s
  destination:
    name: postgresql-keycloak-credentials
    create: true
EOF

# Создать VaultStaticSecret для синхронизации admin credentials из Vault
cat <<EOF | kubectl apply -f -
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  name: keycloak-admin-credentials
  namespace: keycloak
spec:
  vaultAuthRef: vault-secrets-operator/default
  mount: secret
  type: kv-v2
  path: keycloak/admin
  refreshAfter: 60s
  destination:
    name: keycloak-admin-credentials
    create: true
EOF

# Проверить синхронизацию секретов
kubectl get vaultstaticsecret -n keycloak
kubectl get secret postgresql-keycloak-credentials -n keycloak
kubectl get secret keycloak-admin-credentials -n keycloak
```

**Примечание:** Секреты PostgreSQL и admin credentials для Keycloak уже сохранены в Vault в разделе 6.1. Здесь мы создаем VaultStaticSecret в namespace `keycloak` для синхронизации этих секретов.

#### 7.3. Создание Keycloak инстанса

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

### 8. Установка cert-manager

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

### 9. Создание Gateway

```bash
# 1. Применить Gateway
kubectl apply -f manifests/services/gateway/gateway.yaml

# 2. Проверить статус Gateway
kubectl get gateway -n default
kubectl describe gateway service-gateway -n default
```

**Примечание:** 
- HTTP listener будет работать сразу после создания Gateway
- HTTPS listener не будет работать до создания Secret `gateway-tls-cert` (это будет сделано на шаге 7)
- Gateway должен быть создан перед ClusterIssuer, так как ClusterIssuer ссылается на Gateway для HTTP-01 challenge


### 10. Создание ClusterIssuer и сертификата

```bash
# 1. Применить ClusterIssuer (отредактируйте email перед применением!)
# ВАЖНО: Gateway должен быть создан, так как ClusterIssuer ссылается на него для HTTP-01 challenge
kubectl apply -f manifests/services/cert-manager/cluster-issuer.yaml

# 2. Проверить ClusterIssuer
kubectl get clusterissuer
kubectl describe clusterissuer letsencrypt-prod

# 3. Применить Certificate
kubectl apply -f manifests/services/cert-manager/gateway-certificate.yaml

# 4. Проверить статус Certificate
kubectl get certificate -n default
kubectl describe certificate gateway-tls-cert -n default

# 5. Дождаться создания Secret (может занять несколько минут)
# Cert-manager автоматически создаст Secret gateway-tls-cert после успешной выдачи сертификата
watch kubectl get secret gateway-tls-cert -n default
```

**Важно:** 
- Замените `admin@buildbyte.ru` на ваш реальный email в `manifests/services/cert-manager/cluster-issuer.yaml`
- Gateway должен быть создан до ClusterIssuer, так как ClusterIssuer использует Gateway для HTTP-01 challenge
- После создания Secret `gateway-tls-cert`, HTTPS listener Gateway автоматически активируется
- Certificate уже содержит все hostnames: `argo.buildbyte.ru`, `jenkins.buildbyte.ru`, `grafana.buildbyte.ru`, `keycloak.buildbyte.ru`
- При добавлении новых приложений обновите `dnsNames` в `manifests/services/cert-manager/gateway-certificate.yaml` и пересоздайте Certificate

### 11. Установка Jenkins и Argo CD

**Важно:** Установите приложения ПЕРЕД созданием HTTPRoute, так как HTTPRoute ссылаются на сервисы этих приложений.

#### 10.1. Сохранение секретов администраторов в Vault

Перед установкой Argo CD и Jenkins сохраните пароли администраторов в Vault:

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

# Сохранить credentials администратора Jenkins
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault kv put secret/jenkins/admin username='admin' password='<ВАШ_ПАРОЛЬ>'
"

# Сохранить credentials администратора Grafana
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault kv put secret/grafana/admin \
  admin_user='admin' \
  admin_password='<ВАШ_ПАРОЛЬ>'
"
```

**Важно для Argo CD:**
- Пароль должен быть bcrypt хешированным
- Используйте команду: `htpasswd -nbBC 10 "" <пароль> | tr -d ':\n' | sed 's/$2y/$2a/'`
- Сохраните хеш в Vault по пути `secret/argocd/admin` с ключом `password`

#### 10.2. Создание VaultStaticSecret для синхронизации секретов

```bash
# Создать namespace для Argo CD и Jenkins (если еще не созданы)
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace jenkins --dry-run=client -o yaml | kubectl apply -f -

# Создать VaultStaticSecret для Argo CD
cat <<EOF | kubectl apply -f -
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  name: argocd-admin-credentials
  namespace: argocd
spec:
  vaultAuthRef: vault-secrets-operator/default
  mount: secret
  type: kv-v2
  path: argocd/admin
  refreshAfter: 60s
  destination:
    name: argocd-initial-admin-secret
    create: true
EOF

# Создать VaultStaticSecret для Jenkins
cat <<EOF | kubectl apply -f -
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  name: jenkins-admin-credentials
  namespace: jenkins
spec:
  vaultAuthRef: vault-secrets-operator/default
  mount: secret
  type: kv-v2
  path: jenkins/admin
  refreshAfter: 60s
  destination:
    name: jenkins-admin-credentials
    create: true
EOF

# Создать VaultStaticSecret для Grafana (будет использоваться при установке Prometheus Kube Stack)
kubectl create namespace kube-prometheus-stack --dry-run=client -o yaml | kubectl apply -f -
cat <<EOF | kubectl apply -f -
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  name: grafana-admin-credentials
  namespace: kube-prometheus-stack
spec:
  vaultAuthRef: vault-secrets-operator/default
  mount: secret
  type: kv-v2
  path: grafana/admin
  refreshAfter: 60s
  destination:
    name: grafana-admin
    create: true
EOF

# Проверить синхронизацию секретов
kubectl get vaultstaticsecret -n argocd
kubectl get vaultstaticsecret -n jenkins
kubectl get vaultstaticsecret -n kube-prometheus-stack
kubectl get secret argocd-initial-admin-secret -n argocd
kubectl get secret jenkins-admin-credentials -n jenkins
kubectl get secret grafana-admin -n kube-prometheus-stack
```

#### 10.3. Установка Argo CD и Jenkins

```bash
# 1. Добавить Helm репозитории
helm repo add argo https://argoproj.github.io/argo-helm
helm repo add jenkins https://charts.jenkins.io
helm repo update

# 2. Установить Argo CD с использованием существующего секрета
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  -f helm/services/argocd/argocd-values.yaml \
  --set configs.secret.argocdServerAdminPassword="$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d)"

# 3. Установить Jenkins (admin credentials уже настроены в helm/services/jenkins/jenkins-values.yaml)
helm upgrade --install jenkins jenkins/jenkins \
  --namespace jenkins \
  --create-namespace \
  -f helm/services/jenkins/jenkins-values.yaml

# 4. Проверить установку
kubectl get pods -n argocd
kubectl get pods -n jenkins

# 5. Дождаться готовности сервисов
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=jenkins-controller -n jenkins --timeout=300s
```

**Получение паролей:**
```bash
# Пароль администратора Argo CD (из Vault через VaultStaticSecret)
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d | echo
# Примечание: Это bcrypt хеш, для использования нужно знать исходный пароль

# Пароль администратора Jenkins (из Vault через VaultStaticSecret)
kubectl get secret jenkins-admin-credentials -n jenkins -o jsonpath='{.data.jenkins-admin-password}' | base64 -d && echo
```

#### 10.4. Настройка OIDC для Argo CD через Keycloak

**Важно:** Перед настройкой OIDC убедитесь, что:
- Keycloak установлен и доступен по адресу `https://keycloak.buildbyte.ru`
- В Keycloak создан клиент `argocd` с правильными redirect URIs
- Получен Client Secret для клиента `argocd`

**Шаг 1: Создать клиент в Keycloak**

1. Войдите в Keycloak Admin Console: `https://keycloak.buildbyte.ru/admin`
2. Выберите Realm (например, `master`)
3. Перейдите в **Clients** → **Create client**
4. Настройте клиент:
   - **Client ID:** `argocd`
   - **Client protocol:** `openid-connect`
   - **Access Type:** `confidential`
   - **Valid Redirect URIs:** 
     - `https://argo.buildbyte.ru/api/dex/callback`
     - `https://argo.buildbyte.ru/auth/callback`
   - **Web Origins:** `https://argo.buildbyte.ru`
5. Сохраните клиент и перейдите на вкладку **Credentials**
6. Скопируйте **Secret** (Client Secret)

**Шаг 2: Сохранить Client Secret в Vault**

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

# Сохранить Client Secret для Argo CD OIDC
# Замените <ВАШ_CLIENT_SECRET> на реальный Client Secret из Keycloak
# ВАЖНО: Используйте нижнее подчеркивание в ключе (client_secret), а не дефис
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault kv put secret/argocd/oidc \
  client_secret='<ВАШ_CLIENT_SECRET>'
"

# Проверить, что секрет сохранен правильно
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault kv get secret/argocd/oidc
"
```

**Шаг 3: Создать VaultStaticSecret для синхронизации Client Secret**

VaultStaticSecret синхронизирует Client Secret из Vault в отдельный секрет `argocd-oidc-secret`, который используется Argo CD для OIDC аутентификации.

```bash
# Создать VaultStaticSecret для синхронизации OIDC client-secret
cat <<EOF | kubectl apply -f -
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  name: argocd-oidc-secret
  namespace: argocd
spec:
  vaultAuthRef: vault-secrets-operator/default
  mount: secret
  type: kv-v2
  path: argocd/oidc
  refreshAfter: 60s
  destination:
    name: argocd-oidc-secret
    create: true
EOF

# Проверить статус VaultStaticSecret
kubectl get vaultstaticsecret argocd-oidc-secret -n argocd
kubectl describe vaultstaticsecret argocd-oidc-secret -n argocd

# Проверить созданный Secret
kubectl get secret argocd-oidc-secret -n argocd

# Проверить значение Client Secret (должно быть реальное значение)
kubectl get secret argocd-oidc-secret -n argocd -o jsonpath='{.data.client_secret}' | base64 -d && echo

# Если синхронизация не прошла, проверьте логи Vault Secrets Operator:
kubectl logs -n vault-secrets-operator -l app.kubernetes.io/name=vault-secrets-operator --tail=50 | grep -i argocd
```

**Важно:**
- VaultStaticSecret создает отдельный секрет `argocd-oidc-secret` с ключом `client_secret`
- Ключ `client_secret` должен содержать реальное значение Client Secret из Keycloak
- Если синхронизация не прошла, проверьте:
  - Существует ли секрет в Vault по пути `secret/argocd/oidc` с ключом `client_secret`
  - Настроен ли VaultAuth для Vault Secrets Operator
  - Работает ли Vault Secrets Operator

**Шаг 4: Обновить Argo CD с OIDC конфигурацией**

OIDC конфигурация уже настроена в `helm/services/argocd/argocd-values.yaml`. Обновите Argo CD:

```bash
# Обновить Argo CD с OIDC конфигурацией
helm upgrade argocd argo/argo-cd \
  --namespace argocd \
  -f helm/services/argocd/argocd-values.yaml \
  --set configs.secret.argocdServerAdminPassword="$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d)"

# Проверить, что Argo CD перезапустился
kubectl get pods -n argocd
kubectl logs -f deployment/argocd-server -n argocd | grep -i oidc
```

**Шаг 5: Настроить RBAC в Argo CD**

RBAC уже настроен в `helm/services/argocd/argocd-values.yaml`. Группа `ArgoCDAdmins` из Keycloak привязана к встроенной роли `role:admin`, которая дает полные права администратора в Argo CD.

Текущая конфигурация:
```yaml
configs:
  rbac:
    # Настройка RBAC на основе групп из Keycloak
    # Группа ArgoCDAdmins должна быть создана в Keycloak
    policy.csv: |
      # Привязать группу ArgoCDAdmins из Keycloak к встроенной роли admin
      # Роль admin дает полные права администратора в Argo CD
      g, "ArgoCDAdmins", role:admin
```

**Важно:**
- Группа `ArgoCDAdmins` должна быть создана в Keycloak
- Пользователи должны быть добавлены в эту группу
- Встроенная роль `role:admin` предоставляет все административные права в Argo CD
- Если нужно добавить другие группы или роли, отредактируйте `policy.csv` в `helm/services/argocd/argocd-values.yaml`

**Проверка OIDC:**

1. Откройте Argo CD: `https://argo.buildbyte.ru`
2. Должна появиться кнопка **"LOG IN VIA KEYCLOAK"** или **"LOG IN VIA OIDC"**
3. Выполните вход через Keycloak
4. Проверьте, что пользователь успешно аутентифицирован

**Важно:**
- OIDC конфигурация использует Realm `services` по умолчанию (настроено в `helm/services/argocd/argocd-values.yaml`). Если используется другой Realm, измените `issuer` в `helm/services/argocd/argocd-values.yaml`
- Client Secret синхронизируется из Vault через Vault Secrets Operator в секрет `argocd-oidc-secret`
- RBAC настраивается на основе групп из Keycloak через `policy.csv`
- **При ошибке "unauthorized_client":** см. инструкции по устранению неполадок в `helm/services/argocd/OIDC_TROUBLESHOOTING.md`

#### 10.5. Настройка GitHub API Token для Jenkins

**Важно:** Перед настройкой GitHub token убедитесь, что:
- Jenkins установлен и работает
- Vault Secrets Operator установлен и работает
- VaultAuth для Vault Secrets Operator настроен

**Шаг 1: Создать Personal Access Token в GitHub**

1. Перейдите в GitHub: **Settings** → **Developer settings** → **Personal access tokens** → **Tokens (classic)**
2. Нажмите **"Generate new token (classic)"**
3. Укажите **Note** (описание токена, например, "Jenkins CI/CD")
4. Выберите **scopes** (права доступа):
   - Для публичных репозиториев: `public_repo`
   - Для приватных репозиториев: `repo` (полный доступ к репозиториям)
   - Для работы с webhooks: `admin:repo_hook` (опционально)
5. Нажмите **"Generate token"**
6. Скопируйте токен (он показывается только один раз!)

**Шаг 2: Сохранить GitHub Token в Vault**

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

# Сохранить GitHub Personal Access Token
# Замените <ВАШ_GITHUB_TOKEN> на реальный токен из GitHub
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault kv put secret/jenkins/github \
  token='<ВАШ_GITHUB_TOKEN>'
"

# Проверить, что секрет сохранен правильно
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault kv get secret/jenkins/github
"
```

**Шаг 3: Создать VaultStaticSecret для синхронизации GitHub Token**

```bash
# Создать VaultStaticSecret для синхронизации GitHub token
cat <<EOF | kubectl apply -f -
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  name: jenkins-github-token
  namespace: jenkins
spec:
  vaultAuthRef: vault-secrets-operator/default
  mount: secret
  type: kv-v2
  path: jenkins/github
  refreshAfter: 60s
  destination:
    name: jenkins-github-token
    create: true
EOF

# Проверить статус VaultStaticSecret
kubectl get vaultstaticsecret jenkins-github-token -n jenkins
kubectl describe vaultstaticsecret jenkins-github-token -n jenkins

# Проверить созданный Secret
kubectl get secret jenkins-github-token -n jenkins

# Проверить значение токена (должно быть реальное значение)
kubectl get secret jenkins-github-token -n jenkins -o jsonpath='{.data.token}' | base64 -d && echo
```

**Шаг 4: Обновить Jenkins с конфигурацией GitHub credentials**

GitHub credentials уже настроены в `helm/services/jenkins/jenkins-values.yaml` через JCasC. Обновите Jenkins:

```bash
# Обновить Jenkins с новой конфигурацией
helm upgrade jenkins jenkins/jenkins \
  --namespace jenkins \
  -f helm/services/jenkins/jenkins-values.yaml

# Проверить, что Jenkins перезапустился
kubectl get pods -n jenkins
kubectl logs -f deployment/jenkins -n jenkins | grep -i "github\|credentials"
```

**Проверка GitHub credentials в Jenkins:**

1. Откройте Jenkins: `https://jenkins.buildbyte.ru`
2. Перейдите в **Manage Jenkins** → **Credentials** → **System** → **Global credentials**
3. Должен быть создан credential с ID `github-token` типа "Secret text"
4. Этот credential можно использовать в Pipeline jobs для доступа к GitHub репозиториям

#### 10.6. Настройка Docker Registry для Jenkins

**Важно:** Перед настройкой Docker Registry убедитесь, что:
- Docker Registry создан в панели управления облака (см. раздел "Создание Docker Registry в панели управления облака")
- Jenkins установлен и работает
- Vault Secrets Operator установлен и работает
- VaultAuth для Vault Secrets Operator настроен

**Примечание:** Для Timeweb Container Registry используется **API Token** вместо пароля. В Vault credentials сохраняются с полем `api_token`, которое затем используется как `password` в Jenkins credentials для совместимости с Docker login.

**Шаг 1: Сохранить Docker Registry credentials в Vault**

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

# Сохранить Docker Registry credentials
# Для Timeweb Container Registry используется api_token вместо password
# Данные для buildbyte-container-registry:
#   Домен: buildbyte-container-registry.registry.twcstorage.ru
#   Username: buildbyte-container-registry
#   API Token: (сохраняется в поле api_token)
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault kv put secret/jenkins/docker-registry \
  username='buildbyte-container-registry' \
  api_token='<ВАШ_API_TOKEN>'
"

# Проверить, что секрет сохранен правильно
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault kv get secret/jenkins/docker-registry
"
```

**Шаг 2: Создать VaultStaticSecret для синхронизации Docker Registry credentials**

```bash
# Создать VaultStaticSecret для синхронизации Docker Registry credentials
cat <<EOF | kubectl apply -f -
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  name: jenkins-docker-registry
  namespace: jenkins
spec:
  vaultAuthRef: vault-secrets-operator/default
  mount: secret
  type: kv-v2
  path: jenkins/docker-registry
  refreshAfter: 60s
  destination:
    name: jenkins-docker-registry
    create: true
EOF

# Проверить статус VaultStaticSecret
kubectl get vaultstaticsecret jenkins-docker-registry -n jenkins
kubectl describe vaultstaticsecret jenkins-docker-registry -n jenkins

# Дождаться синхронизации (может занять несколько секунд)
kubectl wait --for=condition=Ready externalsecret jenkins-docker-registry -n jenkins --timeout=60s

# Проверить созданный Secret
kubectl get secret jenkins-docker-registry -n jenkins

# Проверить значения credentials (должны быть реальные значения, а не строки с $)
kubectl get secret jenkins-docker-registry -n jenkins -o jsonpath='{.data.username}' | base64 -d && echo
kubectl get secret jenkins-docker-registry -n jenkins -o jsonpath='{.data.password}' | base64 -d && echo
```

**Шаг 3: Обновить Jenkins с конфигурацией Docker Registry credentials**

Docker Registry credentials уже настроены в `helm/services/jenkins/jenkins-values.yaml` через JCasC. Обновите Jenkins:

```bash
# Обновить Jenkins с новой конфигурацией
helm upgrade jenkins jenkins/jenkins \
  --namespace jenkins \
  -f helm/services/jenkins/jenkins-values.yaml

# Проверить, что Jenkins перезапустился
kubectl get pods -n jenkins
kubectl logs -f deployment/jenkins -n jenkins | grep -i "docker\|credentials"
```

**Проверка Docker Registry credentials в Jenkins:**

1. Откройте Jenkins: `https://jenkins.buildbyte.ru`
2. Перейдите в **Manage Jenkins** → **Credentials** → **System** → **Global credentials**
3. Должен быть создан credential с ID `docker-registry` типа "Username with password"
4. Этот credential можно использовать в Pipeline jobs для доступа к приватному Docker Registry

**Использование Docker Registry credentials в Pipeline:**

```groovy
pipeline {
    agent any
    
    stages {
        stage('Build and Push') {
            steps {
                script {
                    // Использование Docker registry credentials
                    withCredentials([usernamePassword(
                        credentialsId: 'docker-registry',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )]) {
                        sh '''
                            docker login -u $DOCKER_USER -p $DOCKER_PASS buildbyte-container-registry.registry.twcstorage.ru
                            docker build -t buildbyte-container-registry.registry.twcstorage.ru/image:tag .
                            docker push buildbyte-container-registry.registry.twcstorage.ru/image:tag
                        '''
                    }
                }
            }
        }
    }
}
```

Или используйте встроенные шаги Docker Pipeline:

```groovy
pipeline {
    agent any
    
    stages {
        stage('Build and Push') {
            steps {
                script {
                    docker.withRegistry('https://buildbyte-container-registry.registry.twcstorage.ru', 'docker-registry') {
                        def image = docker.build('buildbyte-container-registry.registry.twcstorage.ru/image:tag')
                        image.push()
                    }
                }
            }
        }
    }
}
```

**Важно:**
- GitHub token синхронизируется из Vault через Vault Secrets Operator в секрет `jenkins-github-token`
- Секрет монтируется в Jenkins через `additionalExistingSecrets` и используется в JCasC через переменную `${jenkins-github-token-token}`
- GitHub credentials автоматически создаются в Jenkins через JCasC с ID `github-token`
- Для использования в Pipeline jobs укажите `credentialsId: "github-token"` в конфигурации SCM

#### 10.7. Добавление Docker Registry credentials для Kubernetes (ImagePullSecrets)

Docker Registry credentials могут использоваться не только в Jenkins, но и в Kubernetes для доступа к приватным образам из подов. Это полезно для:
- Pull образов из приватного Docker Registry в поды
- Использования в Argo CD для развертывания приложений с приватными образами
- Использования в других компонентах, которым нужен доступ к приватному registry

**Важно:** Перед настройкой Docker Registry credentials убедитесь, что:
- Docker Registry создан в панели управления облака (см. раздел "Создание Docker Registry в панели управления облака")
- Dev кластер развернут и настроен
- Vault Secrets Operator установлен и работает в dev кластере
- VaultAuth для Vault Secrets Operator настроен в dev кластере (см. раздел "Шаг 6: Установка и настройка Vault Secrets Operator для работы с внешним Vault")

**Шаг 1: Создать и сохранить .dockerconfigjson в Vault**

Для Kubernetes ImagePullSecrets требуется Secret типа `kubernetes.io/dockerconfigjson` с готовым JSON. Создайте и сохраните его в Vault:

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

# Создать .dockerconfigjson
# Для Timeweb Container Registry используется API Token вместо пароля
DOCKER_USERNAME="buildbyte-container-registry"
DOCKER_PASSWORD="<ВАШ_API_TOKEN>"
DOCKER_REGISTRY="buildbyte-container-registry.registry.twcstorage.ru"

# Создать base64 encoded auth string
AUTH_STRING=$(echo -n "$DOCKER_USERNAME:$DOCKER_PASSWORD" | base64 -w 0)

# Создать .dockerconfigjson в формате JSON
DOCKERCONFIGJSON=$(cat <<EOF | jq -c .
{
  "auths": {
    "$DOCKER_REGISTRY": {
      "username": "$DOCKER_USERNAME",
      "password": "$DOCKER_PASSWORD",
      "auth": "$AUTH_STRING"
    }
  }
}
EOF
)

# Сохранить в Vault
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault kv put secret/kubernetes/docker-registry \
  dockerconfigjson='$DOCKERCONFIGJSON'
"

# Проверить, что секрет сохранен правильно
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault kv get secret/kubernetes/docker-registry
"
```

**Шаг 2: Создать VaultStaticSecret для синхронизации Docker Registry credentials**

**Важно:** VaultStaticSecret создается в dev кластере, так как Docker Registry credentials нужны для pull образов в dev кластере, где развертываются приложения.

```bash
# Переключиться на dev кластер
export KUBECONFIG=$HOME/kubeconfig-dev-cluster.yaml

# Создать VaultStaticSecret для Docker Registry credentials
cat <<EOF | kubectl apply -f -
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  name: docker-registry-credentials
  namespace: default
  labels:
    app: docker-registry
    component: credentials
spec:
  vaultAuthRef: vault-secrets-operator/default
  mount: secret
  type: kv-v2
  path: kubernetes/docker-registry
  refreshAfter: 60s
  destination:
    name: docker-registry-credentials
    create: true
    type: kubernetes.io/dockerconfigjson
    transformation:
      templates:
        .dockerconfigjson:
          text: '{{ .Secrets.dockerconfigjson }}'
EOF

# Проверить статус VaultStaticSecret
kubectl get vaultstaticsecret docker-registry-credentials -n default
kubectl describe vaultstaticsecret docker-registry-credentials -n default

# Проверить созданный Secret
kubectl get secret docker-registry-credentials -n default
kubectl describe secret docker-registry-credentials -n default

# Проверить тип Secret (должен быть kubernetes.io/dockerconfigjson)
kubectl get secret docker-registry-credentials -n default -o jsonpath='{.type}' && echo

# Проверить содержимое .dockerconfigjson (должно быть валидным JSON)
kubectl get secret docker-registry-credentials -n default -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | jq .
```

**Шаг 4: Использование ImagePullSecrets в подах**

После создания Secret можно использовать его в подах через `imagePullSecrets`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
  namespace: default
spec:
  imagePullSecrets:
    - name: docker-registry-credentials
  containers:
    - name: my-app
      image: buildbyte-container-registry.registry.twcstorage.ru/my-app:latest
      # ...
```

Или добавить ImagePullSecret на уровне ServiceAccount:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-service-account
  namespace: default
imagePullSecrets:
  - name: docker-registry-credentials
```

**Использование в Argo CD:**

Для использования Docker Registry credentials в Argo CD приложениях:

1. VaultStaticSecret уже создан в dev кластере (см. Шаг 2)
2. Secret `docker-registry-credentials` будет автоматически синхронизирован в namespace `default` (или в указанном namespace)
3. Для использования в других namespace создайте VaultStaticSecret в нужном namespace или скопируйте Secret
4. Добавьте ImagePullSecret в ServiceAccount, который используется приложениями
5. Или укажите `imagePullSecrets` в манифестах приложений

**Пример для Argo CD Application:**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  destination:
    namespace: my-namespace
    server: https://kubernetes.default.svc
  source:
    repoURL: https://github.com/example/my-app
    path: k8s
    targetRevision: main
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
```

В манифестах приложения (в Git репозитории):

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app
  namespace: my-namespace
imagePullSecrets:
  - name: docker-registry-credentials
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: my-namespace
spec:
  template:
    spec:
      serviceAccountName: my-app
      containers:
        - name: my-app
          image: buildbyte-container-registry.registry.twcstorage.ru/my-app:latest
          # ...
```

**Важно:**
- Secret должен иметь тип `kubernetes.io/dockerconfigjson`
- Secret должен содержать ключ `.dockerconfigjson` с валидным JSON
- Для использования в разных namespace создайте VaultStaticSecret в каждом namespace
- Для Timeweb Container Registry используется API Token вместо пароля, но в Kubernetes Secret он сохраняется в поле `password` для совместимости

**Диагностика, если ImagePullSecrets не работает:**

```bash
# 1. Проверить статус VaultStaticSecret
kubectl get vaultstaticsecret docker-registry-credentials -n default
kubectl describe vaultstaticsecret docker-registry-credentials -n default

# 2. Проверить созданный Secret
kubectl get secret docker-registry-credentials -n default -o yaml

# 3. Проверить тип Secret
kubectl get secret docker-registry-credentials -n default -o jsonpath='{.type}' && echo
# Должно быть: kubernetes.io/dockerconfigjson

# 4. Проверить содержимое .dockerconfigjson
kubectl get secret docker-registry-credentials -n default -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | jq .

# 5. Проверить логи Vault Secrets Operator
kubectl logs -n vault-secrets-operator -l app.kubernetes.io/name=vault-secrets-operator --tail=50 | grep -i "docker-registry"

# 6. Проверить события VaultStaticSecret
kubectl get events -n default --field-selector involvedObject.name=docker-registry-credentials

# 7. Проверить, что секрет существует в Vault
export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_TOKEN=$(cat /tmp/vault-root-token.txt)
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault kv get secret/kubernetes/docker-registry
"

# 8. Проверить, что под может использовать ImagePullSecret
kubectl describe pod <pod-name> -n <namespace> | grep -i "imagepull\|pull"
```

### 12. Установка Prometheus Kube Stack (Prometheus + Grafana)

**Важно:** 
- Перед установкой Prometheus Kube Stack необходимо создать секрет с паролем администратора Grafana через Vault Secrets Operator.
- **Loki должен быть развернут ДО установки Prometheus Kube Stack** (см. раздел 13), так как Loki настроен как источник данных в Grafana (`additionalDataSources` в `helm/services/prom-kube-stack/prom-kube-stack-values.yaml`). Если Prometheus Kube Stack развернется раньше Loki, источник данных Loki не будет автоматически настроен.

#### 12.1. Создание секрета в Vault и VaultStaticSecret для Grafana admin credentials

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

# Создать VaultStaticSecret для синхронизации admin credentials из Vault
cat <<EOF | kubectl apply -f -
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  name: grafana-admin-credentials
  namespace: kube-prometheus-stack
spec:
  vaultAuthRef: vault-secrets-operator/default
  mount: secret
  type: kv-v2
  path: grafana/admin
  refreshAfter: 60s
  destination:
    name: grafana-admin
    create: true
EOF

# Проверить синхронизацию секретов
kubectl get vaultstaticsecret -n kube-prometheus-stack
kubectl describe vaultstaticsecret grafana-admin-credentials -n kube-prometheus-stack

# Проверить созданный Secret
kubectl get secret grafana-admin -n kube-prometheus-stack
```

**Примечание:** Если секреты для Grafana уже сохранены в Vault в разделе 10.1, можно пропустить Шаг 1 и сразу перейти к Шагу 2.

#### 12.2. Установка Prometheus Kube Stack

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
- Secret `grafana-admin` должен быть создан через Vault Secrets Operator перед установкой
- Admin credentials настроены в `helm/services/prom-kube-stack/prom-kube-stack-values.yaml` для использования существующего секрета
- **Loki должен быть развернут ДО установки Prometheus Kube Stack** (см. раздел 13), так как Loki настроен как источник данных в Grafana через `additionalDataSources`. Если Prometheus Kube Stack развернется раньше Loki, источник данных Loki не будет автоматически настроен при первом развертывании

**Получение пароля администратора Grafana:**
```bash
# Имя администратора Grafana (из Vault через VaultStaticSecret)
kubectl get secret grafana-admin -n kube-prometheus-stack -o jsonpath='{.data.admin-user}' | base64 -d && echo

# Пароль администратора Grafana (из Vault через VaultStaticSecret)
kubectl get secret grafana-admin -n kube-prometheus-stack -o jsonpath='{.data.admin-password}' | base64 -d && echo
```

#### 12.3. Настройка OIDC для Grafana через Keycloak

**Важно:** Перед настройкой OIDC убедитесь, что:
- Keycloak установлен и доступен по адресу `https://keycloak.buildbyte.ru`
- В Keycloak создан клиент `grafana` с правильными redirect URIs
- Получен Client Secret для клиента `grafana`

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
# Установить переменные для работы с Vault
export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_TOKEN=$(cat /tmp/vault-root-token.txt)

# Убедиться, что KV v2 секретный движок включен
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault secrets enable -version=2 -path=secret kv 2>&1 || echo 'Секретный движок уже включен'
"

# Сохранить Client Secret для Grafana OIDC
# Замените <ВАШ_CLIENT_SECRET> на реальный Client Secret из Keycloak
# ВАЖНО: Используйте нижнее подчеркивание в ключе (client_secret), а не дефис
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

VaultStaticSecret синхронизирует Client Secret из Vault в секрет `grafana-oidc-secret`, который используется Grafana для OIDC аутентификации через переменную окружения.

```bash
# Создать VaultStaticSecret для синхронизации OIDC client-secret для Grafana
cat <<EOF | kubectl apply -f -
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  name: grafana-oidc-secret
  namespace: kube-prometheus-stack
spec:
  vaultAuthRef: vault-secrets-operator/default
  mount: secret
  type: kv-v2
  path: grafana/oidc
  refreshAfter: 60s
  destination:
    name: grafana-oidc-secret
    create: true
EOF

# Проверить статус VaultStaticSecret
kubectl get vaultstaticsecret grafana-oidc-secret -n kube-prometheus-stack
kubectl describe vaultstaticsecret grafana-oidc-secret -n kube-prometheus-stack

# Проверить созданный Secret
kubectl get secret grafana-oidc-secret -n kube-prometheus-stack

# Проверить значение Client Secret (должно быть реальное значение)
kubectl get secret grafana-oidc-secret -n kube-prometheus-stack -o jsonpath='{.data.client_secret}' | base64 -d && echo

# Если синхронизация не прошла, проверьте логи Vault Secrets Operator:
kubectl logs -n vault-secrets-operator -l app.kubernetes.io/name=vault-secrets-operator --tail=50 | grep -i grafana
```

**Важно:**
- VaultStaticSecret создает секрет `grafana-oidc-secret` с ключом `client_secret`
- Секрет используется через переменную окружения `GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET` (настроено в `helm/services/prom-kube-stack/prom-kube-stack-values.yaml` через `envValueFrom`)
- OIDC конфигурация уже настроена в `helm/services/prom-kube-stack/prom-kube-stack-values.yaml`
- Если синхронизация не прошла, проверьте:
  - Существует ли секрет в Vault по пути `secret/grafana/oidc` с ключом `client_secret`
  - Настроен ли VaultAuth для Vault Secrets Operator
  - Работает ли Vault Secrets Operator

**Шаг 4: Перезапустить Grafana (если необходимо)**

После создания секрета Grafana автоматически использует его для OIDC. Если OIDC не работает, перезапустите Grafana:

```bash
# Перезапустить Grafana
kubectl rollout restart deployment kube-prometheus-stack-grafana -n kube-prometheus-stack

# Проверить логи Grafana для подтверждения OIDC конфигурации
kubectl logs -f deployment/kube-prometheus-stack-grafana -n kube-prometheus-stack | grep -i oauth

# Проверить, что переменная окружения установлена в поде Grafana
GRAFANA_POD=$(kubectl get pods -n kube-prometheus-stack -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}')
kubectl exec $GRAFANA_POD -n kube-prometheus-stack -- env | grep GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET
```

**Проверка OIDC:**

1. Откройте Grafana: `https://grafana.buildbyte.ru`
2. Должна появиться кнопка **"LOG IN VIA KEYCLOAK"** или **"LOG IN VIA OIDC"**
3. Выполните вход через Keycloak
4. Проверьте, что пользователь успешно аутентифицирован

**Важно:**
- OIDC конфигурация использует Realm `services` по умолчанию (настроено в `helm/services/prom-kube-stack/prom-kube-stack-values.yaml`)
- Client Secret синхронизируется из Vault через Vault Secrets Operator в секрет `grafana-oidc-secret` с ключом `client_secret`
- Секрет используется через переменную окружения `GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET`, которая устанавливается через `envValueFrom` в `helm/services/prom-kube-stack/prom-kube-stack-values.yaml`
- Grafana автоматически читает переменные окружения с префиксом `GF_` для конфигурации
- Роли настраиваются на основе групп из Keycloak через `role_attribute_path`:
  - Группа `GrafanaAdmins` получает роль `Admin`
  - Группа `GrafanaEditors` получает роль `Editor`
  - Остальные пользователи получают роль `Viewer`

### 13. Установка Loki (централизованное хранение логов)

Loki разворачивается в services кластере и используется для централизованного хранения логов из dev кластера через Fluent Bit.

**Важно:** 
- **Loki должен быть развернут ДО установки Prometheus Kube Stack** (раздел 12), так как Loki настроен как источник данных в Grafana через `additionalDataSources`. Если Prometheus Kube Stack развернется раньше Loki, источник данных Loki не будет автоматически настроен при первом развертывании.
- Loki должен быть развернут перед установкой Fluent Bit в services кластере (раздел 14) и перед настройкой Fluent Bit в dev кластере (раздел 7), так как Fluent Bit будет отправлять логи в Loki.

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
- Chart версия: `6.21.0` (указана в `helm/services/loki/loki-values.yaml` или можно указать через `--version`)

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
- Для production рекомендуется использовать VPN или приватную сеть вместо публичного LoadBalancer

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

### 15. Установка Jaeger

```bash
# 1. Добавить Helm репозиторий Jaeger
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo update

# 2. Установить Jaeger
helm upgrade --install jaeger jaegertracing/jaeger \
  --namespace jaeger \
  --create-namespace \
  -f helm/services/jaeger/jaeger-values.yaml

# 3. Проверить установку
kubectl get pods -n jaeger
kubectl get services -n jaeger

# 4. Дождаться готовности Jaeger
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=jaeger -n jaeger --timeout=300s
```

**Важно:**
- Jaeger настроен для приема трейсов через Jaeger и Zipkin протоколы
- OpenTelemetry Collector настроен для приема и обработки трейсов
- Конфигурация находится в `helm/services/jaeger/jaeger-values.yaml`

**Доступ к Jaeger UI:**
- Jaeger UI доступен через порт-форвардинг или через Ingress/HTTPRoute (если настроен)

**Подробная документация:**
- См. конфигурацию в `helm/services/jaeger/jaeger-values.yaml`

### 16. Создание HTTPRoute для приложений

**Важно:** HTTPRoute должны создаваться ПОСЛЕ установки приложений, так как они ссылаются на сервисы Argo CD и Jenkins.

```bash
# 1. Применить HTTPRoute для Argo CD
kubectl apply -f manifests/services/gateway/routes/argocd-https-route.yaml
kubectl apply -f manifests/services/gateway/routes/argocd-http-redirect.yaml

# 2. Применить HTTPRoute для Jenkins
kubectl apply -f manifests/services/gateway/routes/jenkins-https-route.yaml
kubectl apply -f manifests/services/gateway/routes/jenkins-http-redirect.yaml

# 3. Применить HTTPRoute для Grafana
kubectl apply -f manifests/services/gateway/routes/grafana-https-route.yaml
kubectl apply -f manifests/services/gateway/routes/grafana-http-redirect.yaml

# 4. Применить HTTPRoute для Keycloak
kubectl apply -f manifests/services/gateway/routes/keycloak-https-route.yaml
kubectl apply -f manifests/services/gateway/routes/keycloak-http-redirect.yaml

# 5. Проверить HTTPRoute
kubectl get httproute -A
kubectl describe httproute argocd-server -n argocd
kubectl describe httproute jenkins-server -n jenkins
kubectl describe httproute grafana-server -n kube-prometheus-stack
kubectl describe httproute keycloak-server -n keycloak

# 6. Проверить, что HTTPRoute привязаны к Gateway
kubectl describe gateway service-gateway -n default | grep -A 20 "Listeners:"
```

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

**Примечание:** Gateway API опционален. Если ingress не требуется, этот шаг можно пропустить.

### Шаг 4: Создание Gateway

После установки Gateway API необходимо создать Gateway ресурс для обработки входящего трафика:

```bash
# 1. Применить Gateway
kubectl apply -f manifests/dev/gateway/gateway.yaml

# 2. Проверить статус Gateway
kubectl get gateway -n default
kubectl describe gateway dev-gateway -n default

# 3. Проверить, что Gateway получил IP адрес
kubectl get gateway dev-gateway -n default -o jsonpath='{.status.addresses[0].value}'
```

**Примечание:** 
- HTTP listener будет работать сразу после создания Gateway
- HTTPS listener не будет работать до создания Secret `gateway-tls-cert` (это будет сделано на следующем шаге)
- Gateway должен быть создан перед ClusterIssuer, так как ClusterIssuer ссылается на Gateway для HTTP-01 challenge
- После создания Gateway получите его IP адрес и настройте DNS записи для ваших доменов

**Важно:** 
- Имя Gateway: `dev-gateway` (используется в ClusterIssuer)
- Gateway создается в namespace `default`
- Убедитесь, что Gateway получил внешний IP адрес перед настройкой DNS

### Шаг 5: Установка cert-manager

cert-manager необходим для автоматического управления TLS сертификатами через Let's Encrypt:

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
- Перед установкой убедитесь, что файл `helm/dev/cert-manager/cert-manager-values.yaml` настроен правильно

**Примечание:** cert-manager опционален, если TLS сертификаты не требуются. Однако рекомендуется установить его для безопасного доступа к приложениям.

#### 5.1. Создание ClusterIssuer и сертификата (опционально)

После установки cert-manager можно создать ClusterIssuer и Certificate для автоматической выдачи TLS сертификатов:

```bash
# 1. Применить ClusterIssuer (отредактируйте email и gateway перед применением!)
# ВАЖНО: Gateway должен быть создан, так как ClusterIssuer ссылается на него для HTTP-01 challenge
kubectl apply -f manifests/dev/cert-manager/cluster-issuer.yaml

# 2. Проверить ClusterIssuer
kubectl get clusterissuer
kubectl describe clusterissuer letsencrypt-prod

# 3. Применить Certificate (отредактируйте dnsNames перед применением!)
kubectl apply -f manifests/dev/cert-manager/gateway-certificate.yaml

# 4. Проверить статус Certificate
kubectl get certificate -n default
kubectl describe certificate gateway-tls-cert -n default

# 5. Дождаться создания Secret (может занять несколько минут)
kubectl wait --for=condition=ready certificate gateway-tls-cert -n default --timeout=600s
kubectl get secret gateway-tls-cert -n default
```

**Важно:**
- Перед применением ClusterIssuer отредактируйте `manifests/dev/cert-manager/cluster-issuer.yaml`:
  - Замените `admin@buildbyte.ru` на ваш реальный email
  - Убедитесь, что `parentRefs[0].name` указывает на правильный Gateway (по умолчанию `dev-gateway`)
- Перед применением Certificate отредактируйте `manifests/dev/cert-manager/gateway-certificate.yaml`:
  - Добавьте домены ваших приложений в `dnsNames`
  - Убедитесь, что `secretName` совпадает с `certificateRefs` в Gateway

### Шаг 6: Установка и настройка Vault Secrets Operator для работы с внешним Vault

Vault Secrets Operator будет подключаться к Vault, который находится в services кластере.

#### 6.1. Установка Vault Secrets Operator

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

#### 6.2. Проверка HTTPRoute для Vault в services кластере

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

#### 6.3. Настройка Kubernetes Auth в Vault для dev кластера

Vault должен быть настроен для аутентификации ServiceAccount из dev кластера:

```bash
# 1. Переключиться на services кластер (где находится Vault)
export KUBECONFIG=$HOME/kubeconfig-services-cluster.yaml

# 2. Аутентифицироваться в Vault
export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_TOKEN=$(cat /tmp/vault-root-token.txt)

# Если root token не найден, получите его:
# kubectl exec -n vault vault-0 -- vault operator init -key-shares=1 -key-threshold=1 -format=json | jq -r '.root_token' > /tmp/vault-root-token.txt

# 3. Создать ServiceAccount для token reviewer в dev кластере
# Переключиться на dev кластер
export KUBECONFIG=$HOME/kubeconfig-dev-cluster.yaml

# Создать ServiceAccount для token reviewer в dev кластере
# Этот ServiceAccount будет использоваться Vault для проверки токенов из dev кластера
kubectl create serviceaccount vault-token-reviewer -n vault-secrets-operator --dry-run=client -o yaml | kubectl apply -f -

# 4. Создать ClusterRoleBinding для token reviewer
# Дать права на выполнение TokenReview запросов к Kubernetes API
kubectl create clusterrolebinding vault-token-reviewer-auth-delegator \
  --clusterrole=system:auth-delegator \
  --serviceaccount=vault-secrets-operator:vault-token-reviewer \
  --dry-run=client -o yaml | kubectl apply -f -

# 5. Получить токен ServiceAccount для token reviewer
# Этот токен будет использоваться Vault для проверки токенов из dev кластера
DEV_TOKEN_REVIEWER_JWT=$(kubectl create token vault-token-reviewer -n vault-secrets-operator --duration=8760h)

# 7. Получить CA сертификат dev кластера
DEV_CA_CERT=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.certificate-authority-data}' | base64 -d)

# 8. Получить адрес Kubernetes API dev кластера
# Обычно это адрес из kubeconfig
DEV_K8S_HOST=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.server}')

# 9. Настроить Kubernetes auth в Vault для dev кластера
# Переключиться обратно на services кластер
export KUBECONFIG=$HOME/kubeconfig-services-cluster.yaml

# Включить Kubernetes auth method (если еще не включен)
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault auth enable -path=kubernetes-dev kubernetes 2>&1 || echo 'Kubernetes auth уже включен'
"

# Настроить конфигурацию Kubernetes auth для dev кластера
# ВАЖНО: Используем токен token reviewer из dev кластера, а не из pod'а Vault
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault write auth/kubernetes-dev/config \
  token_reviewer_jwt='$DEV_TOKEN_REVIEWER_JWT' \
  kubernetes_host='$DEV_K8S_HOST' \
  kubernetes_ca_cert='$DEV_CA_CERT' \
  disable_iss_validation=true
"

# 10. Создать политику для Vault Secrets Operator из dev кластера
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault policy write vault-secrets-operator-dev-policy - <<'EOF'
# Политика для Vault Secrets Operator из dev кластера
path \"secret/data/*\" {
  capabilities = [\"read\"]
}
path \"secret/metadata/*\" {
  capabilities = [\"read\", \"list\"]
}
EOF
"

# 11. Создать роль в Vault для Vault Secrets Operator из dev кластера
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

**Важно:** 
- **Token reviewer JWT** должен быть получен из **dev кластера**, а не из pod'а Vault в services кластере
- ServiceAccount `vault-token-reviewer` должен иметь права `system:auth-delegator` через ClusterRoleBinding
- CA сертификат и адрес Kubernetes API должны соответствовать **dev кластеру**
- Если CA сертификат слишком большой для передачи через переменную окружения, можно сохранить его в файл и использовать `kubernetes_ca_cert=@/path/to/dev-ca.pem`

#### 6.4. Создание VaultConnection и VaultAuth для подключения к внешнему Vault

Создайте VaultConnection и VaultAuth для подключения к Vault в services кластере:

```bash
# Переключиться на dev кластер
export KUBECONFIG=$HOME/kubeconfig-dev-cluster.yaml

# Создать VaultConnection для подключения к внешнему Vault
cat <<EOF | kubectl apply -f -
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultConnection
metadata:
  name: vault-connection
  namespace: vault-secrets-operator
spec:
  address: https://vault.buildbyte.ru
  skipTLSVerify: false
EOF

# Создать VaultAuth для аутентификации в Vault
cat <<EOF | kubectl apply -f -
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultAuth
metadata:
  name: vault-auth
  namespace: vault-secrets-operator
spec:
  vaultConnectionRef: vault-connection
  method: kubernetes
  mount: kubernetes-dev
  kubernetes:
    role: vault-secrets-operator
    serviceAccount: default
EOF

# Проверить VaultConnection и VaultAuth
kubectl get vaultconnection -n vault-secrets-operator
kubectl get vaultauth -n vault-secrets-operator
kubectl describe vaultauth vault-auth -n vault-secrets-operator
```

**Важно:** 
- Адрес Vault: `https://vault.buildbyte.ru` (через HTTPRoute в services кластере)
- Убедитесь, что DNS запись для `vault.buildbyte.ru` настроена и указывает на Gateway
- Убедитесь, что TLS сертификат для `vault.buildbyte.ru` создан через cert-manager
- HTTPRoute `vault-server` должен быть применен в services кластере
- Auth method mount: `kubernetes-dev` (отдельный от services кластера)

### Шаг 7: Установка Fluent Bit (сбор логов) в dev кластере

Fluent Bit разворачивается как DaemonSet и собирает логи контейнеров с каждого узла dev кластера, отправляя их в Loki, который развернут в services кластере.

**Важно:**
- Перед установкой Fluent Bit убедитесь, что Loki развернут в services кластере и LoadBalancer Service `loki-gateway` получил внешний IP адрес (см. раздел 13)
- Fluent Bit настроен для отправки логов в Loki через HTTP API
- Необходимо обновить конфигурацию Fluent Bit с внешним IP адресом Loki перед установкой

#### 7.1. Настройка Fluent Bit для отправки логов в Loki

Перед установкой Fluent Bit необходимо обновить конфигурацию с внешним IP адресом Loki:

```bash
# 1. Переключиться на services кластер и получить внешний IP адрес Loki
export KUBECONFIG=$HOME/kubeconfig-services-cluster.yaml
LOKI_EXTERNAL_IP=$(kubectl get svc loki-external -n logging -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Внешний IP адрес Loki: $LOKI_EXTERNAL_IP"

# 2. Обновить конфигурацию Fluent Bit с IP адресом Loki
# Заменить <LOKI_EXTERNAL_IP> на реальный IP адрес в файле helm/dev/fluent-bit/fluent-bit-values.yaml
# Или использовать sed для автоматической замены:
sed -i "s/<LOKI_EXTERNAL_IP>/$LOKI_EXTERNAL_IP/g" helm/dev/fluent-bit/fluent-bit-values.yaml

# 3. Проверить, что IP адрес заменен
grep -A 2 "Host.*$LOKI_EXTERNAL_IP" helm/dev/fluent-bit/fluent-bit-values.yaml
```

**Важно:**
- Замените `<LOKI_EXTERNAL_IP>` на реальный внешний IP адрес LoadBalancer Service `loki-gateway` из services кластера
- IP адрес можно получить командой: `kubectl get svc loki-gateway -n logging -o jsonpath='{.status.loadBalancer.ingress[0].ip}'`
- Если LoadBalancer еще не получил IP адрес, дождитесь его назначения перед настройкой Fluent Bit

#### 7.2. Развертывание Fluent Bit через Argo CD Application

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

#### 7.3. Проверка установки Fluent Bit

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

**Примечание:** Поскольку в Argo CD настроена авторизация через Keycloak (OIDC), используется способ через Secret, который не требует авторизации через CLI.

```bash
# 1. Переключиться на services кластер
export KUBECONFIG=$HOME/kubeconfig-services-cluster.yaml

# 2. Создать Secret с kubeconfig dev кластера для Argo CD
# Получить адрес API сервера dev кластера
DEV_CLUSTER_SERVER=$(kubectl config view --kubeconfig=$HOME/kubeconfig-dev-cluster.yaml --raw --minify --flatten -o jsonpath='{.clusters[].cluster.server}')

# Создать Secret с правильным форматом config
# Argo CD ожидает, что config будет содержать полный kubeconfig в формате YAML
# Используем временный файл для безопасной обработки многострочного YAML

# Создать временные файлы
TMP_CONFIG=$(mktemp)
TMP_SECRET=$(mktemp)

# Получить kubeconfig
kubectl config view --kubeconfig=$HOME/kubeconfig-dev-cluster.yaml --raw --minify --flatten > "$TMP_CONFIG"

# Создать манифест Secret с stringData
cat > "$TMP_SECRET" <<'SECRET_HEADER'
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
  server: 
SECRET_HEADER

# Добавить server (без подстановки переменных в heredoc)
echo "  $DEV_CLUSTER_SERVER" >> "$TMP_SECRET"
echo "  config: |" >> "$TMP_SECRET"

# Добавить kubeconfig с правильными отступами (4 пробела для YAML)
sed 's/^/    /' "$TMP_CONFIG" >> "$TMP_SECRET"

# Применить манифест
kubectl apply -f "$TMP_SECRET"

# Удалить временные файлы
rm -f "$TMP_CONFIG" "$TMP_SECRET"

# Способ 2: Альтернативный способ с JSON форматом config (если способ 1 не работает)
# Argo CD может ожидать config в формате JSON строки
# Создать config как JSON объект
CONFIG_JSON='{"tlsClientConfig":{"insecure":false}}'

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
  server: $DEV_CLUSTER_SERVER
  config: '$CONFIG_JSON'
EOF

# Примечание: Если нужна аутентификация, добавьте в CONFIG_JSON:
# - bearerToken: токен для аутентификации
# - tlsClientConfig.caData: CA сертификат (base64)
# - tlsClientConfig.certData: клиентский сертификат (base64)
# - tlsClientConfig.keyData: клиентский ключ (base64)

# 3. Проверить, что Secret создан
kubectl get secret dev-cluster-secret -n argocd
kubectl describe secret dev-cluster-secret -n argocd

# 4. Проверить статус кластера в Argo CD через веб-интерфейс
# Откройте https://argo.buildbyte.ru
# Авторизуйтесь через Keycloak
# Перейдите в Settings > Clusters
# Должен отображаться кластер dev-cluster со статусом "Connected"
```

**Диагностика, если кластер не отображается в интерфейсе:**

```bash
# 1. Проверить формат Secret
kubectl get secret dev-cluster-secret -n argocd -o yaml

# Убедитесь, что Secret содержит:
# - name: dev-cluster (в data или stringData)
# - server: адрес API сервера dev кластера
# - config: полный kubeconfig в формате YAML
# - метка: argocd.argoproj.io/secret-type: cluster

# Проверить декодированные значения (если Secret использует data вместо stringData)
kubectl get secret dev-cluster-secret -n argocd -o jsonpath='{.data.name}' | base64 -d && echo
kubectl get secret dev-cluster-secret -n argocd -o jsonpath='{.data.server}' | base64 -d && echo
kubectl get secret dev-cluster-secret -n argocd -o jsonpath='{.data.config}' | base64 -d | head -20

# Если Secret использует stringData, проверить через describe
kubectl describe secret dev-cluster-secret -n argocd

# 2. Проверить логи Argo CD Application Controller
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --tail=50 | grep -i cluster

# 3. Проверить, что Argo CD может подключиться к dev кластеру
# Переключиться на dev кластер
export KUBECONFIG=$HOME/kubeconfig-dev-cluster.yaml

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
- Если приложение использует приватные Docker образы, убедитесь, что Docker Registry credentials настроены в namespace `donweather` (см. раздел 10.7)

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
- [ ] Секреты PostgreSQL сохранены в Vault (путь: `secret/postgresql/admin` и `secret/keycloak/postgresql`)
- [ ] VaultStaticSecret `postgresql-admin-credentials` создан и синхронизирован
- [ ] Secret `postgresql-admin-credentials` создан Vault Secrets Operator
- [ ] PostgreSQL установлен через Helm Bitnami и доступен
- [ ] База данных и пользователь для Keycloak созданы в PostgreSQL
- [ ] Секреты PostgreSQL для Keycloak сохранены в Vault (путь: `secret/keycloak/postgresql`)
- [ ] Admin credentials для Keycloak сохранены в Vault (путь: `secret/keycloak/admin`)
- [ ] VaultStaticSecret `postgresql-keycloak-credentials` создан и синхронизирован в namespace `keycloak`
- [ ] VaultStaticSecret `keycloak-admin-credentials` создан и синхронизирован в namespace `keycloak`
- [ ] Secret `postgresql-keycloak-credentials` создан Vault Secrets Operator
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

- **Настройка Kubernetes Auth в Vault для Vault Secrets Operator:** см. раздел 5.1 в этом документе
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
