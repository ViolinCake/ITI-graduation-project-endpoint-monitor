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

        stage('Prepare Build Context') {
            steps {
                script {
                    echo "� Preparing build context for Kaniko..."
                    echo "✅ Using Jenkins service account with ECR permissions"
                    echo "IAM Role: ${env.JENKINS_ROLE_ARN ?: 'Using default service account role'}"
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
                        echo "📋 Using service account IAM role for ECR authentication"
                        
                        sh '''
                            echo "Environment variables:"
                            echo "AWS_REGION: ${AWS_REGION}"
                            echo "AWS_DEFAULT_REGION: ${AWS_DEFAULT_REGION:-not set}"
                            echo "ECR_REGISTRY: ${ECR_REGISTRY}"
                            echo "IMAGE_NAME: ${IMAGE_NAME}"
                            echo "IMAGE_LATEST: ${IMAGE_LATEST}"
                            
                            echo "Build context check:"
                            ls -la ${WORKSPACE}/node_app
                            
                            echo "🏗️ Starting Kaniko build with IAM role authentication..."
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
