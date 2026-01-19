# Интеграция Gateway API с cert-manager

Инструкция по настройке автоматического управления TLS сертификатами для Gateway API с использованием cert-manager и Let's Encrypt.

## Предварительные требования

1. **Установленный cert-manager** в кластере
2. **Gateway API** установлен и работает
3. **Gateway ресурс** создан и доступен
4. **Домен** должен указывать на ваш Gateway (DNS настроен)
5. **Gateway доступен из интернета** на портах 80 и 443 (для HTTP-01 challenge)

## Установка cert-manager

**ВАЖНО:** Для работы с Gateway API необходимо включить поддержку Gateway API в cert-manager при установке!

### Установка cert-manager с поддержкой Gateway API

```bash
# Добавление Helm репозитория
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Установка cert-manager с включенной поддержкой Gateway API
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.14.5 \
  --set installCRDs=true \
  --set global.leaderElection.namespace=cert-manager \
  --set config.enableGatewayAPI=true

# Или используйте файл values:
# helm install cert-manager jetstack/cert-manager \
#   --namespace cert-manager \
#   --create-namespace \
#   --version v1.14.5 \
#   -f helm/cert-manager-values.yaml
```

**Критически важно:** Флаг `--set config.enableGatewayAPI=true` (или `config.enableGatewayAPI: true` в values) **обязателен** для работы с Gateway API!

### Обновление существующего cert-manager

Если cert-manager уже установлен без поддержки Gateway API:

```bash
# Обновление с включением Gateway API
helm upgrade cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version v1.14.5 \
  --set installCRDs=true \
  --set global.leaderElection.namespace=cert-manager \
  --set config.enableGatewayAPI=true

# Или используйте файл values:
# helm upgrade cert-manager jetstack/cert-manager \
#   --namespace cert-manager \
#   --version v1.14.5 \
#   -f helm/cert-manager-values.yaml

# Перезапуск подов cert-manager для применения изменений
kubectl rollout restart deployment -n cert-manager
```

### Проверка установки

```bash
# Проверка подов cert-manager
kubectl get pods -n cert-manager

# Проверка CRDs
kubectl get crd | grep cert-manager

# Проверка, что Gateway API включен в конфигурации cert-manager
kubectl get deployment cert-manager -n cert-manager -o yaml | grep -i gateway

# Проверка логов cert-manager (должны отсутствовать ошибки о Gateway API)
kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager --tail=50
```

### Проверка версии cert-manager

```bash
# Проверка версии
kubectl get deployment cert-manager -n cert-manager -o jsonpath='{.spec.template.spec.containers[0].image}'
```

**Требования:** cert-manager версии 1.12+ с включенным флагом `enableGatewayAPI`.

## Применение манифестов

### 1. Создание ClusterIssuer

```bash
# Сначала отредактируйте email в cluster-issuer.yaml
kubectl apply -f manifests/gateway/cert-manager/cluster-issuer.yaml
```

**Важно:** Замените `admin@buildbyte.ru` на ваш реальный email адрес.

### 2. Проверка ClusterIssuer

```bash
kubectl get clusterissuer
kubectl describe clusterissuer letsencrypt-prod
```

### 3. Создание временного Secret (опционально)

Если Gateway требует Secret сразу, создайте временный Secret:

```bash
kubectl apply -f manifests/gateway/cert-manager/temporary-secret.yaml
```

**Примечание:** Этот Secret будет автоматически заменен cert-manager после выдачи настоящего сертификата.

### 4. Создание Certificate

```bash
kubectl apply -f manifests/gateway/cert-manager/gateway-certificate.yaml
```

### 5. Проверка статуса Certificate

```bash
# Проверка статуса Certificate
kubectl get certificate -n default
kubectl describe certificate gateway-tls-cert -n default

# Проверка Order (запрос на сертификат)
kubectl get order -n default
kubectl describe order -n default

# Проверка Challenge (HTTP-01 challenge)
kubectl get challenge -A
kubectl describe challenge -A

# Проверка созданного Secret
kubectl get secret gateway-tls-cert -n default
kubectl describe secret gateway-tls-cert -n default
```

### 6. Gateway автоматически использует Secret

Gateway уже настроен на использование Secret `gateway-tls-cert`, который будет создан cert-manager автоматически.

## Проверка работы

После успешной выдачи сертификата:

```bash
# Проверка сертификата через openssl
echo | openssl s_client -showcerts -connect argo.buildbyte.ru:443 2>/dev/null | openssl x509 -inform pem -noout -text

# Проверка через curl
curl -vI https://argo.buildbyte.ru
```

## Использование Staging окружения

Для тестирования используйте staging ClusterIssuer:

```yaml
# В gateway-certificate.yaml измените:
spec:
  issuerRef:
    name: letsencrypt-staging  # Вместо letsencrypt-prod
    kind: ClusterIssuer
```

**Важно:** Staging сертификаты не доверяются браузерами, но позволяют протестировать процесс без риска превысить лимиты production.

## Добавление дополнительных доменов

Чтобы добавить больше доменов в сертификат:

```yaml
# В gateway-certificate.yaml
spec:
  dnsNames:
    - argo.buildbyte.ru
    - weather.buildbyte.ru
    - weather-api.buildbyte.ru
```

## Автоматическое обновление

cert-manager автоматически:
- Обновляет сертификаты за 15 дней до истечения (настроено в `renewBefore`)
- Создает новые Order при необходимости
- Обновляет Secret, который использует Gateway

## Устранение неполадок

### Certificate не выдается

```bash
# Проверка логов cert-manager
kubectl logs -n cert-manager -l app=cert-manager
kubectl logs -n cert-manager -l app=cert-manager --tail=100

# Проверка событий
kubectl get events -n default --sort-by='.lastTimestamp' | grep certificate

# Проверка Order
kubectl describe order -n default

# Проверка Challenge
kubectl describe challenge -A
```

### HTTP-01 challenge не проходит

1. Убедитесь, что Gateway доступен из интернета на порту 80
2. Проверьте, что DNS настроен правильно
3. Проверьте, что HTTPRoute создан для домена
4. Проверьте логи Gateway контроллера

### Ошибка "gateway api is not enabled"

Если вы видите ошибку `Error presenting challenge: gateway api is not enabled`:

**Проблема:** cert-manager установлен без поддержки Gateway API.

**Решение:**

1. **Обновите cert-manager с включенной поддержкой Gateway API:**
   ```bash
   helm upgrade cert-manager jetstack/cert-manager \
     --namespace cert-manager \
     --version v1.14.5 \
     --set config.enableGatewayAPI=true \
     --reuse-values
   ```

2. **Перезапустите поды cert-manager:**
   ```bash
   kubectl rollout restart deployment -n cert-manager
   ```

3. **Проверьте, что Gateway API включен:**
   ```bash
   # Проверка переменных окружения в поде cert-manager
   kubectl get deployment cert-manager -n cert-manager -o yaml | grep -A 5 ENABLE_GATEWAY_API
   
   # Или проверьте логи
   kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager | grep -i gateway
   ```

4. **После обновления пересоздайте Certificate:**
   ```bash
   # Удалите Certificate и создайте заново
   kubectl delete certificate gateway-tls-cert -n default
   kubectl apply -f manifests/gateway/cert-manager/gateway-certificate.yaml
   ```

**Важно:** Без флага `config.enableGatewayAPI=true` cert-manager не сможет создавать HTTPRoute для HTTP-01 challenge!

### Gateway не использует новый сертификат

```bash
# Удалите поды Gateway контроллера для перезагрузки сертификата
kubectl rollout restart deployment -n nginx-gateway

# Или проверьте, что Secret обновлен
kubectl get secret gateway-tls-cert -n default -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -dates
```

### Ошибка "secret does not exist"

Если Gateway выдает ошибку `secret does not exist`:

1. **Создайте временный Secret:**
   ```bash
   kubectl apply -f manifests/gateway/cert-manager/temporary-secret.yaml
   ```

2. **Примените Gateway:**
   ```bash
   kubectl apply -f manifests/gateway/gateway.yaml
   ```

3. **Создайте Certificate (cert-manager заменит временный Secret):**
   ```bash
   kubectl apply -f manifests/gateway/cert-manager/gateway-certificate.yaml
   ```

4. **После выдачи сертификата можно удалить временный Secret (опционально):**
   ```bash
   # Cert-manager уже создал новый Secret, временный можно удалить
   kubectl delete secret gateway-tls-cert -n default
   # Cert-manager автоматически пересоздаст Secret с настоящим сертификатом
   ```

## Лимиты Let's Encrypt

- **Production:** 50 сертификатов на домен в неделю
- **Staging:** 300 сертификатов на домен в неделю

При превышении лимитов используйте staging для тестирования.

## Безопасность

- Email адрес используется только для уведомлений о проблемах с сертификатами
- Приватный ключ ACME аккаунта хранится в Secret `letsencrypt-prod`
- TLS сертификаты автоматически обновляются

## Дополнительная информация

- [Документация cert-manager](https://cert-manager.io/docs/)
- [Gateway API с cert-manager](https://cert-manager.io/docs/usage/gateway/)
- [Let's Encrypt документация](https://letsencrypt.org/docs/)
