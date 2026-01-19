# Методы аутентификации в Vault

**Важно:** Root токен должен использоваться **только для начальной настройки**. Для ежедневного использования настройте альтернативные методы аутентификации.

## Доступные методы аутентификации

1. **Userpass** - username/password (для людей)
2. **Kubernetes** - через Kubernetes ServiceAccount (для приложений в K8s)
3. **AppRole** - для приложений и CI/CD
4. **LDAP/AD** - интеграция с корпоративной аутентификацией
5. **GitHub** - через GitHub OAuth
6. **OIDC** - через OpenID Connect провайдеры

---

## 1. Userpass Auth Method (Рекомендуется для людей)

### Настройка через UI

1. Откройте `https://vault.buildbyte.ru`
2. Войдите с root токеном
3. Перейдите в **Access → Auth Methods → Enable new method**
4. Выберите **Username & Password**
5. Path: `userpass` (или оставьте пустым)
6. Нажмите **Enable Method**

### Настройка через CLI

```bash
# Включить userpass auth method
kubectl exec -it vault-0 -n vault -- vault auth enable userpass

# Создать пользователя с политикой
kubectl exec -it vault-0 -n vault -- vault write auth/userpass/users/admin \
  password="my-secure-password" \
  policies="admin"
```

### Использование

**Через UI:**
1. На странице логина выберите **Username & Password** (или **Other** если указан кастомный path)
2. Введите username и password

**Через CLI:**
```bash
kubectl exec -it vault-0 -n vault -- vault login -method=userpass username=admin
# Введите password при запросе
```

### Управление пользователями

```bash
# Создать пользователя
kubectl exec -it vault-0 -n vault -- vault write auth/userpass/users/alice \
  password="password123" \
  policies="developer"

# Изменить пароль
kubectl exec -it vault-0 -n vault -- vault write auth/userpass/users/alice \
  password="new-password"

# Удалить пользователя
kubectl exec -it vault-0 -n vault -- vault delete auth/userpass/users/alice

# Просмотреть пользователей
kubectl exec -it vault-0 -n vault -- vault list auth/userpass/users
```

---

## 2. Kubernetes Auth Method (Рекомендуется для приложений в K8s)

**Преимущества:**
- Автоматическая аутентификация через ServiceAccount
- Не нужно хранить токены в коде
- Интеграция с RBAC Kubernetes

### Проверка настройки

В вашем `vault-values.yaml` уже включен `authDelegator: enabled: true`, что позволяет использовать Kubernetes Auth Method.

### Настройка через CLI

```bash
# 1. Включить kubernetes auth method
kubectl exec -it vault-0 -n vault -- vault auth enable kubernetes

# 2. Настроить kubernetes auth method (нужен токен сервисного аккаунта Kubernetes)
# Получить токен из ServiceAccount
SA_SECRET=$(kubectl get sa vault -n vault -o jsonpath='{.secrets[0].name}')
SA_TOKEN=$(kubectl get secret $SA_SECRET -n vault -o jsonpath='{.data.token}' | base64 -d)
K8S_HOST="https://kubernetes.default.svc.cluster.local"  # или ваш Kubernetes API server

# 3. Настроить kubernetes auth
kubectl exec -it vault-0 -n vault -- vault write auth/kubernetes/config \
  token_reviewer_jwt="${SA_TOKEN}" \
  kubernetes_host="${K8S_HOST}" \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

# Или более простой способ (Vault сам получит токен):
kubectl exec -it vault-0 -n vault -- sh -c 'vault write auth/kubernetes/config \
  token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
  kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443" \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt'
```

### Создание Role для Kubernetes Auth

```bash
# Создать роль для namespace default
kubectl exec -it vault-0 -n vault -- vault write auth/kubernetes/role/myapp \
  bound_service_account_names=default \
  bound_service_account_namespaces=default \
  policies=myapp-policy \
  ttl=1h

# Создать роль для конкретного ServiceAccount
kubectl exec -it vault-0 -n vault -- vault write auth/kubernetes/role/myapp \
  bound_service_account_names=myapp-sa \
  bound_service_account_namespaces=production \
  policies=myapp-policy \
  ttl=24h
```

### Использование в приложении

**В поде Kubernetes:**
```bash
# Аутентификация через ServiceAccount
kubectl exec -it <pod-name> -n <namespace> -- vault write auth/kubernetes/login \
  role=myapp \
  jwt=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)

# Ответ будет содержать client_token - используйте его для доступа к Vault
```

**Пример в коде (Go):**
```go
import "github.com/hashicorp/vault/api"

client, _ := api.NewClient(api.DefaultConfig())
client.SetAddress("http://vault.vault.svc.cluster.local:8200")

// Получить токен из ServiceAccount
saToken, _ := os.ReadFile("/var/run/secrets/kubernetes.io/serviceaccount/token")

// Аутентификация
secret, err := client.Logical().Write("auth/kubernetes/login", map[string]interface{}{
    "role": "myapp",
    "jwt":  string(saToken),
})
if err != nil {
    log.Fatal(err)
}

// Использовать токен
client.SetToken(secret.Auth.ClientToken)
```

---

## 3. AppRole Auth Method (Для CI/CD и приложений вне K8s)

### Настройка

```bash
# 1. Включить AppRole
kubectl exec -it vault-0 -n vault -- vault auth enable approle

# 2. Создать политику для приложения
kubectl exec -it vault-0 -n vault -- vault policy write myapp-policy - <<EOF
path "secret/data/myapp/*" {
  capabilities = ["read", "list"]
}
EOF

# 3. Создать AppRole
kubectl exec -it vault-0 -n vault -- vault write auth/approle/role/myapp \
  token_policies="myapp-policy" \
  token_ttl=1h \
  token_max_ttl=4h \
  bind_secret_id=true

# 4. Получить Role ID (публичный)
kubectl exec -it vault-0 -n vault -- vault read auth/approle/role/myapp/role-id

# 5. Получить Secret ID (приватный - сохранить безопасно)
kubectl exec -it vault-0 -n vault -- vault write -f auth/approle/role/myapp/secret-id
```

### Использование

```bash
# Логин с Role ID и Secret ID
vault write auth/approle/login \
  role_id=<role-id> \
  secret_id=<secret-id>

# Получить токен из ответа
```

---

## 4. LDAP Auth Method (Интеграция с Active Directory)

### Настройка

```bash
# 1. Включить LDAP
kubectl exec -it vault-0 -n vault -- vault auth enable ldap

# 2. Настроить подключение к LDAP/AD
kubectl exec -it vault-0 -n vault -- vault write auth/ldap/config \
  url="ldaps://ldap.company.com" \
  userdn="ou=Users,dc=company,dc=com" \
  userattr="sAMAccountName" \
  groupdn="ou=Groups,dc=company,dc=com" \
  groupattr="cn" \
  groupfilter="(&(objectClass=group)(member={{.UserDN}}))" \
  binddn="CN=vault,CN=Users,DC=company,DC=com" \
  bindpass="password"

# 3. Создать группы и привязать политики
kubectl exec -it vault-0 -n vault -- vault write auth/ldap/groups/developers \
  policies=developer-policy
```

### Использование

```bash
# Логин с LDAP credentials
vault write auth/ldap/login/<username> password=<password>
```

---

## 5. GitHub Auth Method

### Настройка

```bash
# 1. Включить GitHub
kubectl exec -it vault-0 -n vault -- vault auth enable github

# 2. Настроить GitHub Organization
kubectl exec -it vault-0 -n vault -- vault write auth/github/config organization=my-org

# 3. Настроить mapping группы GitHub на политику Vault
kubectl exec -it vault-0 -n vault -- vault write auth/github/map/teams/developers value=developer-policy
```

### Использование

```bash
# Логин с GitHub токеном
vault write auth/github/login token=<github-personal-access-token>
```

---

## Рекомендуемая структура настройки

### Для людей (администраторы, разработчики):

1. **Userpass** - основной метод
   ```bash
   vault auth enable userpass
   vault write auth/userpass/users/admin password="..." policies="admin"
   vault write auth/userpass/users/dev password="..." policies="developer"
   ```

### Для приложений:

1. **Kubernetes Auth** - для приложений в Kubernetes
   ```bash
   vault auth enable kubernetes
   # Настроить для каждого приложения отдельный role
   ```

2. **AppRole** - для CI/CD пайплайнов и внешних систем
   ```bash
   vault auth enable approle
   # Создать role для каждого сервиса
   ```

---

## Создание политик (Policies)

Перед настройкой аутентификации создайте политики для ограничения доступа:

```bash
# Создать политику для администратора
kubectl exec -it vault-0 -n vault -- vault policy write admin - <<EOF
# Полный доступ ко всему
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOF

# Создать политику для разработчика
kubectl exec -it vault-0 -n vault -- vault policy write developer - <<EOF
# Доступ к секретам приложения
path "secret/data/myapp/*" {
  capabilities = ["read", "list"]
}

# Доступ к KV v2 секретам (только чтение)
path "secret/metadata/myapp/*" {
  capabilities = ["list", "read"]
}
EOF

# Просмотреть политики
kubectl exec -it vault-0 -n vault -- vault policy list

# Просмотреть содержимое политики
kubectl exec -it vault-0 -n vault -- vault policy read admin
```

---

## Пример: Полная настройка для команды

```bash
# 1. Создать политики
vault policy write admin - <<EOF
path "*" { capabilities = ["create", "read", "update", "delete", "list", "sudo"] }
EOF

vault policy write developer - <<EOF
path "secret/data/myapp/*" { capabilities = ["read", "list"] }
path "secret/metadata/myapp/*" { capabilities = ["list", "read"] }
EOF

# 2. Включить userpass
vault auth enable userpass

# 3. Создать пользователей
vault write auth/userpass/users/admin password="secure-password" policies="admin"
vault write auth/userpass/users/alice password="password123" policies="developer"
vault write auth/userpass/users/bob password="password456" policies="developer"

# 4. Включить Kubernetes auth для приложений
vault auth enable kubernetes
vault write auth/kubernetes/config \
  token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
  kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443" \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

# 5. Создать role для Kubernetes
vault write auth/kubernetes/role/myapp \
  bound_service_account_names=default \
  bound_service_account_namespaces=default \
  policies=developer \
  ttl=1h
```

---

## Безопасность Root токена

После настройки альтернативных методов аутентификации:

1. **Удалить или ротировать root токен:**
   ```bash
   # Удалить текущий root токен (после создания альтернативных методов!)
   vault token revoke <root-token>
   ```

2. **Хранить root токен и unseal keys в безопасном месте:**
   - Менеджер паролей (1Password, Bitwarden)
   - Банковский сейф
   - HSM (Hardware Security Module)

3. **Использовать root токен только для:**
   - Первоначальной настройки
   - Восстановления после инцидентов
   - Критических операций администрирования

---

## Проверка активных методов аутентификации

```bash
# Список всех включенных auth methods
kubectl exec -it vault-0 -n vault -- vault auth list

# Детали конкретного метода
kubectl exec -it vault-0 -n vault -- vault read auth/userpass/config
```

---

## Ссылки

- [Vault Auth Methods](https://developer.hashicorp.com/vault/docs/auth)
- [Userpass Auth Method](https://developer.hashicorp.com/vault/docs/auth/userpass)
- [Kubernetes Auth Method](https://developer.hashicorp.com/vault/docs/auth/kubernetes)
- [AppRole Auth Method](https://developer.hashicorp.com/vault/docs/auth/approle)
- [LDAP Auth Method](https://developer.hashicorp.com/vault/docs/auth/ldap)
