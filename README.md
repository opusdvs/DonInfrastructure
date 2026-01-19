# DonInfrastructure

Инфраструктура для развертывания Kubernetes кластера с использованием Timeweb Cloud.

## Порядок установки Kubernetes кластера

Пошаговая инструкция по развертыванию полного стека инфраструктуры.

### Предварительные требования

- Установленный Terraform (версия >= 0.13)
- Настроенный `kubectl` для работы с кластером
- Установленный Helm (версия 3.x+)
- Доступ к панели управления Timeweb Cloud
- API ключ Timeweb Cloud с правами на создание ресурсов

### 1. Развертывание Kubernetes кластера с помощью Terraform

```bash
# Перейти в директорию terraform
cd terraform

# Инициализировать Terraform
terraform init

# Проверить план (опционально)
terraform plan

# Применить конфигурацию и создать кластер
terraform apply

# После создания кластера, kubeconfig будет сохранен в:
# ~/kubeconfig-<cluster-name>.yaml
```

**Важно:** После создания кластера убедитесь, что `kubectl` настроен для работы с кластером:

```bash
# Настроить kubeconfig
export KUBECONFIG=~/kubeconfig-<cluster-name>.yaml

# Проверить подключение к кластеру
kubectl get nodes
kubectl get pods -A
```

**Конфигурация кластера:**
- Регион: `ru-1` (по умолчанию, можно изменить в `terraform/variables.tf`)
- Мастер: 4 CPU
- Воркер ноды: 2 CPU, количество узлов: 3 (настраивается в `terraform/variables.tf`)

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

### 4. Установка cert-manager

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

### 5. Создание Gateway

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

### 6. Создание ClusterIssuer и сертификата

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

### 7. Установка Jenkins и Argo CD

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

### 8. Установка Vault

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

**Получение root token:**
```bash
# См. инструкцию: helm/vault/VAULT_TOKEN.md
kubectl exec -n vault vault-0 -- vault operator init -key-shares=1 -key-threshold=1 -format=json | jq -r '.root_token'
```

**Подробная документация:**
- `helm/vault/VAULT_TOKEN.md` - получение root token
- `helm/vault/VAULT_AUTH_METHODS.md` - настройка методов аутентификации
- `helm/vault/VAULT_SECRETS_INJECTION.md` - инъекция секретов в поды
- `helm/vault/CSI_TROUBLESHOOTING.md` - устранение проблем с CSI
- `helm/vault/RAFT_TROUBLESHOOTING.md` - устранение проблем с Raft storage

### 9. Установка Prometheus Kube Stack (Prometheus + Grafana)

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

### 10. Установка Keycloak Operator

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

# 4. Создать Keycloak инстанс
kubectl apply -f manifests/keycloak/keycloak-instance.yaml

# 5. Проверить статус Keycloak
kubectl get keycloak -n keycloak
kubectl get pods -n keycloak

# 6. Дождаться готовности Keycloak (может занять несколько минут)
kubectl wait --for=condition=ready pod -l app=keycloak -n keycloak --timeout=600s
```

**Важно:**
- Keycloak использует встроенную H2 базу данных (не требует PostgreSQL)
- Для production рекомендуется использовать PostgreSQL
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

### 11. Установка Jaeger

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

### 12. Создание HTTPRoute для приложений

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

## Полный чек-лист установки

- [ ] Кластер Kubernetes развернут через Terraform
- [ ] `kubectl` настроен и подключен к кластеру
- [ ] Gateway API с NGINX Gateway Fabric установлен
- [ ] CSI драйвер Timeweb Cloud установлен и работает
- [ ] cert-manager установлен с поддержкой Gateway API
- [ ] Gateway создан (HTTP listener работает)
- [ ] ClusterIssuer создан и готов (Status: Ready)
- [ ] Certificate создан и Secret `gateway-tls-cert` существует
- [ ] HTTPS listener Gateway активирован (после создания Secret)
- [ ] Argo CD установлен и сервисы готовы
- [ ] Jenkins установлен и сервисы готовы
- [ ] Vault установлен и сервисы готовы
- [ ] Prometheus Kube Stack установлен и сервисы готовы
- [ ] Keycloak Operator установлен и Keycloak инстанс готов
- [ ] Jaeger установлен и сервисы готовы
- [ ] HTTPRoute для Argo CD созданы и привязаны к Gateway
- [ ] HTTPRoute для Jenkins созданы и привязаны к Gateway
- [ ] HTTPRoute для Vault созданы и привязаны к Gateway
- [ ] HTTPRoute для Grafana созданы и привязаны к Gateway
- [ ] HTTPRoute для Keycloak созданы и привязаны к Gateway

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
```

## Дополнительная документация

- **Gateway API:** `manifests/gateway/README.md`
- **Устранение неполадок Gateway:** `manifests/gateway/TROUBLESHOOTING.md`
- **cert-manager:** `manifests/cert-manager/README.md`
- **Vault:** `helm/vault/VAULT_TOKEN.md`, `helm/vault/VAULT_AUTH_METHODS.md`, `helm/vault/VAULT_SECRETS_INJECTION.md`
- **Prometheus Kube Stack:** `helm/prom-kube-stack/GRAFANA_ADMIN_PASSWORD.md`
- **Keycloak:** `manifests/keycloak/README.md`
- **Argo CD курс:** `docs/argocd-course/`
- **Vault курс:** `docs/vault-course/`

## Важные замечания

1. **Порядок установки критичен:**
   - Gateway должен быть создан перед ClusterIssuer (ClusterIssuer ссылается на Gateway для HTTP-01 challenge)
   - Приложения должны быть установлены перед созданием HTTPRoute (HTTPRoute ссылаются на их сервисы)
   - Secret для TLS создается cert-manager автоматически, но HTTPS listener не будет работать до его создания
   - Keycloak Operator требует установки CRDs перед установкой оператора
   - Vault использует Raft storage, убедитесь, что CSI драйвер работает корректно

2. **Зависимости компонентов:**
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
  - Vault
  - Prometheus Kube Stack (Prometheus + Grafana)
  - Keycloak Operator → Keycloak
  - Jaeger
  ↓
HTTPRoute (ссылаются на Gateway и сервисы приложений)
```
