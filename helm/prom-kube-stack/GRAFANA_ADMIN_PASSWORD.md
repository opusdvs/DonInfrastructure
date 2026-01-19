# Изменение пароля администратора в Grafana

## Варианты настройки пароля

Есть два способа задать пароль администратора Grafana:

1. **Прямое указание в values.yaml** (простой способ)
2. **Использование Kubernetes Secret** (более безопасный способ)

---

## Вариант 1: Прямое указание пароля (простой способ)

### 1. Раскомментировать и изменить adminPassword в values.yaml

Откройте файл `helm/prom-kube-stack/prom-kube-stack-values.yaml` и найдите секцию:

```yaml
grafana:
  # Administrator credentials when not using an existing secret (see below)
  adminUser: admin
  # adminPassword: strongpassword
```

Измените на:

```yaml
grafana:
  adminUser: admin
  adminPassword: ваш-новый-пароль
```

⚠️ **ВНИМАНИЕ:** Пароль будет храниться в открытом виде в values.yaml. Не коммитьте файл с паролем в публичный репозиторий!

### 2. Применить изменения

```bash
# Обновить Helm релиз
helm upgrade prometheus-kube-stack prometheus-community/kube-prometheus-stack \
  -n kube-prometheus-stack \
  -f helm/prom-kube-stack/prom-kube-stack-values.yaml

# Или если релиз называется иначе
helm upgrade <your-release-name> prometheus-community/kube-prometheus-stack \
  -n <namespace> \
  -f helm/prom-kube-stack/prom-kube-stack-values.yaml
```

### 3. Перезапустить под Grafana (опционально)

```bash
# Если пароль не применился, перезапустите под Grafana
kubectl rollout restart deployment kube-prometheus-stack-grafana -n kube-prometheus-stack
```

---

## Вариант 2: Использование Kubernetes Secret (рекомендуется)

Этот способ более безопасный, так как пароль хранится в Kubernetes Secret, а не в файле values.yaml.

### 1. Создать Kubernetes Secret с паролем

```bash
# Создать Secret с паролем администратора
kubectl create secret generic grafana-admin \
  -n kube-prometheus-stack \
  --from-literal=admin-user=admin \
  --from-literal=admin-password=ваш-новый-пароль

# Или использовать base64 (если нужен более безопасный способ)
echo -n "ваш-новый-пароль" | base64
# Затем использовать полученную строку в YAML
```

### 2. Обновить values.yaml

В файле `helm/prom-kube-stack/prom-kube-stack-values.yaml` найдите секцию:

```yaml
grafana:
  adminUser: admin
  # adminPassword: strongpassword

  # Use an existing secret for the admin user.
  admin:
    ## Name of the secret. Can be templated.
    existingSecret: ""
    userKey: admin-user
    passwordKey: admin-password
```

Измените на:

```yaml
grafana:
  adminUser: admin
  # adminPassword не указываем, используем Secret

  admin:
    existingSecret: "grafana-admin"  # Имя Secret, созданного выше
    userKey: admin-user
    passwordKey: admin-password
```

### 3. Применить изменения

```bash
# Обновить Helm релиз
helm upgrade prometheus-kube-stack prometheus-community/kube-prometheus-stack \
  -n kube-prometheus-stack \
  -f helm/prom-kube-stack/prom-kube-stack-values.yaml
```

### 4. Перезапустить под Grafana (опционально)

```bash
kubectl rollout restart deployment kube-prometheus-stack-grafana -n kube-prometheus-stack
```

---

## Вариант 3: Изменение пароля через UI Grafana (после первого входа)

Если вы уже зашли в Grafana со стандартным паролем, можно изменить пароль через веб-интерфейс:

1. Войдите в Grafana: `https://grafana.buildbyte.ru`
2. Перейдите в **Administration → Users → admin**
3. Нажмите **Change Password**
4. Введите новый пароль
5. Нажмите **Change Password**

⚠️ **ВНИМАНИЕ:** При пересоздании пода Grafana пароль вернется к значению из values.yaml или Secret.

---

## Безопасность

### Рекомендации:

1. **Используйте Secret** вместо прямого указания пароля в values.yaml
2. **Храните Secret в безопасном месте** (например, в зашифрованном виде через Sealed Secrets или External Secrets)
3. **Не коммитьте пароли в Git** - используйте `.gitignore` для values.yaml с паролями или переменные окружения
4. **Ротация паролей** - периодически меняйте пароли администратора

### Использование Sealed Secrets (опционально)

Если используется Sealed Secrets:

```bash
# Создать Sealed Secret
kubectl create secret generic grafana-admin \
  --dry-run=client \
  --from-literal=admin-user=admin \
  --from-literal=admin-password=ваш-новый-пароль \
  -o yaml | kubeseal -o yaml > grafana-admin-sealed.yaml

# Применить Sealed Secret
kubectl apply -f grafana-admin-sealed.yaml -n kube-prometheus-stack
```

---

## Проверка текущего пароля

Если нужно проверить текущий пароль (из Secret):

```bash
# Получить пароль из Secret
kubectl get secret grafana-admin -n kube-prometheus-stack \
  -o jsonpath='{.data.admin-password}' | base64 -d

# Или если пароль хранится в Secret, созданном Helm chart
kubectl get secret kube-prometheus-stack-grafana -n kube-prometheus-stack \
  -o jsonpath='{.data.admin-password}' | base64 -d
```

---

## Устранение проблем

### Пароль не меняется

1. Проверьте, что Secret создан правильно:
   ```bash
   kubectl get secret grafana-admin -n kube-prometheus-stack -o yaml
   ```

2. Проверьте значения в values.yaml:
   ```bash
   grep -A 5 "admin:" helm/prom-kube-stack/prom-kube-stack-values.yaml
   ```

3. Перезапустите под Grafana:
   ```bash
   kubectl rollout restart deployment kube-prometheus-stack-grafana -n kube-prometheus-stack
   ```

4. Проверьте логи пода:
   ```bash
   kubectl logs -n kube-prometheus-stack deployment/kube-prometheus-stack-grafana
   ```

### Не могу войти с новым паролем

1. Проверьте, что Helm релиз обновлен:
   ```bash
   helm get values prometheus-kube-stack -n kube-prometheus-stack | grep -A 5 admin
   ```

2. Проверьте текущий Secret:
   ```bash
   kubectl get secret -n kube-prometheus-stack | grep grafana
   ```

3. Попробуйте пересоздать Secret и перезапустить под:
   ```bash
   kubectl delete secret grafana-admin -n kube-prometheus-stack
   # Создать Secret заново (см. Вариант 2)
   kubectl rollout restart deployment kube-prometheus-stack-grafana -n kube-prometheus-stack
   ```

---

## Ссылки

- [Grafana Helm Chart - Admin Credentials](https://github.com/grafana/helm-charts/blob/main/charts/grafana/values.yaml)
- [Kubernetes Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
