pipeline{
    agent {
      docker {
      image 'docker:24.0.6'
      args '-v /var/run/docker.sock:/var/run/docker.sock'
     }
    }
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
        stage('Build & Push Image (Kaniko)') {
            steps {
                container('kaniko') {
                    sh """
                        /kaniko/executor \
                          --context=`pwd` \
                          --dockerfile=Dockerfile \
                          --destination=${IMAGE_NAME} \
                          --destination=${IMAGE_LATEST}
                    """
                }
            }
        }
    }
}