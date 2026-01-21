# Настройка Kubernetes Auth в Vault для External Secrets Operator

Данная инструкция описывает процесс настройки Kubernetes аутентификации в Vault специально для работы с External Secrets Operator.

## Предварительные требования

- Vault установлен и разблокирован
- External Secrets Operator установлен
- Доступ к Vault pod через `kubectl`
- Root token Vault (для первоначальной настройки)

## Шаг 1: Проверка доступности и разблокировка Vault

**Важно:** Vault должен быть разблокирован (unsealed) перед настройкой Kubernetes auth и использованием External Secrets Operator!

```bash
# Проверить статус Vault pod
kubectl get pods -n vault

# Проверить статус Vault (запечатан или разблокирован)
kubectl exec -it vault-0 -n vault -- vault status
```

**Ожидаемый результат:** Vault должен быть в статусе `Sealed: false`

**Если Vault запечатан (`Sealed: true`), выполните разблокировку:**

```bash
# Получить unseal key (если еще не сохранен)
VAULT_UNSEAL_KEY=$(cat /tmp/vault-unseal-key.txt 2>/dev/null)

# Если unseal key не найден, получите его из файла инициализации
if [ -z "$VAULT_UNSEAL_KEY" ]; then
  echo "Unseal key не найден. Получите его из файла инициализации:"
  echo "cat /tmp/vault-init.json | jq -r '.unseal_keys_b64[0]' > /tmp/vault-unseal-key.txt"
  echo ""
  echo "Или инициализируйте Vault заново (если еще не инициализирован):"
  echo "kubectl exec -n vault vault-0 -- vault operator init -key-shares=1 -key-threshold=1 -format=json > /tmp/vault-init.json"
  exit 1
fi

# Разблокировать Vault
kubectl exec -it vault-0 -n vault -- vault operator unseal "$VAULT_UNSEAL_KEY"

# Проверить статус после разблокировки
kubectl exec -it vault-0 -n vault -- vault status
```

**Важно:**
- Vault должен быть разблокирован перед настройкой Kubernetes auth
- Vault должен оставаться разблокированным для работы External Secrets Operator
- Если Vault перезапускается, его нужно разблокировать снова

## Шаг 2: Аутентификация в Vault

Перед выполнением команд Vault необходимо аутентифицироваться с помощью root token.

```bash
# Установить адрес Vault
export VAULT_ADDR="http://127.0.0.1:8200"

# Получить root token (если еще не сохранен)
# Если вы инициализировали Vault ранее, используйте сохраненный токен
VAULT_ROOT_TOKEN=$(cat /tmp/vault-root-token.txt 2>/dev/null)

# Или получить root token из файла инициализации
if [ -z "$VAULT_ROOT_TOKEN" ]; then
  echo "Root token не найден. Получите его из файла инициализации или инициализируйте Vault:"
  echo "kubectl exec -n vault vault-0 -- vault operator init -key-shares=1 -key-threshold=1 -format=json | jq -r '.root_token'"
  exit 1
fi

# Установить root token
export VAULT_TOKEN="$VAULT_ROOT_TOKEN"

# Проверить аутентификацию
kubectl exec -it vault-0 -n vault -- sh -c "export VAULT_ADDR='http://127.0.0.1:8200' && export VAULT_TOKEN='$VAULT_TOKEN' && vault token lookup"
```

**Важно:**
- Root token необходим для первоначальной настройки Vault
- Если root token утерян, вам нужно будет переинициализировать Vault (это приведет к потере всех данных!)
- После настройки можно создать токен с ограниченными правами для повседневного использования

## Шаг 3: Получение токена ServiceAccount Vault

Vault использует токен своего ServiceAccount для проверки токенов других ServiceAccount.

В Kubernetes токен ServiceAccount автоматически монтируется в каждый pod по пути `/var/run/secrets/kubernetes.io/serviceaccount/token`.

```bash
# Получить токен напрямую из Vault pod
VAULT_SA_TOKEN=$(kubectl exec -n vault vault-0 -- cat /var/run/secrets/kubernetes.io/serviceaccount/token)

# Проверить, что токен получен
echo "Token length: ${#VAULT_SA_TOKEN}"
if [ ${#VAULT_SA_TOKEN} -eq 0 ]; then
  echo "Ошибка: Токен не получен!"
  exit 1
fi
```

**Важно:** 
- Сохраните этот токен — он понадобится на шаге 6
- Токен имеет ограниченный срок действия (обычно 1 час)
- Если токен истек, получите новый токен из файловой системы pod

## Шаг 4: Получение CA сертификата Kubernetes

Vault нужен CA сертификат для проверки подлинности Kubernetes API server.

```bash
# Получить CA сертификат из файловой системы Vault pod
K8S_CA_CERT=$(kubectl exec -n vault vault-0 -- cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt)

# Сохранить в файл для удобства
echo "$K8S_CA_CERT" > /tmp/k8s-ca.crt
```

**Проверка сертификата:**

```bash
# Проверить содержимое сертификата
cat /tmp/k8s-ca.crt | openssl x509 -text -noout | head -20
```

## Шаг 5: Определение адреса Kubernetes API Server

```bash
# Использовать стандартный адрес внутри кластера
K8S_HOST="https://kubernetes.default.svc"

echo "Kubernetes API Host: $K8S_HOST"
```

## Шаг 6: Включение Kubernetes Auth Method

**Важно:** Этот шаг должен быть выполнен ПЕРЕД настройкой конфигурации Kubernetes auth!

```bash
# Убедитесь, что переменные VAULT_ADDR и VAULT_TOKEN установлены
# (см. Шаг 2)

# Проверить, включен ли Kubernetes auth method
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault auth list | grep kubernetes || echo 'Kubernetes auth не включен'
"

# Включить Kubernetes auth method (если еще не включен)
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault auth enable kubernetes 2>&1 || echo 'Kubernetes auth уже включен или произошла ошибка'
"
```

**Если метод уже включен**, вы увидите ошибку:
```
Error enabling kubernetes auth: path is already in use at auth/kubernetes/
```

В этом случае пропустите этот шаг.

## Шаг 7: Настройка конфигурации Kubernetes Auth

Настройте Kubernetes auth, используя CA сертификат из pod:

**Шаг 7.1: Определить issuer Kubernetes кластера**

Перед настройкой конфигурации нужно определить issuer вашего Kubernetes кластера:

```bash
# Получить issuer из токена ServiceAccount
kubectl exec -n vault vault-0 -- cat /var/run/secrets/kubernetes.io/serviceaccount/token | \
  cut -d. -f2 | base64 -d 2>/dev/null | jq -r '.iss' 2>/dev/null || echo "Не удалось получить issuer из токена"

# Или получить issuer из конфигурации кластера
kubectl get --raw /.well-known/openid-configuration 2>/dev/null | jq -r '.issuer' || \
  echo "https://kubernetes.default.svc.cluster.local"
```

**Шаг 7.2: Настроить конфигурацию Kubernetes auth**

```bash
# Настроить Kubernetes auth (используя CA сертификат из pod)
# Если получаете ошибку "claim 'iss' is invalid", добавьте параметр disable_iss_validation=true
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault write auth/kubernetes/config \
  token_reviewer_jwt=\"\$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)\" \
  kubernetes_host=\"https://kubernetes.default.svc\" \
  kubernetes_ca_cert=\"\$(cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt)\" \
  disable_iss_validation=true
"
```

**Важно:** 
- Параметр `disable_iss_validation=true` отключает проверку issuer, что может быть необходимо для некоторых Kubernetes дистрибутивов (например, k0s)
- Если вы знаете точный issuer вашего кластера, можно указать его через параметр `issuer` вместо `disable_iss_validation`

**Проверка конфигурации:**

```bash
# С аутентификацией
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault read auth/kubernetes/config
"
```

**Ожидаемый результат:**
```
Key                                 Value
---                                 -----
disable_iss_validation              false
disable_local_ca_jwt                 false
issuer                              https://kubernetes.default.svc.cluster.local
kubernetes_ca_cert                  -----BEGIN CERTIFICATE-----...
kubernetes_host                     https://kubernetes.default.svc
local_jwt                           false
token_reviewer_jwt                  eyJhbGc...
```

## Шаг 8: Создание политики для External Secrets Operator

Создайте политику, которая определяет, к каким секретам имеет доступ External Secrets Operator:

```bash
# Убедитесь, что VAULT_TOKEN установлен (см. Шаг 2)
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault policy write external-secrets-policy - <<'EOF'
# Политика для External Secrets Operator
# Разрешает чтение секретов из всех путей secret/data/*

path \"secret/data/*\" {
  capabilities = [\"read\"]
}

# Для KV v2 секреты хранятся в secret/data/<path>
# External Secrets Operator будет иметь доступ ко всем секретам в secret/data/*
EOF
"
```

**Проверка политики:**

```bash
# С аутентификацией
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault policy read external-secrets-policy
"
```

## Шаг 9: Проверка ServiceAccount External Secrets Operator

Убедитесь, что ServiceAccount для External Secrets Operator существует:

```bash
# Проверить ServiceAccount
kubectl get sa external-secrets -n external-secrets-system

# Если ServiceAccount не существует, он будет создан автоматически при установке External Secrets Operator
# Проверить установку External Secrets Operator
kubectl get pods -n external-secrets-system
```

## Шаг 10: Создание роли в Vault для External Secrets Operator

Свяжите ServiceAccount External Secrets Operator с политикой через роль:

```bash
# Убедитесь, что VAULT_TOKEN установлен (см. Шаг 2)
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault write auth/kubernetes/role/external-secrets-operator \
  bound_service_account_names=external-secrets \
  bound_service_account_namespaces=external-secrets-system \
  policies=external-secrets-policy \
  ttl=1h
"
```

**Параметры:**
- `bound_service_account_names` — имя ServiceAccount External Secrets Operator (`external-secrets`)
- `bound_service_account_namespaces` — namespace External Secrets Operator (`external-secrets-system`)
- `policies` — политики Vault для этой роли (`external-secrets-policy`)
- `ttl` — время жизни токена (например, `1h`, `24h`)

**Проверка роли:**

```bash
# С аутентификацией
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault read auth/kubernetes/role/external-secrets-operator
"
```

**Ожидаемый результат:**
```
Key                                 Value
---                                 -----
bound_service_account_names         [external-secrets]
bound_service_account_namespaces    [external-secrets-system]
policies                            [external-secrets-policy]
ttl                                 1h
```

## Шаг 11: Применение ClusterSecretStore

После настройки Kubernetes auth в Vault, примените ClusterSecretStore:

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

# Если CRD не установлены, установите External Secrets Operator:
# helm repo add external-secrets https://charts.external-secrets.io
# helm repo update
# helm upgrade --install external-secrets external-secrets/external-secrets \
#   --namespace external-secrets-system \
#   --create-namespace \
#   -f helm/external-secrets/external-secrets-values.yaml

# 3. Дождаться готовности External Secrets Operator
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=external-secrets -n external-secrets-system --timeout=300s

# 4. Применить ClusterSecretStore
kubectl apply -f manifests/external-secrets/vault-cluster-secret-store.yaml

# 5. Проверить ClusterSecretStore
kubectl get clustersecretstore
kubectl describe clustersecretstore vault
```

**Ожидаемый результат:**
```
NAME           AGE   STATUS   CAPABILITY   PROVIDER
vault  ...   Valid    ReadWrite    Vault
```

## Шаг 12: Тестирование подключения

Протестируйте подключение External Secrets Operator к Vault:

**Шаг 12.1: Включить KV v2 секретный движок (если еще не включен)**

Перед созданием секретов необходимо убедиться, что KV v2 секретный движок включен:

```bash
# Убедитесь, что переменные установлены (см. Шаг 2)
export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_TOKEN=$(cat /tmp/vault-root-token.txt)

# Проверить, включен ли секретный движок secret/
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault secrets list | grep secret/ || echo 'Секретный движок secret/ не найден'
"

# Если секретный движок не включен, включить KV v2
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault secrets enable -version=2 -path=secret kv 2>&1 || echo 'Секретный движок уже включен или произошла ошибка'
"
```

**Шаг 12.2: Создать тестовый секрет в Vault**

После включения секретного движка создайте тестовый секрет:

```bash
# Убедитесь, что переменные установлены (см. Шаг 2)
export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_TOKEN=$(cat /tmp/vault-root-token.txt)

# Создать тестовый секрет в Vault
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault kv put secret/test value='test-secret-value'
"

# Проверить, что секрет создан
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault kv get secret/test
"
```

**Шаг 12.2: Проверить статус External Secrets Operator**

```bash
# Проверить статус External Secrets Operator
kubectl get pods -n external-secrets-system

# Проверить логи External Secrets Operator на наличие ошибок подключения к Vault
kubectl logs -n external-secrets-system -l app.kubernetes.io/name=external-secrets | grep -i vault
```

**Шаг 12.3: Создать тестовый ExternalSecret**

```bash
# Создать тестовый ExternalSecret для проверки
cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: test-vault-connection
  namespace: default
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault
    kind: ClusterSecretStore
  target:
    name: test-secret
    creationPolicy: Owner
  data:
    - secretKey: test-key
      remoteRef:
        key: secret/test
        property: value
EOF

# Проверить статус ExternalSecret
kubectl get externalsecret test-vault-connection -n default
kubectl describe externalsecret test-vault-connection -n default
```

**Если ExternalSecret успешно синхронизирован**, вы увидите:
```
Status:
  Conditions:
    Status:  True
    Type:    Ready
```

**Если ExternalSecret имеет статус `SecretSyncedError`**, проверьте раздел "Проверка и устранение неполадок" ниже.

## Проверка и устранение неполадок

### Проверить список включенных auth methods

```bash
# С аутентификацией
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault auth list
"
```

Должен быть включен метод `kubernetes/`.

### Проверить конфигурацию Kubernetes auth

```bash
# С аутентификацией
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault read auth/kubernetes/config
"
```

### Проверить список ролей

```bash
# С аутентификацией
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault list auth/kubernetes/role
"
```

### Проверить конкретную роль

```bash
# С аутентификацией
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault read auth/kubernetes/role/external-secrets-operator
"
```

### Проверить политику

```bash
# С аутентификацией
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault policy read external-secrets-policy
"
```

### Частые ошибки

**Проблема: "permission denied" при создании роли**

**Решение:**
- Убедитесь, что используете root token или токен с правами на создание ролей
- Проверьте, что `authDelegator` включен в Helm values Vault (`server.authDelegator.enabled: true`)

**Проблема: "invalid token" при настройке конфигурации**

**Решение:**
- Проверьте правильность токена ServiceAccount Vault
- Убедитесь, что токен не истек
- Попробуйте получить токен заново

**Проблема: "connection refused" при подключении к Kubernetes API**

**Решение:**
- Проверьте доступность Kubernetes API server: `kubectl cluster-info`
- Убедитесь, что используется правильный адрес (`https://kubernetes.default.svc` для внутри кластера)

**Проблема: "preflight capability check returned 403" при создании секрета**

**Симптомы:**
- Ошибка: `preflight capability check returned 403, please ensure client's policies grant access to path "secret/test/"`
- При выполнении `vault kv put secret/test`

**Решение:**
Это означает, что KV v2 секретный движок не включен или не настроен. Выполните:

```bash
# Убедитесь, что переменные установлены
export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_TOKEN=$(cat /tmp/vault-root-token.txt)

# Включить KV v2 секретный движок
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault secrets enable -version=2 -path=secret kv
"

# Проверить, что движок включен
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault secrets list
"
```

После включения секретного движка можно создавать секреты.

**Проблема: External Secrets Operator не может подключиться к Vault**

**Решение:**
1. Проверьте ClusterSecretStore:
   ```bash
   kubectl describe clustersecretstore vault
   ```

2. Проверьте логи External Secrets Operator:
   ```bash
   kubectl logs -n external-secrets-system -l app.kubernetes.io/name=external-secrets | grep -i error
   ```

3. Проверьте, что роль создана правильно:
   ```bash
   kubectl exec -it vault-0 -n vault -- sh -c "
   export VAULT_ADDR='http://127.0.0.1:8200'
   export VAULT_TOKEN='$VAULT_TOKEN'
   vault read auth/kubernetes/role/external-secrets-operator
   "
   ```

4. Проверьте, что ServiceAccount существует:
   ```bash
   kubectl get sa external-secrets -n external-secrets-system
   ```

**Проблема: ExternalSecret не синхронизируется (SecretSyncedError)**

**Симптомы:**
- Статус ExternalSecret: `SecretSyncedError`
- Ready: `False`
- В Events: `error processing spec.data[0] (key: secret/test), err: Secret does not exist`

**Решение:**
1. **Проверьте статус ExternalSecret:**
   ```bash
   kubectl describe externalsecret <name> -n <namespace>
   ```

2. **Проверьте, что секрет существует в Vault:**
   ```bash
   # Убедитесь, что переменные установлены
   export VAULT_ADDR="http://127.0.0.1:8200"
   export VAULT_TOKEN=$(cat /tmp/vault-root-token.txt)
   
   # Проверить существование секрета
   kubectl exec -it vault-0 -n vault -- sh -c "
   export VAULT_ADDR='http://127.0.0.1:8200'
   export VAULT_TOKEN='$VAULT_TOKEN'
   vault kv get secret/test
   "
   ```

   **Если секрет не существует**, создайте его:
   ```bash
   # Сначала убедитесь, что KV v2 секретный движок включен
   kubectl exec -it vault-0 -n vault -- sh -c "
   export VAULT_ADDR='http://127.0.0.1:8200'
   export VAULT_TOKEN='$VAULT_TOKEN'
   vault secrets enable -version=2 -path=secret kv 2>&1 || echo 'Секретный движок уже включен'
   "
   
   # Затем создайте секрет
   kubectl exec -it vault-0 -n vault -- sh -c "
   export VAULT_ADDR='http://127.0.0.1:8200'
   export VAULT_TOKEN='$VAULT_TOKEN'
   vault kv put secret/test value='test-secret-value'
   "
   ```

3. **Проверьте путь к секрету в ExternalSecret:**
   - Для KV v2 секреты хранятся в `secret/data/<path>`
   - В ExternalSecret используйте путь `secret/<path>` (без `/data/`)
   - Пример: если секрет в Vault по пути `secret/data/test`, в ExternalSecret укажите `key: secret/test`

4. **Проверьте политику в Vault (должна разрешать чтение нужного пути):**
   ```bash
   kubectl exec -it vault-0 -n vault -- sh -c "
   export VAULT_ADDR='http://127.0.0.1:8200'
   export VAULT_TOKEN='$VAULT_TOKEN'
   vault policy read external-secrets-policy
   "
   ```

5. **Проверьте логи External Secrets Operator:**
   ```bash
   kubectl logs -n external-secrets-system -l app.kubernetes.io/name=external-secrets | tail -50
   ```

## Дополнительные настройки

### Ограничение доступа по namespace

Если нужно ограничить доступ External Secrets Operator только определенными namespace:

```bash
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault write auth/kubernetes/role/external-secrets-operator \
  bound_service_account_names=external-secrets \
  bound_service_account_namespaces=external-secrets-system,default,keycloak \
  policies=external-secrets-policy \
  ttl=1h
"
```

### Использование нескольких ServiceAccount

Если External Secrets Operator использует несколько ServiceAccount:

```bash
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault write auth/kubernetes/role/external-secrets-operator \
  bound_service_account_names=external-secrets,external-secrets-readonly \
  bound_service_account_namespaces=external-secrets-system \
  policies=external-secrets-policy \
  ttl=1h
"
```

### Настройка более строгой политики

Если нужно ограничить доступ только к определенным путям:

```bash
kubectl exec -it vault-0 -n vault -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='$VAULT_TOKEN'
vault policy write external-secrets-policy - <<'EOF'
# Доступ только к секретам приложений
path \"secret/data/keycloak/*\" {
  capabilities = [\"read\"]
}

path \"secret/data/grafana/*\" {
  capabilities = [\"read\"]
}

path \"secret/data/apps/*\" {
  capabilities = [\"read\"]
}
EOF
"
```

## Проверка работоспособности

После успешной настройки:

1. Проверьте, что ClusterSecretStore имеет статус `Valid`:
   ```bash
   kubectl get clustersecretstore vault
   ```

2. Создайте тестовый ExternalSecret и убедитесь, что он синхронизируется

3. Проверьте логи External Secrets Operator на отсутствие ошибок подключения к Vault

4. Убедитесь, что секреты создаются в нужных namespace

## Следующие шаги

После настройки Kubernetes auth для External Secrets Operator:

1. Сохраните секреты в Vault (например, для Keycloak, Grafana и т.д.)
2. Создайте ExternalSecret ресурсы для синхронизации секретов
3. Проверьте, что секреты синхронизируются корректно

**Пример сохранения секрета в Vault:**

```bash
# Подключиться к Vault
export VAULT_ADDR="http://vault.vault.svc.cluster.local:8200"
export VAULT_TOKEN="<ваш-root-token>"

# Убедиться, что KV v2 секретный движок включен
vault secrets enable -version=2 -path=secret kv 2>&1 || echo 'Секретный движок уже включен'

# Сохранить секрет
vault kv put secret/keycloak/postgresql \
  username=keycloak \
  password='<пароль>' \
  database=keycloak
```

Готово! Kubernetes auth в Vault настроен для работы с External Secrets Operator.
