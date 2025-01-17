pipeline {
    environment {
        QODANA_TOKEN=credentials('qodana-token')
        QODANA_ENDPOINT='https://qodana.cloud'
    }
    agent {
        docker {
            args '''
              -v "${WORKSPACE}":/data/project
              --entrypoint=""
              '''
            image 'jetbrains/qodana-jvm:2024.3'
        }
    }
    stages {
        stage('Qodana') {
            steps {
                sh '''qodana'''
            }
        }
    }
}