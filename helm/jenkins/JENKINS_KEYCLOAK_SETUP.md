# Настройка Keycloak Authentication для Jenkins

Данная инструкция описывает настройку Jenkins для работы с Keycloak через плагин Keycloak Authentication Plugin.

## Предварительные требования

1. **Keycloak установлен и доступен** по адресу `https://keycloak.buildbyte.ru`
2. **В Keycloak настроен клиент для Jenkins:**
   - Client ID: `jenkins`
   - Access Type: `confidential`
   - Valid Redirect URIs: `https://jenkins.buildbyte.ru/securityRealm/finishLogin`
   - Web Origins: `https://jenkins.buildbyte.ru` или `+`
   - Настроен Mapper для групп (см. ниже)

3. **В Keycloak созданы группы:**
   - `admin` — администраторы Jenkins
   - `developer` — разработчики

## Шаг 1: Настройка клиента в Keycloak

### 1.1. Создание клиента

1. Войдите в Keycloak Admin Console: `https://keycloak.buildbyte.ru/admin`
2. Перейдите в **Clients** → **Create client**
3. Заполните:
   - **Client ID**: `jenkins`
   - **Client Protocol**: `openid-connect`
   - Нажмите **Next**

### 1.2. Настройка клиента

В разделе **Settings**:
- **Access Type**: `confidential`
- **Valid Redirect URIs**: 
  ```
  https://jenkins.buildbyte.ru/securityRealm/finishLogin
  ```
- **Web Origins**: 
  ```
  https://jenkins.buildbyte.ru
  ```
  или просто `+` (разрешить все)

Нажмите **Save**.

### 1.3. Настройка Mapper для групп

1. Перейдите на вкладку **Mappers** → **Create**
2. Заполните:
   - **Name**: `groups`
   - **Mapper Type**: `Group Membership`
   - **Token Claim Name**: `groups`
   - **Full group path**: `false`
   - **Add to ID token**: `ON`
   - **Add to access token**: `ON`
   - **Add to userinfo**: `ON`

3. Нажмите **Save**

### 1.4. Получение Client Secret

1. Перейдите на вкладку **Credentials**
2. Скопируйте значение **Secret** (оно понадобится на следующем шаге)

## Шаг 2: Создание Kubernetes Secret

Создайте Secret с client secret из Keycloak:

```bash
kubectl create secret generic jenkins-keycloak-secret \
  --from-literal=client-secret="ВАШ_CLIENT_SECRET_ИЗ_KEYCLOAK" \
  -n jenkins
```

**Важно:** Замените `ВАШ_CLIENT_SECRET_ИЗ_KEYCLOAK` на реальный secret из Keycloak.

## Шаг 3: Применение конфигурации Jenkins

Конфигурация Keycloak уже настроена в `helm/jenkins/jenkins-values.yaml` через JCasC. Примените изменения:

```bash
helm upgrade jenkins jenkins/jenkins \
  --namespace jenkins \
  -f helm/jenkins/jenkins-values.yaml
```

После применения:
1. Jenkins перезапустится
2. Плагин Keycloak будет установлен автоматически
3. Конфигурация Keycloak будет применена через JCasC

## Шаг 4: Проверка настройки

1. Откройте `https://jenkins.buildbyte.ru`
2. Должна появиться кнопка входа через Keycloak
3. Войдите через Keycloak
4. Проверьте права доступа:
   - Пользователи из группы `admin` должны иметь полные права
   - Пользователи из группы `developer` должны иметь ограниченные права

## Настройка прав доступа

Права доступа настраиваются в `helm/jenkins/jenkins-values.yaml` в секции `authorizationStrategy`. 

### Текущие настройки:

**Группа `admin`:**
- Полные права администратора
- Может создавать, изменять и удалять задачи
- Может настраивать Jenkins

**Группа `developer`:**
- Может запускать и отменять сборки
- Может просматривать задачи и результаты сборок
- Не может изменять конфигурацию

### Добавление новых групп:

Чтобы добавить новую группу, отредактируйте `helm/jenkins/jenkins-values.yaml`:

```yaml
authorizationStrategy: |-
  keycloak:
    groups:
      - name: "admin"
        permissions:
          - "Overall/Administer"
          # ... остальные права
      - name: "viewer"
        permissions:
          - "Overall/Read"
          - "View/Read"
```

После изменения примените конфигурацию:

```bash
helm upgrade jenkins jenkins/jenkins \
  --namespace jenkins \
  -f helm/jenkins/jenkins-values.yaml
```

## Устранение неполадок

### Проблема: "Invalid redirect URI"

**Решение:**
- Убедитесь, что redirect URI в Keycloak точно совпадает: `https://jenkins.buildbyte.ru/securityRealm/finishLogin`
- Проверьте, что используется правильный протокол (https)

### Проблема: "Client authentication failed"

**Решение:**
- Проверьте правильность Client Secret в Kubernetes Secret:
  ```bash
  kubectl get secret jenkins-keycloak-secret -n jenkins -o jsonpath='{.data.client-secret}' | base64 -d && echo
  ```
- Убедитесь, что Secret создан в правильном namespace (`jenkins`)
- Проверьте, что переменная окружения `KEYCLOAK_CLIENT_SECRET` доступна в контейнере Jenkins

### Проблема: "Groups not found"

**Решение:**
- Убедитесь, что в Keycloak настроен Mapper для групп
- Проверьте, что пользователь назначен в группы в Keycloak
- Убедитесь, что группы включены в токен (проверьте настройки Mapper)

### Проблема: "Access denied" после входа

**Решение:**
- Проверьте, что пользователь назначен в правильные группы в Keycloak
- Убедитесь, что группы настроены в `authorizationStrategy` в `jenkins-values.yaml`
- Проверьте логи Jenkins:
  ```bash
  kubectl logs -n jenkins deployment/jenkins --tail=100
  ```

### Проблема: Плагин Keycloak не установился

**Решение:**
- Проверьте, что плагин добавлен в `installPlugins`:
  ```bash
  grep -A 5 "installPlugins:" helm/jenkins/jenkins-values.yaml
  ```
- Проверьте логи установки плагинов:
  ```bash
  kubectl logs -n jenkins deployment/jenkins | grep -i keycloak
  ```
- При необходимости переустановите Jenkins или принудительно обновите плагины

## Обновление Client Secret

Если Client Secret изменился в Keycloak:

1. Обновите Secret:
   ```bash
   kubectl create secret generic jenkins-keycloak-secret \
     --from-literal=client-secret="НОВЫЙ_SECRET" \
     -n jenkins \
     --dry-run=client -o yaml | kubectl apply -f -
   ```

2. Перезапустите Jenkins:
   ```bash
   kubectl rollout restart deployment/jenkins -n jenkins
   ```

Или дождитесь автоматической перезагрузки конфигурации через sidecar (если `configAutoReload.enabled: true`).

## Дополнительные ресурсы

- [Keycloak Authentication Plugin Documentation](https://plugins.jenkins.io/keycloak/)
- [Jenkins Configuration as Code Plugin](https://plugins.jenkins.io/configuration-as-code/)
- [Keycloak Documentation](https://www.keycloak.org/documentation)
