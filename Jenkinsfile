pipeline {
  agent any
  environment {
    APP_NAME   = 'demo'
    REGISTRY   = 'docker.io'
    DOCKER_REPO = 'yogeshsolunke/demo'   // change me
    K8S_NAMESPACE = 'default'
  }
  options { timestamps() }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Build Docker Image (J21, skip tests)') {
      steps {
        sh 'docker version'
        sh 'docker build -t $DOCKER_REPO:$BUILD_NUMBER -t $DOCKER_REPO:latest .'
      }
    }

    stage('Push to Docker Hub') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
          sh '''
            echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin $REGISTRY
            docker push $DOCKER_REPO:$BUILD_NUMBER
            docker push $DOCKER_REPO:latest
          '''
        }
      }
    }

    stage('Deploy to Kubernetes') {
      steps {
        // If you mounted ~/.kube to Jenkins home, kubectl will use /var/jenkins_home/.kube/config
        sh '''
          kubectl config current-context
          # render manifest with the current image tag
          sed "s|yogeshsolunke/demo:latest|$DOCKER_REPO:$BUILD_NUMBER|g" k8s/deployment.yaml > k8s/deployment.rendered.yaml
          kubectl -n $K8S_NAMESPACE apply -f k8s/deployment.rendered.yaml
          kubectl -n $K8S_NAMESPACE rollout status deploy/demo --timeout=120s
        '''
      }
    }

    stage('Smoke Test') {
      steps {
        sh '''
          # Try service inside cluster (pod to pod) — optional
          kubectl -n $K8S_NAMESPACE get svc demo-svc
          # If NodePort, you can hit via minikube:
          echo "Try: minikube service demo-svc --url"
        '''
      }
    }
  }

  post {
    success {
      echo "✅ Deployed $DOCKER_REPO:$BUILD_NUMBER to Kubernetes."
      archiveArtifacts artifacts: 'k8s/*.yaml', fingerprint: true
    }
    failure {
      echo "❌ Build/Deploy failed. Check console logs."
    }
  }
}
