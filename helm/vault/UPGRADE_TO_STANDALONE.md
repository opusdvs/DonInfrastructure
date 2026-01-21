# Переключение Vault с HA режима на Standalone режим

**ВНИМАНИЕ: Это временный тестовый режим для разработки!**

При переключении Vault с HA режима (Raft storage) на Standalone режим (file storage) необходимо пересоздать StatefulSet, так как Kubernetes не позволяет изменять storage backend после создания.

**Важно:** В продакшене будет настроен полноценный HA кластер с Raft storage и 3 репликами для обеспечения высокой доступности.

## Важно перед началом

1. **Сделайте backup данных Vault** (если есть важные данные)
2. **Сохраните unseal keys и root token** (если они еще не сохранены)
3. **Убедитесь, что у вас есть доступ к unseal keys** для разблокировки после переустановки

## Шаг 1: Сохранение важных данных

```bash
# Сохранить unseal key и root token (если еще не сохранены)
cat /tmp/vault-unseal-key.txt
cat /tmp/vault-root-token.txt

# Если файлы не существуют, получите их из текущего Vault
# (требуется доступ к текущему Vault)
```

## Шаг 2: Удаление Helm release с сохранением PVC

**Важно:** Мы удаляем только Helm release, но сохраняем PersistentVolumeClaim (PVC) с данными.

```bash
# Проверить существующие PVC
kubectl get pvc -n vault

# Удалить Helm release (PVC останутся)
helm uninstall vault --namespace vault

# Проверить, что PVC остались
kubectl get pvc -n vault
```

## Шаг 3: Очистка StatefulSet (если остался)

Если StatefulSet не удалился автоматически:

```bash
# Проверить StatefulSet
kubectl get statefulset -n vault

# Удалить StatefulSet вручную (если существует)
kubectl delete statefulset vault -n vault

# Удалить Pod (если остался)
kubectl delete pod vault-0 -n vault --force --grace-period=0
```

## Шаг 4: Переустановка Vault в Standalone режиме

```bash
# Добавить Helm репозиторий (если еще не добавлен)
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# Установить Vault в standalone режиме
helm upgrade --install vault hashicorp/vault \
  --namespace vault \
  --create-namespace \
  -f helm/vault/vault-values.yaml

# Проверить установку
kubectl get pods -n vault
kubectl get statefulset -n vault
```

## Шаг 5: Инициализация Vault

После переустановки Vault нужно инициализировать заново (так как используется новый storage backend):

```bash
# Проверить статус Vault
kubectl exec -it vault-0 -n vault -- vault status

# Если Vault не инициализирован (Not Initialized: true), выполните инициализацию
kubectl exec -n vault vault-0 -- vault operator init -key-shares=1 -key-threshold=1 -format=json > /tmp/vault-init-new.json

# Сохранить новые unseal key и root token
cat /tmp/vault-init-new.json | jq -r '.unseal_keys_b64[0]' > /tmp/vault-unseal-key.txt
cat /tmp/vault-init-new.json | jq -r '.root_token' > /tmp/vault-root-token.txt

# Разблокировать Vault
kubectl exec -it vault-0 -n vault -- vault operator unseal $(cat /tmp/vault-unseal-key.txt)

# Проверить статус после разблокировки
kubectl exec -it vault-0 -n vault -- vault status
```

**Важно:**
- После переустановки в standalone режиме Vault будет не инициализирован
- Старые unseal keys и root token не будут работать (так как используется новый storage backend)
- Нужно сохранить новые unseal key и root token для дальнейшего использования

## Шаг 6: Восстановление данных (если нужно)

Если у вас были данные в старом Vault, их нужно восстановить вручную:

```bash
# Подключиться к новому Vault
export VAULT_ADDR="http://vault.vault.svc.cluster.local:8200"
export VAULT_TOKEN="$(cat /tmp/vault-root-token.txt)"

# Восстановить секреты (пример)
# vault kv put secret/keycloak/postgresql username=keycloak password='<пароль>' database=keycloak
```

**Примечание:** Если данные были в Raft storage (HA режим), они не переносятся автоматически в file storage (standalone режим). Нужно экспортировать данные из старого Vault перед переустановкой и импортировать их в новый Vault после инициализации.

## Альтернативный подход: Миграция данных

Если нужно сохранить данные из Raft storage в file storage:

1. **Экспорт данных из HA Vault:**
   ```bash
   # Подключиться к текущему Vault
   export VAULT_ADDR="http://vault.vault.svc.cluster.local:8200"
   export VAULT_TOKEN="<root-token>"
   
   # Экспортировать секреты (пример)
   vault kv list secret/ > /tmp/vault-secrets-list.txt
   ```

2. **После переустановки в Standalone режиме:**
   ```bash
   # Импортировать данные в новый Vault
   # (выполнить для каждого секрета)
   vault kv put secret/<path> <key>=<value>
   ```

## Важные замечания

1. **Это временный тестовый режим для разработки!** В продакшене будет настроен полноценный HA кластер с Raft storage и 3 репликами для обеспечения высокой доступности
2. **Standalone режим не обеспечивает высокую доступность** - при падении pod Vault будет недоступен
3. **Данные хранятся в PVC** - убедитесь, что PVC не удаляется
4. **После переустановки нужно заново настроить:**
   - Kubernetes auth (если был настроен)
   - Политики и роли
   - Секреты (если не были сохранены в PVC)
5. **При переходе в продакшен** будет необходимо переключиться обратно на HA режим с Raft storage

## Откат изменений

Если нужно вернуться к HA режиму:

1. Измените `helm/vault/vault-values.yaml`:
   ```yaml
   ha:
     enabled: true
     replicas: 3
   standalone:
     enabled: false
   ```

2. Выполните шаги 2-4 выше (удаление и переустановка)

## Проверка после переустановки

```bash
# Проверить статус Vault
kubectl exec -it vault-0 -n vault -- vault status

# Проверить конфигурацию
kubectl exec -it vault-0 -n vault -- cat /vault/config/extraconfig-from-values.hcl

# Проверить, что используется file storage (должно быть storage "file")
kubectl exec -it vault-0 -n vault -- cat /vault/config/extraconfig-from-values.hcl | grep storage
```

Готово! Vault теперь работает в Standalone режиме с одной репликой.
