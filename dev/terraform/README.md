# Развертывание Dev Kubernetes кластера

Инструкция по развертыванию dev кластера для микросервисов.

## Предварительные требования

- Установленный Terraform (версия >= 0.13)
- API ключ Timeweb Cloud с правами на создание ресурсов
- Доступ к Timeweb Cloud S3 Storage для хранения Terraform state
- Проект `dev` создан в Timeweb Cloud

## Настройка

### 1. Настройка провайдера Timeweb Cloud

```bash
export TWC_TOKEN="your-timeweb-cloud-api-token"
```

### 2. Настройка Backend для Terraform State

```bash
export AWS_ACCESS_KEY_ID="your-s3-access-key"
export AWS_SECRET_ACCESS_KEY="your-s3-secret-key"
```

Или создайте файл `backend.hcl` (не коммитьте в git!):

```hcl
access_key = "your-s3-access-key"
secret_key = "your-s3-secret-key"
```

### 3. Настройка переменных (опционально)

При необходимости измените переменные в `variables.tf`:

- `project_name`: `dev` (по умолчанию)
- `cluster_name`: `dev-cluster` (по умолчанию)
- `node_group_node_count`: `2` (по умолчанию, меньше чем в services)

## Развертывание кластера

```bash
# Перейти в директорию dev
cd terraform/dev

# Инициализировать Terraform
terraform init

# Проверить план развертывания
terraform plan

# Применить конфигурацию и создать кластер
terraform apply

# После создания кластера, kubeconfig будет сохранен в:
# ~/kubeconfig-dev-cluster.yaml
```

## Настройка kubectl

```bash
# Настроить kubeconfig
export KUBECONFIG=$HOME/kubeconfig-dev-cluster.yaml

# Проверить подключение к кластеру
kubectl get nodes
kubectl get pods -A
```

## Конфигурация кластера по умолчанию

- **Регион:** `ru-1`
- **Проект:** `dev`
- **Имя кластера:** `dev-cluster`
- **Версия Kubernetes:** `v1.34.3+k0s.0`
- **Сетевой драйвер:** `calico`
- **Мастер нода:** 4 CPU
- **Воркер ноды:** 2 CPU, количество узлов: 2 (по умолчанию)
- **Группы нод:** 2 группы воркеров

## Управление кластером

```bash
# Просмотр информации о кластере
terraform show

# Просмотр outputs
terraform output

# Удаление кластера (осторожно!)
terraform destroy
```

## Отличия от Services кластера

- **Меньше ресурсов:** 2 воркер ноды вместо 3 (можно настроить)
- **Отдельный проект:** Проект `dev` в Timeweb Cloud
- **Отдельный state:** State хранится в `dev/terraform.tfstate`
- **Отдельный kubeconfig:** `kubeconfig-dev-cluster.yaml`

## Следующие шаги

После развертывания dev кластера:

1. Установить Gateway API (если нужен)
2. Установить CSI драйвер Timeweb Cloud
3. Настроить доступ к кластеру для разработчиков
4. Развернуть микросервисы через Argo CD или Helm
