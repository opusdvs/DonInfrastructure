-- SQL скрипт для создания базы данных и пользователя для Keycloak
-- Выполните этот скрипт в PostgreSQL перед настройкой Keycloak
--
-- Использование:
-- 1. Подключитесь к PostgreSQL:
--    kubectl exec -it <postgresql-pod> -n <postgresql-namespace> -- psql -U postgres
--
-- 2. Выполните команды ниже или скопируйте файл в pod и выполните:
--    kubectl cp manifests/keycloak/create-keycloak-database.sql <postgresql-pod>:/tmp/create-keycloak-database.sql -n <postgresql-namespace>
--    kubectl exec -it <postgresql-pod> -n <postgresql-namespace> -- psql -U postgres -f /tmp/create-keycloak-database.sql

-- Создание пользователя для Keycloak
-- ⚠️ ВАЖНО: Замените 'change-me-please' на безопасный пароль!
CREATE USER keycloak WITH PASSWORD 'change-me-please';

-- Создание базы данных для Keycloak
CREATE DATABASE keycloak OWNER keycloak;

-- Предоставление всех привилегий пользователю keycloak на базу данных keycloak
GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak;

-- Подключение к базе данных keycloak
\c keycloak

-- Предоставление привилегий на схему public
GRANT ALL ON SCHEMA public TO keycloak;

-- Установка владельца схемы public на пользователя keycloak
ALTER SCHEMA public OWNER TO keycloak;

-- Вывод информации о созданных объектах
\du keycloak
\l keycloak
