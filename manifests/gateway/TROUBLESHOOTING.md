# Устранение неполадок Gateway API

Инструкция по диагностике и решению проблем с Gateway API и NGINX Gateway Fabric.

## Ошибка: "The Listener is invalid for this parent ref"

Эта ошибка возникает, когда HTTPRoute ссылается на listener, который не существует или не может быть активирован в Gateway.

### Причины

1. **Secret для TLS не существует** — HTTPS listener не может быть активирован без Secret с сертификатом
2. **Имя listener не совпадает** — `sectionName` в HTTPRoute не соответствует `name` listener в Gateway
3. **Gateway не готов** — Gateway не был принят контроллером
4. **Namespace не совпадает** — Gateway и HTTPRoute находятся в разных namespace

### Диагностика

#### 1. Проверка Gateway и его listeners

```bash
# Проверить статус Gateway
kubectl get gateway service-gateway -n default
kubectl describe gateway service-gateway -n default

# Проверить, какие listeners активны
kubectl get gateway service-gateway -n default -o jsonpath='{.status.listeners[*].name}'
kubectl get gateway service-gateway -n default -o jsonpath='{.status.listeners[*].conditions}'
```

#### 2. Проверка Secret для TLS

```bash
# Проверить, существует ли Secret
kubectl get secret gateway-tls-cert -n default

# Если Secret не существует, HTTPS listener не будет работать
kubectl describe gateway service-gateway -n default | grep -A 10 "Listeners:"
```

#### 3. Проверка HTTPRoute и parentRefs

```bash
# Проверить все HTTPRoute
kubectl get httproute -A

# Проверить конкретный HTTPRoute
kubectl describe httproute <httproute-name> -n <namespace>

# Проверить parentRefs в HTTPRoute
kubectl get httproute <httproute-name> -n <namespace> -o yaml | grep -A 10 parentRefs
```

### Решения

#### Решение 1: Создать временный Secret для TLS (если Secret отсутствует)

Если Secret `gateway-tls-cert` не существует, HTTPS listener не будет активирован:

```bash
# Проверить, существует ли Secret
kubectl get secret gateway-tls-cert -n default

# Если Secret не существует, создайте временный самоподписанный сертификат
# (cert-manager заменит его позже автоматически)
kubectl create secret tls gateway-tls-cert \
  --cert=/dev/null \
  --key=/dev/null \
  -n default 2>/dev/null || echo "Secret уже существует"

# Или используйте cert-manager для создания настоящего сертификата
kubectl apply -f manifests/gateway/cert-manager/gateway-certificate.yaml
```

#### Решение 2: Проверить соответствие имен listeners

Убедитесь, что `sectionName` в HTTPRoute соответствует `name` listener в Gateway:

**Gateway:**
```yaml
listeners:
  - name: http    # ← это имя
    protocol: HTTP
    port: 80
  - name: https   # ← это имя
    protocol: HTTPS
    port: 443
```

**HTTPRoute:**
```yaml
parentRefs:
  - name: service-gateway
    namespace: default
    sectionName: https  # ← должно совпадать с name listener в Gateway
```

#### Решение 3: Проверить namespace

Убедитесь, что Gateway и HTTPRoute находятся в правильных namespace:

```bash
# Gateway должен быть в namespace default
kubectl get gateway service-gateway -n default

# HTTPRoute может быть в любом namespace, но parentRefs должен указывать на правильный namespace
kubectl get httproute <httproute-name> -n <namespace> -o yaml | grep -A 5 parentRefs
```

#### Решение 4: Проверить статус Gateway listener

Если HTTPS listener не принимается, проверьте условия:

```bash
kubectl get gateway service-gateway -n default -o jsonpath='{.status.listeners[?(@.name=="https")].conditions}' | jq '.'
```

Возможные проблемы:
- `ResolvedRefs: False` — Secret не существует или не может быть прочитан
- `Ready: False` — Listener не может быть активирован

### Примеры проверки

#### Полная диагностика Gateway

```bash
# 1. Проверить Gateway
kubectl get gateway service-gateway -n default -o yaml

# 2. Проверить Secret
kubectl get secret gateway-tls-cert -n default

# 3. Проверить HTTPRoute
kubectl get httproute -A -o wide

# 4. Проверить события
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | grep -i gateway | tail -20

# 5. Проверить логи контроллера Gateway
kubectl logs -n nginx-gateway -l app=nginx-gateway-fabric --tail=100
```

#### Проверка конкретного HTTPRoute

```bash
# Для конкретного HTTPRoute (например, jenkins-server)
kubectl describe httproute jenkins-server -n jenkins

# Проверить условия parentRefs
kubectl get httproute jenkins-server -n jenkins -o jsonpath='{.status.parents[*].conditions}' | jq '.'
```

### Типичные ошибки

#### Ошибка 1: Secret не существует

```
Error: Secret "gateway-tls-cert" not found
```

**Решение:** Создайте Secret или используйте cert-manager для автоматического создания.

#### Ошибка 2: Неправильное имя listener

```
Error: The Listener is invalid for this parent ref
```

**Решение:** Проверьте, что `sectionName` в HTTPRoute точно совпадает с `name` listener в Gateway (с учетом регистра).

#### Ошибка 3: Namespace не совпадает

```
Error: Gateway not found in namespace
```

**Решение:** Убедитесь, что `parentRefs.namespace` в HTTPRoute указывает на правильный namespace, где находится Gateway.

### Быстрое решение

Если вы видите ошибку "The Listener is invalid for this parent ref":

1. **Проверьте Secret:**
   ```bash
   kubectl get secret gateway-tls-cert -n default
   ```

2. **Если Secret отсутствует, создайте временный:**
   ```bash
   # Используйте cert-manager для создания настоящего сертификата
   kubectl apply -f manifests/gateway/cert-manager/gateway-certificate.yaml
   ```

3. **Проверьте статус Gateway:**
   ```bash
   kubectl describe gateway service-gateway -n default
   ```

4. **Проверьте HTTPRoute:**
   ```bash
   kubectl get httproute -A
   kubectl describe httproute <problematic-httproute> -n <namespace>
   ```
