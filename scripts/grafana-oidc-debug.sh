#!/bin/bash
# Скрипт для диагностики проблем с OIDC в Grafana

set -e

NAMESPACE="kube-prometheus-stack"

echo "=== Диагностика OIDC для Grafana ==="
echo ""

# 1. Проверить секрет
echo "1. Проверка секрета grafana-oidc-secret:"
kubectl get secret grafana-oidc-secret -n $NAMESPACE 2>/dev/null && echo "✓ Секрет существует" || echo "✗ Секрет НЕ существует"
echo ""

# 2. Проверить значение Client Secret
echo "2. Проверка значения Client Secret:"
CLIENT_SECRET=$(kubectl get secret grafana-oidc-secret -n $NAMESPACE -o jsonpath='{.data.client_secret}' 2>/dev/null | base64 -d)
if [ -z "$CLIENT_SECRET" ]; then
    echo "✗ Client Secret пустой или не найден"
else
    echo "✓ Client Secret установлен (длина: ${#CLIENT_SECRET} символов)"
    if [[ "$CLIENT_SECRET" == *"$"* ]]; then
        echo "⚠ ВНИМАНИЕ: Client Secret содержит символ '$' - возможно, это не реальное значение!"
    fi
fi
echo ""

# 3. Получить имя пода Grafana
GRAFANA_POD=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$GRAFANA_POD" ]; then
    echo "✗ Pod Grafana не найден"
    exit 1
fi
echo "3. Pod Grafana: $GRAFANA_POD"
echo ""

# 4. Проверить переменную окружения
echo "4. Проверка переменной окружения GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET:"
ENV_VALUE=$(kubectl exec $GRAFANA_POD -n $NAMESPACE -- env 2>/dev/null | grep "^GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=" || echo "")
if [ -z "$ENV_VALUE" ]; then
    echo "✗ Переменная окружения НЕ установлена!"
else
    echo "✓ Переменная окружения установлена"
    ENV_SECRET=$(echo "$ENV_VALUE" | cut -d'=' -f2)
    if [ -z "$ENV_SECRET" ]; then
        echo "⚠ ВНИМАНИЕ: Значение переменной окружения пустое!"
    else
        echo "  Длина значения: ${#ENV_SECRET} символов"
    fi
fi
echo ""

# 5. Проверить конфигурацию Grafana
echo "5. Проверка конфигурации OAuth в grafana.ini:"
kubectl exec $GRAFANA_POD -n $NAMESPACE -- cat /etc/grafana/grafana.ini 2>/dev/null | grep -A 15 "auth.generic_oauth" || echo "✗ Конфигурация OAuth не найдена"
echo ""

# 6. Проверить логи Grafana на ошибки OAuth
echo "6. Последние ошибки OAuth в логах Grafana:"
kubectl logs $GRAFANA_POD -n $NAMESPACE --tail=100 2>/dev/null | grep -i "oauth\|token\|auth" | tail -10 || echo "Нет записей в логах"
echo ""

# 7. Проверить доступность Keycloak
echo "7. Проверка доступности Keycloak:"
KEYCLOAK_URL="https://keycloak.buildbyte.ru/realms/services"
if curl -s -o /dev/null -w "%{http_code}" "$KEYCLOAK_URL/.well-known/openid-configuration" | grep -q "200"; then
    echo "✓ Keycloak доступен"
else
    echo "✗ Keycloak недоступен или возвращает ошибку"
fi
echo ""

# 8. Проверить ExternalSecret
echo "8. Проверка ExternalSecret:"
kubectl get externalsecret grafana-oidc-secret -n $NAMESPACE 2>/dev/null && echo "✓ ExternalSecret существует" || echo "✗ ExternalSecret НЕ существует"
kubectl describe externalsecret grafana-oidc-secret -n $NAMESPACE 2>/dev/null | grep -A 5 "Status:" || echo ""
echo ""

echo "=== Рекомендации ==="
echo "1. Убедитесь, что Client Secret в Keycloak совпадает с тем, что в Vault"
echo "2. Проверьте Redirect URI в Keycloak: https://grafana.buildbyte.ru/login/generic_oauth"
echo "3. Проверьте, что Realm 'services' существует в Keycloak"
echo "4. Перезапустите Grafana после изменений: kubectl rollout restart deployment kube-prometheus-stack-grafana -n $NAMESPACE"
