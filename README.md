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
- **ВНИМАНИЕ: Текущая конфигурация - это временный тестовый режим (standalone) для разработки!**
- Vault использует file storage backend в standalone режиме (настроен в `helm/vault/vault-values.yaml`)
- В продакшене будет настроен полноценный HA кластер с Raft storage и 3 репликами
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
cat /tmp/vault-root-token.txt
```

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

#### 5.1. Настройка Kubernetes Auth в Vault для External Secrets Operator

Перед настройкой ClusterSecretStore необходимо настроить Kubernetes auth в Vault для External Secrets Operator.

**Подробная инструкция:** [`manifests/external-secrets/VAULT_KUBERNETES_AUTH_SETUP.md`](manifests/external-secrets/VAULT_KUBERNETES_AUTH_SETUP.md)

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

# 3. Создать политику для External Secrets Operator
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault policy write external-secrets-policy - <<'EOF'
path \"secret/data/*\" {
  capabilities = [\"read\"]
}
EOF
"

# 4. Создать роль в Vault для External Secrets Operator
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault write auth/kubernetes/role/external-secrets-operator \
  bound_service_account_names=external-secrets \
  bound_service_account_namespaces=external-secrets-system \
  policies=external-secrets-policy \
  ttl=1h
"

# 5. Проверить настройку
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault read auth/kubernetes/role/external-secrets-operator
"
```

#### 5.2. Настройка ClusterSecretStore для Vault

После настройки Kubernetes auth в Vault примените ClusterSecretStore:

**Важно:** Перед применением ClusterSecretStore убедитесь, что External Secrets Operator установлен и CRD созданы!

```bash
# 1. Проверить, что External Secrets Operator установлен
kubectl get pods -n external-secrets-system

# 2. Проверить, что CRD установлены
kubectl get crd | grep external-secrets

# Должны быть установлены следующие CRD:
# - clustersecretstores.external-secrets.io
# - externalsecrets.external-secrets.io
# - secretstores.external-secrets.io

# Если CRD не установлены, установите External Secrets Operator (см. раздел 5)

# 3. Дождаться готовности External Secrets Operator (если только что установили)
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=external-secrets -n external-secrets-system --timeout=300s

# 4. Применить ClusterSecretStore
kubectl apply -f manifests/external-secrets/vault-cluster-secret-store.yaml

# 5. Проверить ClusterSecretStore
kubectl get clustersecretstore
kubectl describe clustersecretstore vault
```

**Важно:**
- **Vault должен быть разблокирован (unsealed)** перед применением ClusterSecretStore
- External Secrets Operator должен быть установлен ПЕРЕД применением ClusterSecretStore (см. раздел 5)
- Kubernetes auth в Vault должен быть настроен перед созданием ClusterSecretStore (см. раздел 5.1)
- ServiceAccount `external-secrets` должен существовать в namespace `external-secrets-system` (создается автоматически при установке)
- Роль в Vault должна иметь доступ к путям секретов, которые будут использоваться
- После настройки ClusterSecretStore можно создавать ExternalSecret ресурсы для синхронизации секретов

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

#### 6.2. Создание ExternalSecret для PostgreSQL

Создайте ExternalSecret для синхронизации секретов из Vault:

```bash
# Создать namespace для PostgreSQL (если еще не создан)
kubectl create namespace postgresql --dry-run=client -o yaml | kubectl apply -f -

# Применить ExternalSecret манифест для PostgreSQL admin credentials
kubectl apply -f manifests/postgresql/postgresql-admin-credentials-externalsecret.yaml

# Проверить синхронизацию секретов
kubectl get externalsecret -n postgresql
kubectl describe externalsecret postgresql-admin-credentials -n postgresql

# Проверить созданный Secret
kubectl get secret postgresql-admin-credentials -n postgresql
```

#### 6.3. Установка PostgreSQL через Helm Bitnami

```bash
# 1. Добавить Helm репозиторий Bitnami
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# 2. Установить PostgreSQL
# Настройки для использования существующего Secret уже указаны в helm/postgresql/postgresql-values.yaml
helm upgrade --install postgresql bitnami/postgresql \
  --namespace postgresql \
  --create-namespace \
  -f helm/postgresql/postgresql-values.yaml

# 3. Проверить установку
kubectl get pods -n postgresql
kubectl get statefulset -n postgresql
kubectl get pvc -n postgresql

# 5. Дождаться готовности PostgreSQL
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgresql -n postgresql --timeout=600s
```

**Важно:**
- PostgreSQL использует StorageClass `nvme.network-drives.csi.timeweb.cloud` для персистентного хранилища
- Размер хранилища по умолчанию: 8Gi (можно изменить в `helm/postgresql/postgresql-values.yaml`)
- Secret `postgresql-admin-credentials` должен быть создан через External Secrets Operator перед установкой

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

Откройте `manifests/keycloak/keycloak-instance.yaml` и обновите адрес PostgreSQL:

```yaml
database:
  host: postgresql.postgresql.svc.cluster.local  # Замените на ваш адрес PostgreSQL
```

**Шаг 3: Создать ExternalSecret для PostgreSQL credentials в namespace keycloak**

Секреты PostgreSQL для Keycloak должны быть созданы в namespace `keycloak`, где будет развернут Keycloak:

```bash
# Создать namespace для Keycloak (если еще не создан)
kubectl create namespace keycloak --dry-run=client -o yaml | kubectl apply -f -

# Создать ExternalSecret для синхронизации секретов PostgreSQL из Vault
kubectl apply -f manifests/keycloak/postgresql-credentials-externalsecret.yaml

# Создать ExternalSecret для синхронизации admin credentials из Vault
kubectl apply -f manifests/keycloak/admin-credentials-externalsecret.yaml

# Проверить синхронизацию секретов
kubectl get externalsecret -n keycloak
kubectl get secret postgresql-keycloak-credentials -n keycloak
kubectl get secret keycloak-admin-credentials -n keycloak
```

**Примечание:** Секреты PostgreSQL и admin credentials для Keycloak уже сохранены в Vault в разделе 6.1. Здесь мы создаем ExternalSecret в namespace `keycloak` для синхронизации этих секретов.

#### 7.3. Создание Keycloak инстанса

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

#### 7.4. Создание realm "services" и клиентов

После того, как Keycloak инстанс готов, создайте realm "services" с клиентами для приложений:

```bash
# 1. Убедиться, что секрет keycloak-admin-credentials существует
kubectl get secret keycloak-admin-credentials -n keycloak

# Если секрет не существует, создать ExternalSecret:
kubectl apply -f manifests/keycloak/admin-credentials-externalsecret.yaml

# 2. Дождаться готовности Keycloak
kubectl wait --for=condition=ready pod -l app=keycloak -n keycloak --timeout=600s

# 3. Применить KeycloakRealmImport для создания realm "services" и всех компонентов
kubectl apply -f manifests/keycloak/services-realm-import.yaml

# 4. Проверить статус импорта
kubectl get keycloakrealmimport services-realm -n keycloak
kubectl wait --for=condition=ready keycloakrealmimport/services-realm -n keycloak --timeout=300s
```

**Важно:**
- Realm "services" создается автоматически с клиентами для Argo CD, Jenkins и Grafana
- Client secrets генерируются автоматически Keycloak
- Если realm не виден в UI, перезагрузите Keycloak: `kubectl rollout restart statefulset/keycloak -n keycloak`

### 8. Установка cert-manager

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

### 9. Создание Gateway

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


### 10. Создание ClusterIssuer и сертификата

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
- Certificate уже содержит все hostnames: `argo.buildbyte.ru`, `jenkins.buildbyte.ru`, `grafana.buildbyte.ru`, `keycloak.buildbyte.ru`
- При добавлении новых приложений обновите `dnsNames` в `manifests/cert-manager/gateway-certificate.yaml` и пересоздайте Certificate

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

#### 10.2. Создание ExternalSecret для синхронизации секретов

```bash
# Создать namespace для Argo CD и Jenkins (если еще не созданы)
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace jenkins --dry-run=client -o yaml | kubectl apply -f -

# Создать ExternalSecret для Argo CD
kubectl apply -f manifests/argocd/admin-credentials-externalsecret.yaml

# Создать ExternalSecret для Jenkins
kubectl apply -f manifests/jenkins/admin-credentials-externalsecret.yaml

# Создать ExternalSecret для Grafana (будет использоваться при установке Prometheus Kube Stack)
kubectl create namespace kube-prometheus-stack --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f manifests/grafana/admin-credentials-externalsecret.yaml

# Проверить синхронизацию секретов
kubectl get externalsecret -n argocd
kubectl get externalsecret -n jenkins
kubectl get externalsecret -n kube-prometheus-stack
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
  -f helm/argocd/argocd-values.yaml \
  --set configs.secret.argocdServerAdminPassword="$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d)"

# 3. Установить Jenkins (admin credentials уже настроены в helm/jenkins/jenkins-values.yaml)
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

**Получение паролей:**
```bash
# Пароль администратора Argo CD (из Vault через ExternalSecret)
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d | echo
# Примечание: Это bcrypt хеш, для использования нужно знать исходный пароль

# Пароль администратора Jenkins (из Vault через ExternalSecret)
kubectl get secret jenkins-admin-credentials -n jenkins -o jsonpath='{.data.jenkins-admin-password}' | base64 -d && echo
```

### 12. Установка Prometheus Kube Stack (Prometheus + Grafana)

**Важно:** Перед установкой Prometheus Kube Stack необходимо создать секрет с паролем администратора Grafana через External Secrets Operator.

#### 12.1. Создание секрета в Vault и ExternalSecret для Grafana admin credentials

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

**Шаг 2: Создать ExternalSecret для синхронизации секретов**

```bash
# Создать namespace для Prometheus Kube Stack (если еще не создан)
kubectl create namespace kube-prometheus-stack --dry-run=client -o yaml | kubectl apply -f -

# Создать ExternalSecret для синхронизации admin credentials из Vault
kubectl apply -f manifests/grafana/admin-credentials-externalsecret.yaml

# Проверить синхронизацию секретов
kubectl get externalsecret -n kube-prometheus-stack
kubectl describe externalsecret grafana-admin-credentials -n kube-prometheus-stack

# Проверить созданный Secret
kubectl get secret grafana-admin -n kube-prometheus-stack
```

**Примечание:** Если секреты для Grafana уже сохранены в Vault в разделе 10.1, можно пропустить Шаг 1 и сразу перейти к Шагу 2.

#### 12.2. Установка Prometheus Kube Stack

```bash
# 1. Добавить Helm репозиторий Prometheus Community
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# 2. Установить Prometheus Kube Stack
# Admin credentials уже настроены в helm/prom-kube-stack/prom-kube-stack-values.yaml
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
- Secret `grafana-admin` должен быть создан через External Secrets Operator перед установкой
- Admin credentials настроены в `helm/prom-kube-stack/prom-kube-stack-values.yaml` для использования существующего секрета

**Получение пароля администратора Grafana:**
```bash
# Имя администратора Grafana (из Vault через ExternalSecret)
kubectl get secret grafana-admin -n kube-prometheus-stack -o jsonpath='{.data.admin-user}' | base64 -d && echo

# Пароль администратора Grafana (из Vault через ExternalSecret)
kubectl get secret grafana-admin -n kube-prometheus-stack -o jsonpath='{.data.admin-password}' | base64 -d && echo
```

### 13. Установка Jaeger

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

### 14. Создание HTTPRoute для приложений

**Важно:** HTTPRoute должны создаваться ПОСЛЕ установки приложений, так как они ссылаются на сервисы Argo CD и Jenkins.

```bash
# 1. Применить HTTPRoute для Argo CD
kubectl apply -f manifests/gateway/routes/argocd-https-route.yaml
kubectl apply -f manifests/gateway/routes/argocd-http-redirect.yaml

# 2. Применить HTTPRoute для Jenkins
kubectl apply -f manifests/gateway/routes/jenkins-https-route.yaml
kubectl apply -f manifests/gateway/routes/jenkins-http-redirect.yaml

# 3. Применить HTTPRoute для Grafana
kubectl apply -f manifests/gateway/routes/grafana-https-route.yaml
kubectl apply -f manifests/gateway/routes/grafana-http-redirect.yaml

# 4. Применить HTTPRoute для Keycloak
kubectl apply -f manifests/gateway/routes/keycloak-https-route.yaml
kubectl apply -f manifests/gateway/routes/keycloak-http-redirect.yaml

# 5. Проверить HTTPRoute
kubectl get httproute -A
kubectl describe httproute argocd-server -n argocd
kubectl describe httproute jenkins-server -n jenkins
kubectl describe httproute grafana-server -n kube-prometheus-stack
kubectl describe httproute keycloak-server -n keycloak

# 6. Проверить, что HTTPRoute привязаны к Gateway
kubectl describe gateway service-gateway -n default | grep -A 20 "Listeners:"
```

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
- [ ] Секреты PostgreSQL сохранены в Vault (путь: `secret/postgresql/admin` и `secret/keycloak/postgresql`)
- [ ] ExternalSecret `postgresql-admin-credentials` создан и синхронизирован
- [ ] Secret `postgresql-admin-credentials` создан External Secrets Operator
- [ ] PostgreSQL установлен через Helm Bitnami и доступен
- [ ] База данных и пользователь для Keycloak созданы в PostgreSQL
- [ ] Секреты PostgreSQL для Keycloak сохранены в Vault (путь: `secret/keycloak/postgresql`)
- [ ] Admin credentials для Keycloak сохранены в Vault (путь: `secret/keycloak/admin`)
- [ ] ExternalSecret `postgresql-keycloak-credentials` создан и синхронизирован в namespace `keycloak`
- [ ] ExternalSecret `keycloak-admin-credentials` создан и синхронизирован в namespace `keycloak`
- [ ] Secret `postgresql-keycloak-credentials` создан External Secrets Operator
- [ ] Secret `keycloak-admin-credentials` создан External Secrets Operator
- [ ] Адрес PostgreSQL обновлен в `keycloak-instance.yaml`
- [ ] Keycloak Operator установлен и Keycloak инстанс готов
- [ ] Keycloak успешно подключен к PostgreSQL (проверено в логах)
- [ ] Argo CD установлен и сервисы готовы
- [ ] Jenkins установлен и сервисы готовы
- [ ] Admin credentials для Grafana сохранены в Vault (путь: `secret/grafana/admin`)
- [ ] ExternalSecret `grafana-admin-credentials` создан и синхронизирован в namespace `kube-prometheus-stack`
- [ ] Secret `grafana-admin` создан External Secrets Operator
- [ ] Prometheus Kube Stack установлен и сервисы готовы
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

- **Настройка Kubernetes Auth в Vault для External Secrets Operator:** [`manifests/external-secrets/VAULT_KUBERNETES_AUTH_SETUP.md`](manifests/external-secrets/VAULT_KUBERNETES_AUTH_SETUP.md)
- **Настройка Keycloak Authentication для Jenkins:** [`helm/jenkins/JENKINS_KEYCLOAK_SETUP.md`](helm/jenkins/JENKINS_KEYCLOAK_SETUP.md)

## Важные замечания

1. **Порядок установки критичен:**
   - **Vault должен быть установлен одним из первых** (для хранения секретов)
   - **External Secrets Operator должен быть установлен после Vault** (для синхронизации секретов)
   - **ClusterSecretStore должен быть настроен после External Secrets Operator** (для подключения к Vault)
   - **PostgreSQL должен быть установлен перед Keycloak** (Keycloak использует PostgreSQL в качестве базы данных)
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
   - **PostgreSQL** → требует **секреты через External Secrets Operator** (для паролей администратора и репликации)
   - **Приложения** → требуют **секреты через External Secrets Operator** (Keycloak, Grafana и т.д.)
   - **Keycloak** → требует **PostgreSQL** (в качестве базы данных)
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
PostgreSQL (использует секреты из External Secrets Operator)
  ↓
Keycloak Operator → Keycloak (использует PostgreSQL и секреты из External Secrets Operator)
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
- **Vault** должен быть установлен до External Secrets Operator
- **External Secrets Operator** должен быть установлен до приложений, которые используют секреты
- Все секреты создаются через External Secrets Operator, который синхронизирует их из Vault
- Секреты для Keycloak, Grafana и других приложений должны быть сохранены в Vault перед установкой приложений
