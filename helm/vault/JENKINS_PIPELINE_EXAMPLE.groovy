/**
 * Пример Jenkinsfile для использования секретов из Vault в CI/CD пайплайне
 * 
 * Настройка:
 * 1. Установите "HashiCorp Vault Plugin" в Jenkins
 * 2. Настройте Vault в Jenkins (Manage Jenkins → Configure System → HashiCorp Vault)
 * 3. Создайте AppRole в Vault (см. VAULT_SECRETS_INJECTION.md)
 * 4. Добавьте Role ID и Secret ID в Jenkins Credentials (тип "Vault App Role Credential")
 * 
 * Или используйте вариант с Vault CLI (без плагина)
 */

pipeline {
    agent any
    
    environment {
        // Vault адрес (снаружи или изнутри K8s кластера)
        VAULT_ADDR = 'https://vault.buildbyte.ru'
        // Или изнутри K8s: VAULT_ADDR = 'http://vault.vault.svc.cluster.local:8200'
    }
    
    stages {
        stage('Get Secrets from Vault') {
            steps {
                script {
                    // Вариант 1: Использование Vault Plugin (рекомендуется)
                    withVault(configuration: [vaultUrl: env.VAULT_ADDR,
                                             vaultCredentialId: 'vault-approle-credential']) {
                        def secrets = [
                            // Секреты для БД
                            [path: 'secret/data/jenkins/database', engineVersion: 2, secretValues: [
                                [envVar: 'DB_HOST', vaultKey: 'host'],
                                [envVar: 'DB_USER', vaultKey: 'username'],
                                [envVar: 'DB_PASSWORD', vaultKey: 'password']
                            ]],
                            // API ключи
                            [path: 'secret/data/jenkins/api', engineVersion: 2, secretValues: [
                                [envVar: 'API_KEY', vaultKey: 'api_key'],
                                [envVar: 'API_SECRET', vaultKey: 'api_secret']
                            ]],
                            // Секреты для деплоя
                            [path: 'secret/data/apps/myapp', engineVersion: 2, secretValues: [
                                [envVar: 'DEPLOY_KEY', vaultKey: 'deployment_key']
                            ]]
                        ]
                        vaultSecret(secrets: secrets)
                    }
                }
            }
        }
        
        stage('Build') {
            steps {
                script {
                    // Переменные окружения из Vault доступны здесь
                    sh '''
                        echo "Building application..."
                        echo "Database: ${DB_HOST}:${DB_USER}"
                        echo "API Key: ${API_KEY}"
                        # Ваш build процесс
                        # docker build -t myapp:${BUILD_NUMBER} .
                    '''
                }
            }
        }
        
        stage('Test') {
            steps {
                script {
                    sh '''
                        echo "Running tests with secrets..."
                        # Используйте секреты для тестов
                        # npm test -- --db-host=${DB_HOST} --api-key=${API_KEY}
                    '''
                }
            }
        }
        
        stage('Deploy') {
            steps {
                script {
                    sh '''
                        echo "Deploying with deployment key..."
                        # Используйте DEPLOY_KEY для деплоя
                        # kubectl apply -f k8s/ -n production
                    '''
                }
            }
        }
    }
    
    post {
        always {
            // Очистить переменные окружения (опционально)
            script {
                env.remove('DB_PASSWORD')
                env.remove('API_SECRET')
                env.remove('DEPLOY_KEY')
            }
        }
    }
}

/* 
 * Альтернативный вариант: Использование Vault CLI без плагина
 * Требует наличия vault CLI в Jenkins агентах
 */
pipeline {
    agent any
    
    environment {
        VAULT_ADDR = 'https://vault.buildbyte.ru'
        // Role ID и Secret ID хранятся в Jenkins Credentials
        VAULT_ROLE_ID = credentials('vault-role-id')
        VAULT_SECRET_ID = credentials('vault-secret-id')
    }
    
    stages {
        stage('Get Secrets from Vault (CLI)') {
            steps {
                script {
                    sh '''
                        # Аутентификация в Vault через AppRole
                        export VAULT_TOKEN=$(vault write -field=token auth/approle/login \
                            role_id=${VAULT_ROLE_ID} \
                            secret_id=${VAULT_SECRET_ID})
                        
                        # Получить секреты
                        export DB_HOST=$(vault kv get -field=host secret/jenkins/database)
                        export DB_USER=$(vault kv get -field=username secret/jenkins/database)
                        export DB_PASSWORD=$(vault kv get -field=password secret/jenkins/database)
                        export API_KEY=$(vault kv get -field=api_key secret/jenkins/api)
                        
                        echo "Secrets retrieved from Vault"
                    '''
                }
            }
        }
        
        stage('Build and Deploy') {
            steps {
                sh '''
                    echo "Building and deploying with secrets..."
                    # Ваш build/deploy процесс
                '''
            }
        }
    }
}
