pipeline {
  agent any  // runs on your Jenkins container

  environment {
    // App & registry
    APP_NAME       = 'demo'
    REGISTRY       = 'docker.io'
    DOCKER_REPO    = 'yogeshsolunke/demo'

    // Kubernetes
    KUBECONFIG     = '/var/jenkins_home/.kube/config'
    K8S_CONTEXT    = 'test-cluster'        // <-- you have this context
    K8S_NAMESPACE  = 'default'
  }

  options {
    timestamps()
    ansiColor('xterm')
  }

  stages {

    stage('Checkout') {
      steps {
        // Set the job to "Pipeline script from SCM" in Jenkins so this works
        checkout scm
      }
    }

    stage('Verify Tooling') {
      steps {
        sh '''
          set -e
          echo "== docker =="
          command -v docker && docker version
          echo "== kubectl =="
          command -v kubectl && kubectl version --client
          echo "== kubeconfig path =="
          echo "$KUBECONFIG"
          ls -l $(dirname "$KUBECONFIG") || true
        '''
      }
    }

    stage('Select Kube Context') {
      steps {
        sh '''
          set -e
          echo "== Available contexts =="
          kubectl config get-contexts || true
          echo "== Using context =="
          kubectl config use-context "$K8S_CONTEXT"
          kubectl config current-context
          echo "== Namespaces (first 20) =="
          kubectl get ns | head -n 20
          # Ensure target namespace exists
          kubectl get ns "$K8S_NAMESPACE" >/dev/null 2>&1 || kubectl create ns "$K8S_NAMESPACE"
        '''
      }
    }

    stage('Build Docker Image (J21, skip tests)') {
      steps {
        sh '''
          set -e
          docker build \
            -t $DOCKER_REPO:$BUILD_NUMBER \
            -t $DOCKER_REPO:latest \
            .
        '''
      }
    }

    stage('Push to Docker Hub') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
          sh '''
            set -e
            echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin $REGISTRY
            docker push $DOCKER_REPO:$BUILD_NUMBER
            docker push $DOCKER_REPO:latest
          '''
        }
      }
    }

    stage('Deploy to Kubernetes') {
      steps {
        sh '''
          set -e
          # Render deployment with the just-built tag
          mkdir -p k8s
          test -f k8s/deployment.yaml
          sed "s|yogeshsolunke/demo:latest|$DOCKER_REPO:$BUILD_NUMBER|g" \
            k8s/deployment.yaml > k8s/deployment.rendered.yaml

          echo "== Applying manifests =="
          kubectl -n "$K8S_NAMESPACE" apply -f k8s/deployment.rendered.yaml

          echo "== Waiting for rollout =="
          # If your Deployment name differs from 'demo', change below accordingly
          kubectl -n "$K8S_NAMESPACE" rollout status deploy/demo --timeout=180s
        '''
      }
    }

    stage('Smoke Test') {
      steps {
        sh '''
          set -e
          echo "== Services =="
          kubectl -n "$K8S_NAMESPACE" get svc
          # If NodePort, you can fetch nodePort like:
          # kubectl -n "$K8S_NAMESPACE" get svc demo-svc -o jsonpath='{.spec.ports[0].nodePort}'; echo
        '''
      }
    }
  }

  post {
    success {
      echo "✅ Deployed $DOCKER_REPO:$BUILD_NUMBER to Kubernetes (context: $K8S_CONTEXT, ns: $K8S_NAMESPACE)."
      archiveArtifacts artifacts: 'k8s/*.yaml', fingerprint: true
    }
    failure {
      echo "❌ Build/Deploy failed. Check logs above for the failing stage."
      sh '''
        echo "=== Debug: Current pods ==="
        kubectl -n "$K8S_NAMESPACE" get pods || true
        echo "=== Debug: ReplicaSets ==="
        kubectl -n "$K8S_NAMESPACE" get rs || true
        echo "=== Debug: Events (last 50) ==="
        kubectl -n "$K8S_NAMESPACE" get events --sort-by=.lastTimestamp | tail -n 50 || true
      '''
    }
    always {
      echo "Run finished for image: $DOCKER_REPO:$BUILD_NUMBER"
    }
  }
}
