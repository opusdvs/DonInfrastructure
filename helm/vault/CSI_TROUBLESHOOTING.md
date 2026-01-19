# Устранение проблем с CSI драйвером для Vault

## Ошибка: "Drive has mount"

**Симптомы:**
```
AttachVolume.Attach failed for volume "pvc-xxx" : rpc error: code = Unknown desc = 
ControllerPublishVolume api mount needed. Disk mounts: [{6423277 server}]. 
Error: request error! response body: {"status_code":400,"error_code":"drive_has_mount",
"message":"Drive has mount","response_id":"xxx"} Response code: 400
```

**Причина:** Диск уже смонтирован на сервере (ID: 6423277) и не может быть повторно прикреплен к поду.

## Решение

### Шаг 1: Проверка состояния PVC и подов

```bash
# Проверка всех PVC в namespace vault
kubectl get pvc -n vault

# Проверка подов Vault
kubectl get pods -n vault

# Детальная информация о проблемном PVC
kubectl describe pvc <pvc-name> -n vault
```

### Шаг 2: Удаление проблемных подов и PVC

Если поды не запускаются из-за проблемы с volume:

```bash
# Удаление всех подов Vault (они пересоздадутся автоматически)
kubectl delete pods -n vault -l app.kubernetes.io/name=vault

# Если проблема сохраняется, удалите проблемный PVC
# ВНИМАНИЕ: Это удалит данные! Используйте только если данные не критичны
kubectl delete pvc <pvc-name> -n vault
```

### Шаг 3: Проверка узлов и availability zones

Проблема может быть связана с несоответствием availability zones:

```bash
# Проверка узлов и их zones
kubectl get nodes -o wide

# Проверка, на каком узле должен быть под
kubectl get pod <pod-name> -n vault -o jsonpath='{.spec.nodeName}'

# Проверка zone узла
kubectl get node <node-name> -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}'
```

### Шаг 4: Проверка логов CSI драйвера

```bash
# Проверка подов CSI драйвера
kubectl get pods -n kube-system | grep csi

# Логи CSI контроллера
kubectl logs -n kube-system -l app=csi-timeweb-controller --tail=100

# Логи CSI node драйвера на проблемном узле
kubectl logs -n kube-system -l app=csi-timeweb-node --tail=100
```

### Шаг 5: Ручное отключение диска через Timeweb Cloud API

Если диск остался прикрепленным на уровне облака:

1. Войдите в панель Timeweb Cloud
2. Перейдите в раздел "Диски" (Network Drives)
3. Найдите диск с ID из ошибки (или по размеру 10Gi/5Gi)
4. Отключите диск от сервера, если он прикреплен
5. Подождите несколько минут и попробуйте снова

### Шаг 6: Перезапуск CSI драйвера

```bash
# Перезапуск CSI контроллера
kubectl rollout restart deployment -n kube-system csi-timeweb-controller

# Перезапуск CSI node драйвера на всех узлах
kubectl rollout restart daemonset -n kube-system csi-timeweb-node

# Ожидание готовности
kubectl rollout status deployment -n kube-system csi-timeweb-controller
kubectl rollout status daemonset -n kube-system csi-timeweb-node
```

### Шаг 7: Очистка и переустановка Vault (крайний случай)

Если ничего не помогает:

```bash
# Удаление Helm релиза Vault
helm uninstall vault -n vault

# Удаление всех PVC (ВНИМАНИЕ: удалит данные!)
kubectl delete pvc -n vault --all

# Ожидание полного удаления
kubectl get pvc -n vault

# Переустановка Vault
helm install vault hashicorp/vault \
  -n vault \
  --create-namespace \
  -f helm/vault/vault-values.yaml
```

## Профилактика

### 1. Использование правильного StorageClass

Убедитесь, что в `vault-values.yaml` указан правильный StorageClass:

```yaml
dataStorage:
  storageClass: nvme.network-drives.csi.timeweb.cloud  # или ваш StorageClass
```

### 2. Проверка availability zones

Убедитесь, что все узлы кластера находятся в одной availability zone или что StorageClass поддерживает cross-zone mounting.

### 3. Мониторинг состояния PVC

Регулярно проверяйте состояние PVC:

```bash
# Проверка статуса всех PVC
kubectl get pvc -A

# Проверка событий, связанных с PVC
kubectl get events -A --field-selector involvedObject.kind=PersistentVolumeClaim
```

## Дополнительная информация

- [Документация Timeweb Cloud CSI](https://timeweb.cloud/docs/)
- [Kubernetes Volume Troubleshooting](https://kubernetes.io/docs/tasks/debug/debug-application/debug-persistent-volume-claims/)
