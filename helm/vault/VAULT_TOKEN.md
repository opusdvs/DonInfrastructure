# Получение токена для входа в Vault

## Способ 1: Инициализация Vault и получение Initial Root Token

Если Vault еще не инициализирован, выполните инициализацию:

```bash
# Найти под Vault
kubectl get pods -n vault

# Подключиться к поду Vault (любому из реплик в HA режиме)
kubectl exec -it vault-0 -n vault -- sh

# Инициализировать Vault
vault operator init

# Вывод команды будет содержать:
# - Initial Root Token (только один раз!)
# - Unseal Keys (5 ключей)
```

**⚠️ ВАЖНО:** Сохраните Initial Root Token и Unseal Keys в безопасном месте (например, в менеджере паролей). Initial Root Token показывается только один раз при инициализации.

Пример вывода:
```
Unseal Key 1: abc123...
Unseal Key 2: def456...
...
Initial Root Token: hvs.CAESIFo...
```

## Способ 2: Проверка Secret в Kubernetes

После инициализации Helm chart Vault может сохранить токен в Kubernetes Secret:

```bash
# Проверить секреты в namespace vault
kubectl get secrets -n vault

# Если есть секрет с токеном (обычно vault-keys или vault-initial-root-token)
kubectl get secret vault-keys -n vault -o jsonpath='{.data.root-token}' | base64 -d
# или
kubectl get secret vault-initial-root-token -n vault -o jsonpath='{.data.token}' | base64 -d
```

## Способ 3: Использование токена для входа

### Через веб-интерфейс

1. Откройте Vault UI: `https://vault.buildbyte.ru`
2. Введите Initial Root Token
3. Нажмите "Sign In"

### Через CLI

```bash
# Вариант 1: Через port-forward (если не используете Gateway API)
kubectl port-forward -n vault svc/vault 8200:8200

# В другом терминале установите переменные окружения
export VAULT_ADDR='http://127.0.0.1:8200'

# Войдите с токеном
vault login <your-root-token>
```

```bash
# Вариант 2: Через exec в поде
kubectl exec -it vault-0 -n vault -- vault login

# Введите токен при запросе
```

```bash
# Вариант 3: Прямой вход с токеном через exec
kubectl exec -it vault-0 -n vault -- vault login <your-root-token>
```

## Способ 4: Генерация нового Root Token (если токен утерян)

Если Initial Root Token был утерян, можно сгенерировать новый, используя Unseal Keys:

```bash
# Подключиться к поду Vault
kubectl exec -it vault-0 -n vault -- sh

# Начать генерацию нового root токена
vault operator generate-root -init

# Это вернет OTP (One-Time Password) и Nonce

# Для каждого unseal key (нужно минимум 3 из 5 для HA):
vault operator generate-root -nonce=<nonce-from-init> -unseal-key=<unseal-key-1>
vault operator generate-root -nonce=<nonce-from-init> -unseal-key=<unseal-key-2>
vault operator generate-root -nonce=<nonce-from-init> -unseal-key=<unseal-key-3>

# После ввода достаточного количества ключей получите Encoded Token
# Декодируйте его:
vault operator generate-root -decode=<encoded-token> -otp=<otp-from-init>

# Это вернет новый root токен
```

## Проверка статуса Vault

Перед получением токена убедитесь, что Vault инициализирован и разблокирован (unsealed):

```bash
# Проверить статус Vault
kubectl exec -it vault-0 -n vault -- vault status

# Если Vault не инициализирован:
# Initialized: false

# Если Vault заблокирован (sealed):
# Sealed: true
```

## Unseal Vault (если заблокирован)

Если Vault заблокирован, нужно разблокировать его перед использованием:

```bash
# Разблокировать Vault (нужно минимум 3 из 5 unseal keys для HA с 3 репликами)
kubectl exec -it vault-0 -n vault -- vault operator unseal <unseal-key-1>
kubectl exec -it vault-0 -n vault -- vault operator unseal <unseal-key-2>
kubectl exec -it vault-0 -n vault -- vault operator unseal <unseal-key-3>

# Проверить статус
kubectl exec -it vault-0 -n vault -- vault status
```

## Безопасность

⚠️ **ВАЖНЫЕ МЕРЫ БЕЗОПАСНОСТИ:**

1. **Initial Root Token** - имеет полные права. Используйте его только для:
   - Первой настройки Vault
   - Создания пользователей и политик
   - Настройки аутентификации

2. **После настройки:**
   - Создайте пользователей с ограниченными правами
   - Используйте обычные токены или другие методы аутентификации (Kubernetes, AppRole, LDAP и т.д.)
   - Ротация root токена: `vault token revoke <root-token>` после создания обычных токенов

3. **Хранение ключей:**
   - Храните Unseal Keys и Root Token в безопасном месте (менеджер паролей, HSM, банковский сейф)
   - Не храните в Git или незашифрованном виде
   - Распределите ключи между несколькими администраторами

## Пример: Быстрая проверка и вход

```bash
# 1. Проверить статус
kubectl exec -it vault-0 -n vault -- vault status

# 2. Если Vault инициализирован и разблокирован - получить токен из секрета или использовать сохраненный
export VAULT_TOKEN=$(kubectl get secret vault-keys -n vault -o jsonpath='{.data.root-token}' 2>/dev/null | base64 -d || echo "токен-не-в-секрете")

# 3. Войти через веб-интерфейс или CLI
# Веб: https://vault.buildbyte.ru
# CLI: vault login $VAULT_TOKEN (через port-forward или exec)
```

## Ссылки

- [Vault Initialization](https://developer.hashicorp.com/vault/docs/commands/operator/init)
- [Vault Authentication](https://developer.hashicorp.com/vault/docs/auth)
- [Generate Root Token](https://developer.hashicorp.com/vault/docs/troubleshoot/generate-root-token)
