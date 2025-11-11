pipeline {
    agent {
        kubernetes {
            yamlFile 'kaniko/index.yaml'
        }
    }
    
    environment {
        AWS_REGION       = 'eu-north-1'
        AWS_ACCOUNT_ID   = '428346553093'
        ECR_REPOSITORY   = 'my-app'
        ECR_REGISTRY     = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        EKS_CLUSTER_NAME = 'ITI-GP-Cluster'
        IMAGE_TAG        = "${BUILD_NUMBER}"
        IMAGE_NAME       = "${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}"
        IMAGE_LATEST     = "${ECR_REGISTRY}/${ECR_REPOSITORY}:latest"
        K8S_NAMESPACE    = 'default'
        APP_NAME         = 'my-app'
    }

    stages {
        stage('Checkout') {
            steps {
                echo '🔍 Checking out code from repository...'
                checkout scm
                script {
                    env.GIT_COMMIT_SHORT = sh(
                        script: "git rev-parse --short HEAD",
                        returnStdout: true
                    ).trim()
                }
            }
        }

        stage('Build Info') {
            steps {
                echo "📦 Building image: ${IMAGE_NAME}"
                echo "🌿 Git Branch: ${env.GIT_BRANCH ?: 'N/A'}"
                echo "📝 Git Commit: ${env.GIT_COMMIT_SHORT}"
                echo "🏗️ Build Number: ${BUILD_NUMBER}"
            }
        }

        stage('Debug AWS Credentials in Kaniko') {
            steps {
                container('kaniko') {
                    script {
                        sh '''
                            echo "=== 🧰 Installing AWS CLI inside Kaniko ==="
                            apk add --no-cache python3 py3-pip groff less curl jq > /dev/null
                            pip install awscli --quiet

                            echo "=== 🔍 Checking AWS CLI Installation ==="
                            aws --version || { echo "❌ AWS CLI not found"; exit 1; }

                            echo "=== 🔑 Testing STS Identity ==="
                            aws sts get-caller-identity || { echo "❌ Failed to get AWS identity"; exit 1; }

                            echo "=== 🧭 Testing ECR Access ==="
                            aws ecr describe-repositories --region ${AWS_REGION} || echo "⚠️ ECR list access might be limited"

                            echo "=== 🔐 Testing ECR Login ==="
                            aws ecr get-login-password --region ${AWS_REGION} | head -c 50
                            echo "..."
                        '''
                    }
                }
            }
        }

        stage('Debug IAM in Kaniko Pod') {
            steps {
                container('kaniko') {
                    script {
                        sh '''
                            echo "=== 🧾 Checking IAM Role in Kaniko Container ==="
                            echo "AWS_ROLE_ARN: ${AWS_ROLE_ARN:-NOT SET ❌}"
                            echo "AWS_WEB_IDENTITY_TOKEN_FILE: ${AWS_WEB_IDENTITY_TOKEN_FILE:-NOT SET ❌}"
                            echo "AWS_REGION: ${AWS_REGION}"

                            if [ -f "${AWS_WEB_IDENTITY_TOKEN_FILE}" ]; then
                                echo "✅ Token file exists at: ${AWS_WEB_IDENTITY_TOKEN_FILE}"
                                head -c 50 "${AWS_WEB_IDENTITY_TOKEN_FILE}"
                                echo "..."
                            else
                                echo "❌ Token file missing!"
                                ls -la /var/run/secrets/eks.amazonaws.com/serviceaccount/ || echo "No serviceaccount token directory"
                            fi

                            echo "=== 📄 Docker Config Check ==="
                            cat /kaniko/.docker/config.json 2>/dev/null || echo "No docker config yet"
                        '''
                    }
                }
            }
        }

        stage('Verify Environment') {
            steps {
                script {
                    echo "🔍 Verifying build environment..."
                    echo "Workspace: ${WORKSPACE}"
                    echo "Build Number: ${BUILD_NUMBER}"
                    echo "ECR Registry: ${ECR_REGISTRY}"
                    echo "Image Name: ${IMAGE_NAME}"

                    sh '''
                        echo "Checking workspace structure:"
                        ls -la ${WORKSPACE}
                        echo "Checking node_app:"
                        ls -la ${WORKSPACE}/node_app || echo "node_app not found"
                        echo "Checking Dockerfile:"
                        ls -la ${WORKSPACE}/node_app/Dockerfile || echo "Dockerfile not found"
                    '''
                }
            }
        }

        stage('Build & Push with Kaniko') {
            steps {
                container('kaniko') {
                    script {
                        echo "🚀 Building and pushing image with Kaniko..."
                        echo "📋 Using IAM Role for ECR authentication"

                        sh '''
                            echo "Environment variables:"
                            echo "AWS_REGION: ${AWS_REGION}"
                            echo "AWS_DEFAULT_REGION: ${AWS_DEFAULT_REGION:-not set}"
                            echo "ECR_REGISTRY: ${ECR_REGISTRY}"
                            echo "IMAGE_NAME: ${IMAGE_NAME}"
                            echo "IMAGE_LATEST: ${IMAGE_LATEST}"

                            echo "🏗️ Starting Kaniko build..."
                            /kaniko/executor \
                              --context ${WORKSPACE}/node_app \
                              --dockerfile ${WORKSPACE}/node_app/Dockerfile \
                              --destination ${IMAGE_NAME} \
                              --destination ${IMAGE_LATEST} \
                              --aws-region ${AWS_REGION} \
                              --verbosity=info \
                              --force
                        '''
                    }
                }
            }
        }
    }

    post {
        success {
            echo '✅ ====================================='
            echo '✅ Pipeline completed successfully!'
            echo '✅ ====================================='
            echo "📦 Image: ${IMAGE_NAME}"
            echo "☁️ ECR: ${ECR_REGISTRY}/${ECR_REPOSITORY}"
            echo "🚀 Deployed to EKS: ${EKS_CLUSTER_NAME}"
        }

        failure {
            echo '❌ ====================================='
            echo '❌ Pipeline failed!'
            echo '❌ ====================================='
        }

        always {
            echo '🧹 Cleaning up workspace...'
            script {
                try {
                    cleanWs()
                } catch (Exception e) {
                    echo "⚠️ cleanWs() not available — using deleteDir()"
                    deleteDir()
                }
            }
        }
    }
}
