pipeline {
    agent any

    environment {
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-credentials')
        AWS_CREDENTIALS = credentials('aws-credentials')
        KUBECONFIG_CREDENTIALS = credentials('kubeconfig')
        QODANA_TOKEN = credentials('qodana-token')
    }

    stages {
        stage('Checkout') {
            steps {
                git 'https://github.com/muhalwan/devops-webapp.git'
            }
        }

        stage('Qodana Scan') {
            steps {
                script {
                    try {
                        sh 'mkdir -p ./qodana'
                        sh '''
                            curl -sSL https://github.com/JetBrains/qodana-action/archive/refs/tags/v2024.3.4.tar.gz -o qodana-action.tar.gz
                            tar -xzf qodana-action.tar.gz -C ./qodana --strip-components=1
                            ls -l ./qodana  # Debugging step to list files
                            chmod +x ./qodana/qodana
                            ./qodana/qodana --version
                            ./qodana/qodana scan --pr-mode=false --token $QODANA_TOKEN --endpoint https://qodana.cloud
                        '''
                    } catch (Exception e) {
                        echo "Qodana Scan failed: ${e}"
                        currentBuild.result = 'FAILURE'
                    }
                }
            }
        }

        stage('Build') {
            steps {
                sh 'npm install'
                sh 'npm audit fix'
                sh 'npm test'
            }
        }

        stage('Docker Build') {
            steps {
                script {
                    dockerImage = docker.build("muhalwan/devops-webapp:${env.BUILD_ID}")
                }
            }
        }

        stage('Docker Push') {
            steps {
                script {
                    docker.withRegistry('https://registry.hub.docker.com', 'dockerhub-credentials') {
                        dockerImage.push()
                    }
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                    sh 'kubectl apply -f k8s/'
                }
            }
        }
    }

    post {
        success {
            echo 'Deployment successful!'
        }
        failure {
            echo 'Deployment failed.'
        }
    }
}