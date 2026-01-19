# Установка Gateway API с NGINX Gateway Fabric

Данная инструкция описывает процесс установки Gateway API с использованием NGINX Gateway Fabric контроллера.

## Предварительные требования

- Работающий Kubernetes кластер (версия 1.24+)
- `kubectl` настроенный для работы с кластером
- Доступ в интернет для загрузки манифестов

## Шаги установки

### 1. Установка CRDs Gateway API (стандартная версия)

Установите стандартные CRDs Gateway API версии v2.3.0:

```bash
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v2.3.0" | kubectl apply -f -
```

**Альтернатива:** Если нужны экспериментальные возможности:

```bash
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/experimental?ref=v2.3.0" | kubectl apply -f -
```

### 2. Установка CRDs NGINX Gateway Fabric

Установите CRDs для NGINX Gateway Fabric:

```bash
kubectl apply --server-side -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v2.3.0/deploy/crds.yaml
```

### 3. Установка контроллера NGINX Gateway Fabric

Разверните NGINX Gateway Fabric контроллер:

```bash
kubectl apply -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v2.3.0/deploy/default/deploy.yaml
```

### 4. Проверка установки

Убедитесь, что все компоненты установлены корректно:

```bash
# Проверка подов контроллера (должны быть в статусе Running)
kubectl get pods -n nginx-gateway

# Проверка установленных CRDs
kubectl get crd | grep gateway

# Проверка GatewayClass (должен появиться автоматически)
kubectl get gatewayclass

# Детальная информация о GatewayClass
kubectl describe gatewayclass nginx
```

### 5. Применение ваших манифестов

После успешной установки контроллера примените ваши манифесты:

```bash
# 1. GatewayClass (опционально, если нужно создать кастомный)
kubectl apply -f manifests/gateway/gatewayclass.yaml

# 2. TLS Secret (выберите один из вариантов):

# Вариант A: Использовать cert-manager для автоматической выдачи сертификатов (рекомендуется)
# См. инструкцию в manifests/gateway/cert-manager/README.md
kubectl apply -f manifests/gateway/cert-manager/cluster-issuer.yaml
kubectl apply -f manifests/gateway/cert-manager/gateway-certificate.yaml

# Вариант B: Использовать самоподписанный сертификат из манифеста
# kubectl apply -f manifests/gateway/gateway-tls-secret.yaml

# 3. Gateway
kubectl apply -f manifests/gateway/gateway.yaml

# 4. HTTPRoute
kubectl apply -f manifests/gateway/gateway-route.yaml
```

### 6. Проверка статуса ресурсов

```bash
# Проверка Gateway
kubectl get gateway -A

# Проверка статуса Gateway (должен быть Ready)
kubectl describe gateway service-gateway

# Проверка HTTPRoute
kubectl get httproute -A

# Проверка статуса HTTPRoute
kubectl describe httproute test-route -n argocd
```

## Важные замечания

1. **Несоответствие имен:** В `gateway-route.yaml` указан `parentRefs.name: argocd-gateway`, а в `gateway.yaml` - `name: service-gateway`. Убедитесь, что имена совпадают, либо измените:
   - `gateway.yaml`: `name: argocd-gateway`, или
   - `gateway-route.yaml`: `parentRefs.name: service-gateway`

2. **TLS Secret:** Убедитесь, что TLS Secret `gateway-tls-cert` создан в том же namespace, где находится Gateway (по умолчанию `default`).
   
   **Рекомендуется:** Использовать cert-manager для автоматической выдачи и обновления сертификатов от Let's Encrypt.
   - Инструкция: `manifests/gateway/cert-manager/README.md`
   - Манифесты: `manifests/gateway/cert-manager/`

3. **Namespace:** Убедитесь, что все ресурсы созданы в правильных namespace'ах.

## Устранение неполадок

Если поды контроллера не запускаются:

```bash
# Проверка логов контроллера
kubectl logs -n nginx-gateway -l app=nginx-gateway-fabric

# Проверка событий в namespace
kubectl get events -n nginx-gateway --sort-by='.lastTimestamp'

# Проверка статуса Gateway
kubectl describe gateway service-gateway
```

Если Gateway не становится Ready:

- Проверьте, что TLS Secret существует и корректно заполнен
- Убедитесь, что hostname указан правильно
- Проверьте, что GatewayClass доступен

## Интеграция с cert-manager

Для автоматического управления TLS сертификатами используйте cert-manager:

```bash
# Установка cert-manager (если еще не установлен)
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true

# Применение ClusterIssuer и Certificate
kubectl apply -f manifests/gateway/cert-manager/cluster-issuer.yaml
kubectl apply -f manifests/gateway/cert-manager/gateway-certificate.yaml
```

Подробная инструкция: `manifests/gateway/cert-manager/README.md`

## Дополнительная информация

- [Документация NGINX Gateway Fabric](https://docs.nginx.com/nginx-gateway-fabric/)
- [Gateway API спецификация](https://gateway-api.sigs.k8s.io/)
- [NGINX Gateway Fabric на GitHub](https://github.com/nginx/nginx-gateway-fabric)
- [cert-manager с Gateway API](https://cert-manager.io/docs/usage/gateway/)