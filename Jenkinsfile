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

        stage('Get ECR Token') {
            steps {
                script {
                    echo "🔐 Getting ECR authentication token..."
                    
                    // Get ECR token using Jenkins AWS credentials
                    withAWS(region: env.AWS_REGION) {
                        env.ECR_TOKEN = sh(
                            script: "aws ecr get-login-password --region ${env.AWS_REGION}",
                            returnStdout: true
                        ).trim()
                    }
                    
                    if (!env.ECR_TOKEN) {
                        error("Failed to get ECR authentication token")
                    }
                    
                    echo "✅ ECR token obtained successfully"
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
                        echo "📋 Setting up ECR authentication..."
                        
                        sh '''
                            # Create Kaniko Docker config directory
                            mkdir -p /kaniko/.docker
                            
                            # Create Docker config with ECR auth
                            cat > /kaniko/.docker/config.json << EOF
{
  "auths": {
    "${ECR_REGISTRY}": {
      "auth": "$(echo -n "AWS:${ECR_TOKEN}" | base64 -w 0)"
    }
  }
}
EOF
                            
                            echo "✅ ECR authentication configured"
                            echo "Registry: ${ECR_REGISTRY}"
                            
                            echo "🏗️ Starting Kaniko build..."
                            /kaniko/executor \\
                              --context ${WORKSPACE}/node_app \\
                              --dockerfile ${WORKSPACE}/node_app/Dockerfile \\
                              --destination ${IMAGE_NAME} \\
                              --destination ${IMAGE_LATEST} \\
                              --verbosity=info \\
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
            cleanWs()
        }
    }
}
