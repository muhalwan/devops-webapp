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
                            # Download Qodana CLI for Linux x86_64
                            curl -sSL https://github.com/JetBrains/qodana-cli/releases/download/v2024.3.4/qodana_linux_x86_64.tar.gz -o qodana.tar.gz
                            tar -xzf qodana.tar.gz -C ./qodana
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
                sh 'npm audit fix --force'
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