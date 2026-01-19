# Установка Keycloak Operator

Данная инструкция описывает процесс установки Keycloak Operator с использованием встроенной H2 базы данных (без PostgreSQL).

## Предварительные требования

- Работающий Kubernetes кластер (версия 1.24+)
- `kubectl` настроенный для работы с кластером
- Доступ в интернет для загрузки CRDs

## Шаги установки

### 1. Установка CRDs Keycloak Operator

Установите Custom Resource Definitions для Keycloak Operator:

```bash
# Установка CRDs из официального репозитория
kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/main/kubernetes/keycloaks.k8s.keycloak.org-v1.yml
kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/main/kubernetes/keycloakrealmimports.k8s.keycloak.org-v1.yml
kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/main/kubernetes/keycloakclients.k8s.keycloak.org-v1.yml
```

**Альтернатива:** Использовать kustomize:

```bash
kubectl kustomize https://github.com/keycloak/keycloak-k8s-resources/kubernetes | kubectl apply -f -
```

### 2. Установка Keycloak Operator

Примените манифест для установки оператора:

```bash
kubectl apply -f manifests/keycloak/keycloak-operator-install.yaml
```

Проверьте, что оператор запустился:

```bash
# Проверка подов оператора
kubectl get pods -n keycloak-system

# Проверка статуса Deployment
kubectl get deployment -n keycloak-system

# Просмотр логов оператора
kubectl logs -f deployment/keycloak-operator -n keycloak-system
```

### 3. Создание Keycloak инстанса

Примените манифест для создания Keycloak инстанса:

```bash
kubectl apply -f manifests/keycloak/keycloak-instance.yaml
```

Проверьте статус Keycloak:

```bash
# Проверка Keycloak CR
kubectl get keycloak -n keycloak

# Детальная информация о Keycloak
kubectl describe keycloak keycloak -n keycloak

# Проверка подов Keycloak
kubectl get pods -n keycloak

# Просмотр логов Keycloak
kubectl logs -f keycloak-0 -n keycloak
```

### 4. Проверка сервисов

Убедитесь, что сервисы созданы:

```bash
# Проверка сервисов
kubectl get svc -n keycloak

# Должен быть сервис keycloak на порту 8080
kubectl describe svc keycloak -n keycloak
```

### 5. Настройка Gateway маршрутов

Если Gateway API уже настроен, примените маршруты:

```bash
# HTTP redirect
kubectl apply -f manifests/gateway/routes/keycloak-http-redirect.yaml

# HTTPS route
kubectl apply -f manifests/gateway/routes/keycloak-https-route.yaml
```

**Важно:** Убедитесь, что в `keycloak-https-route.yaml` указан правильный namespace и имя сервиса:

```yaml
backendRefs:
  - name: keycloak  # Имя сервиса, созданного оператором
    port: 8080      # Порт Keycloak (обычно 8080)
```

### 6. Получение пароля администратора

Пароль администратора хранится в Secret:

```bash
# Получение пароля администратора
kubectl get secret credential-keycloak -n keycloak -o jsonpath='{.data.ADMIN_PASSWORD}' | base64 -d
echo

# Получение имени пользователя администратора
kubectl get secret credential-keycloak -n keycloak -o jsonpath='{.data.ADMIN_USERNAME}' | base64 -d
echo
```

### 7. Доступ к Keycloak

После успешного развертывания Keycloak будет доступен по адресу:

- **URL:** https://keycloak.buildbyte.ru
- **Admin Console:** https://keycloak.buildbyte.ru/admin
- **Username:** admin (или значение из Secret)
- **Password:** (значение из Secret `credential-keycloak`)

## Особенности конфигурации

### Встроенная H2 база данных

По умолчанию Keycloak Operator использует встроенную H2 базу данных, которая:
- Не требует дополнительных компонентов (PostgreSQL, MySQL и т.д.)
- Подходит для development и тестирования
- **Не рекомендуется для production** (данные могут быть потеряны при перезапуске пода)

### Переход на PostgreSQL (опционально)

Если в будущем потребуется PostgreSQL, можно обновить Keycloak CR:

```yaml
spec:
  database:
    vendor: postgres
    host: postgresql.keycloak.svc.cluster.local
    database: keycloak
    usernameSecret:
      name: postgresql-credentials
      key: username
    passwordSecret:
      name: postgresql-credentials
      key: password
```

## Troubleshooting

### Проблема: Keycloak не запускается

```bash
# Проверка событий
kubectl get events -n keycloak --sort-by='.lastTimestamp'

# Проверка логов оператора
kubectl logs -f deployment/keycloak-operator -n keycloak-system

# Проверка логов Keycloak
kubectl logs -f keycloak-0 -n keycloak
```

### Проблема: Health probes не работают

Убедитесь, что в Keycloak CR включен health endpoint:

```yaml
spec:
  additionalOptions:
    - name: health-enabled
      value: "true"
```

### Проблема: Gateway не может подключиться к Keycloak

Проверьте:
1. Сервис создан: `kubectl get svc -n keycloak`
2. Порт в HTTPRoute совпадает с портом сервиса: `kubectl describe svc keycloak -n keycloak`
3. Namespace в HTTPRoute правильный

## Полезные команды

```bash
# Удаление Keycloak инстанса
kubectl delete keycloak keycloak -n keycloak

# Удаление оператора
kubectl delete -f manifests/keycloak/keycloak-operator-install.yaml

# Удаление CRDs (будет удалено все, что использует эти CRDs)
kubectl delete crd keycloaks.k8s.keycloak.org
kubectl delete crd keycloakrealmimports.k8s.keycloak.org
kubectl delete crd keycloakclients.k8s.keycloak.org
```

## Дополнительные ресурсы

- [Keycloak Operator Documentation](https://www.keycloak.org/operator)
- [Keycloak Kubernetes Resources](https://github.com/keycloak/keycloak-k8s-resources)
- [Keycloak Operator Examples](https://github.com/keycloak/keycloak-k8s-resources/tree/main/examples)
