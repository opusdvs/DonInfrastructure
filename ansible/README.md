# Ansible для установки NFS сервера

Минимальная Ansible роль для установки и настройки NFS сервера.

## Структура

```
ansible/
├── ansible.cfg          # Конфигурация Ansible
├── inventory.yml        # Inventory с адресами серверов
├── playbook.yml        # Основной плейбук
└── roles/
    ├── users/            # Роль для создания пользователей
    │   ├── defaults/
    │   │   └── main.yml
    │   └── tasks/
    │       └── main.yml
    └── nfs-server/      # Роль для установки NFS сервера
        ├── defaults/
        │   └── main.yml    # Переменные по умолчанию
        ├── handlers/
        │   └── main.yml    # Handlers для перезапуска сервисов
        └── tasks/
            └── main.yml    # Основные задачи
```

## Использование

### 1. Настройка inventory

Отредактируйте `inventory.yml` и укажите:
- IP адрес сервера (уже указан: 89.19.215.138)
- Пользователя для подключения (по умолчанию: root)
- Путь к SSH ключу (если используется)

### 2. Запуск плейбука

```bash
# Проверка подключения
ansible nfs_servers -m ping

# Запуск плейбука
ansible-playbook playbook.yml

# Запуск с указанием inventory
ansible-playbook -i inventory.yml playbook.yml

# Запуск с проверкой (dry-run)
ansible-playbook --check playbook.yml
```

### 3. Настройка переменных

Переменные можно переопределить через:
- `group_vars/nfs_servers.yml` - для группы серверов
- `host_vars/nfs-server.yml` - для конкретного хоста
- `-e` флаг при запуске плейбука

Пример переопределения переменных:

```bash
ansible-playbook playbook.yml -e "nfs_export_path=/data/nfs nfs_export_options='*(rw,sync,no_subtree_check)'"
```

### 4. Создание нескольких пользователей

Роль `users` поддерживает создание списка пользователей. Примеры:

**Минимальный вариант (только имя):**
```bash
ansible-playbook playbook.yml -e 'nfs_users=[{"name": "user1"}, {"name": "user2"}]'
```

**С полными параметрами:**
```bash
ansible-playbook playbook.yml -e 'nfs_users=[{"name": "user1", "group": "users", "home": "/home/user1"}, {"name": "user2", "group": "users"}]'
```

**Через файл переменных (`group_vars/nfs_servers.yml`):**
```yaml
nfs_users:
  - name: nfs_user
    group: nfs_user
    home: /home/nfs_user
  - name: backup_user
    group: backup
    home: /home/backup_user
    shell: /bin/sh
    update_password: always  # Обновлять пароль при каждом запуске
  - name: app_user
    update_password: on_create  # Установить пароль только при создании пользователя
```

**Автоматическая генерация паролей:**
Роль автоматически генерирует случайный пароль длиной 16 символов (буквы и цифры) для каждого пользователя и выводит его в консоль после создания. Пароли генерируются всегда, ручное указание пароля не поддерживается.

## Переменные ролей

### Роль nfs-server

| Переменная | По умолчанию | Описание |
|------------|--------------|----------|
| `nfs_package` | `nfs-kernel-server` | Пакет NFS сервера |
| `nfs_service` | `nfs-kernel-server` | Имя сервиса NFS |
| `nfs_export_path` | `/exports` | Путь для экспорта |
| `nfs_export_options` | `*(rw,sync,no_subtree_check,no_root_squash)` | Опции экспорта |

### Роль users

| Переменная | По умолчанию | Описание |
|------------|--------------|----------|
| `nfs_users` | `[{"name": "nfs_user", ...}]` | Список пользователей для создания |

Каждый элемент списка `nfs_users` может содержать:
- `name` (обязательно) - имя пользователя
- `group` (опционально) - имя группы, по умолчанию = `name`
- `home` (опционально) - домашняя директория, по умолчанию `/home/name`
- `shell` (опционально) - shell пользователя, по умолчанию `/bin/bash`
- `create_home` (опционально) - создавать домашнюю директорию, по умолчанию `true`
- `update_password` (опционально) - когда обновлять пароль: `always` (всегда) или `on_create` (только при создании), по умолчанию `always`

**Примечание:** Пароль для каждого пользователя генерируется автоматически (16 символов: буквы и цифры) и выводится в консоль после создания. Ручное указание пароля не поддерживается.

## Опции экспорта NFS

- `rw` - read-write доступ
- `sync` - синхронная запись
- `no_subtree_check` - не проверять поддерево (быстрее)
- `no_root_squash` - не маппить root пользователя (для Kubernetes)

## Проверка работы NFS

После установки проверьте:

```bash
# На сервере NFS
showmount -e localhost

# С другого сервера
showmount -e 89.19.215.138
```

## Использование в Kubernetes

После установки NFS сервера, используйте его в Kubernetes:

```yaml
# В StorageClass
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-client
provisioner: k8s-sigs.io/nfs-subdir-external-provisioner
parameters:
  server: 89.19.215.138
  path: /exports
```

## Безопасность

⚠️ **Важно:** Текущая конфигурация экспортирует NFS для всех (`*`). Для production рекомендуется:

1. Ограничить доступ по IP подсети Kubernetes:
   ```yaml
   nfs_export_options: "10.0.0.0/8(rw,sync,no_subtree_check)"
   ```

2. Использовать firewall для ограничения доступа к портам NFS (2049, 111)

3. Настроить аутентификацию через Kerberos (опционально)
