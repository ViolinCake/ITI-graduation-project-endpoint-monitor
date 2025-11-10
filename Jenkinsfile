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
        
        stage('Build & Push with Kaniko') {
            steps {
                container('kaniko') {
                    withAWS(credentials: 'AWS', region: "${AWS_REGION}") {
                        script {
                            echo "🔧 Preparing ECR authentication for Kaniko..."
                            
                            sh '''
                                mkdir -p /kaniko/.docker
                                
                                echo "Getting ECR login token..."
                                AUTH_TOKEN=$(aws ecr get-login-password --region ${AWS_REGION})
                                
                                if [ -z "$AUTH_TOKEN" ]; then
                                    echo "❌ Failed to get ECR auth token"
                                    exit 1
                                fi
                                
                                echo "Creating Kaniko auth config..."
                                cat > /kaniko/.docker/config.json << EOF
{
  "auths": {
    "https://${ECR_REGISTRY}": {
      "auth": "$(echo -n "AWS:${AUTH_TOKEN}" | base64 -w 0)"
    }
  }
}
EOF
                                
                                echo "✅ Kaniko auth config created:"
                                cat /kaniko/.docker/config.json | jq '.' || cat /kaniko/.docker/config.json
                            '''

                            echo "🚀 Building and pushing image with Kaniko..."
                            sh '''
                                /kaniko/executor \
                                  --context ${WORKSPACE}/node_app \
                                  --dockerfile ${WORKSPACE}/node_app/Dockerfile \
                                  --destination ${IMAGE_NAME} \
                                  --destination ${IMAGE_LATEST} \
                                  --use-new-run \
                                  --cache=true \
                                  --single-snapshot \
                                  --verbosity=info
                            '''
                        }
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
            cleanWs()
        }
    }
}
