# Устранение проблемы с Raft storage в Vault

## Ошибка: "failed to create fsm: open /vault/data/vault.db: no such file or directory"

**Причина:** Vault не может создать файл `vault.db` в директории `/vault/data`, потому что:
1. Директория не существует
2. Нет прав доступа на запись
3. PVC не смонтирован правильно

## Решение 1: Проверка конфигурации

Убедитесь, что в `vault-values.yaml` настроено:

```yaml
server:
  ha:
    enabled: true
    replicas: 3
    raft:
      enabled: true
      setNodeId: true
    config: |
      storage "raft" {
        path = "/vault/data"
      }
  
  dataStorage:
    enabled: true
    size: 10Gi
    storageClass: nvme.network-drives.csi.timeweb.cloud
    accessMode: ReadWriteOnce
    mountPath: /vault/data
```

## Решение 2: Проверка состояния PVC и подов

```bash
# Проверка PVC
kubectl get pvc -n vault

# Проверка подов
kubectl get pods -n vault

# Детальная информация о поде
kubectl describe pod <pod-name> -n vault

# Проверка, что volume смонтирован
kubectl exec -it <pod-name> -n vault -- ls -la /vault/data
```

## Решение 3: Ручное создание директории (временное решение)

Если initContainer не работает, можно вручную создать директорию:

```bash
# Подключитесь к поду
kubectl exec -it <pod-name> -n vault -- sh

# Создайте директорию и установите права
mkdir -p /vault/data
chown -R 100:1000 /vault/data
chmod -R 755 /vault/data
```

## Решение 4: Использование extraInitContainers

Если Helm chart поддерживает `extraInitContainers`, добавьте в `vault-values.yaml`:

```yaml
server:
  extraInitContainers: |
    - name: volume-permissions
      image: busybox:1.35
      command: ['sh', '-c']
      args:
        - |
          mkdir -p /vault/data
          chown -R 100:1000 /vault/data
          chmod -R 755 /vault/data
      securityContext:
        runAsUser: 0
      volumeMounts:
        - name: data
          mountPath: /vault/data
```

**ВНИМАНИЕ:** Не все версии Helm chart Vault поддерживают `extraInitContainers`. Проверьте документацию вашей версии.

## Решение 5: Проверка прав доступа

Vault обычно запускается от пользователя `vault` (UID 100, GID 1000). Убедитесь, что:

```bash
# Проверка пользователя в поде
kubectl exec -it <pod-name> -n vault -- id

# Проверка прав на директорию
kubectl exec -it <pod-name> -n vault -- ls -ld /vault/data
```

## Решение 6: Переустановка с правильной конфигурацией

Если ничего не помогает:

```bash
# Удаление Helm релиза
helm uninstall vault -n vault

# Удаление PVC (ВНИМАНИЕ: удалит данные!)
kubectl delete pvc -n vault --all

# Переустановка с правильной конфигурацией
helm install vault hashicorp/vault \
  -n vault \
  --create-namespace \
  -f helm/vault/vault-values.yaml
```

## Решение 7: Использование патча для StatefulSet

Если `extraInitContainers` не поддерживается, можно использовать `kubectl patch`:

```bash
# Создайте патч для StatefulSet
kubectl patch statefulset vault -n vault --type='json' \
  -p='[
    {
      "op": "add",
      "path": "/spec/template/spec/initContainers",
      "value": [
        {
          "name": "volume-permissions",
          "image": "busybox:1.35",
          "command": ["sh", "-c"],
          "args": ["mkdir -p /vault/data && chown -R 100:1000 /vault/data && chmod -R 755 /vault/data"],
          "securityContext": {"runAsUser": 0},
          "volumeMounts": [{"name": "data", "mountPath": "/vault/data"}]
        }
      ]
    }
  ]'
```

## Проверка после исправления

После применения любого из решений:

```bash
# Проверка логов подов
kubectl logs <pod-name> -n vault

# Проверка статуса Vault
kubectl exec -it <pod-name> -n vault -- vault status

# Проверка, что файл vault.db создан
kubectl exec -it <pod-name> -n vault -- ls -la /vault/data
```

## Дополнительная информация

- [Vault Raft Storage Documentation](https://developer.hashicorp.com/vault/docs/configuration/storage/raft)
- [Vault Helm Chart Documentation](https://developer.hashicorp.com/vault/docs/platform/k8s/helm)
