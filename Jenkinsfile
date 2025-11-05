pipeline{
    agent any
    environment{
        NODE_ENV='testing'
        AWS_REGION = 'eu-north-1'
        AWS_ACCOUNT_ID= 'AKIAWHO3RWMC44YXAUVO'
        ECR_REPOSITORY= 'my-app'
        ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        IMAGE_TAG = "${BUILD_NUMBER}"
        IMAGE_NAME = "${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}"
        IMAGE_LATEST = "${ECR_REGISTRY}/${ECR_REPOSITORY}:latest"
    }
    stages{
        stage('Checkout'){
            steps{
                echo 'Checking out code...'
                checkout scm
            }
        }
        stage('Build Info'){
         steps {
                echo "Building image: ${IMAGE_NAME}"
                echo "Git Branch: ${env.GIT_BRANCH}"
                echo "Git Commit: ${env.GIT_COMMIT}"
            }
        }
        stage('Build Docker Image'){
            steps{
               script {
                    echo 'Building Docker image...'
                    sh """
                        docker build -t ${IMAGE_NAME} -t ${IMAGE_LATEST} .
                        docker tag ${IMAGE_NAME} ${IMAGE_LATEST}
                    """
               }
            }
        }

        stage("Test Image"){
            steps{
                echo 'Running tests...'
                sh """
                    docker run -d  --name test-container -p 3001:3000 ${IMAGE_NAME}
                    sleep 10
                    curl -f   http://localhost:3001/health || exit 1
                    docker stop test-container
                    docker rm test-container
                """
            }
        }
    }
}