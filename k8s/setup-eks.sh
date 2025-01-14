#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Variables (Customize these as needed)
CLUSTER_NAME="devops-eks-service"
REGION="us-east-1"
NODEGROUP_NAME="devops-node-group"
NODE_TYPE="t3.medium"
NODES_PER_AZ=2
MIN_NODES=1
MAX_NODES=3
DESIRED_NODES=2
VPC_CIDR="10.0.0.0/16"
SUBNET_CIDR_PUBLIC="10.0.1.0/24"
SUBNET_CIDR_PRIVATE="10.0.2.0/24"
KEY_NAME="my-key-pair"  # Ensure this key pair exists in AWS EC2

# Function to install eksctl if not installed
install_eksctl() {
    if ! command -v eksctl &> /dev/null
    then
        echo "eksctl not found. Installing eksctl..."
        curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
        sudo mv /tmp/eksctl /usr/local/bin
        echo "eksctl installed successfully."
    else
        echo "eksctl is already installed."
    fi
}

# Function to install Helm if not installed
install_helm() {
    if ! command -v helm &> /dev/null
    then
        echo "Helm not found. Installing Helm..."
        curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
        echo "Helm installed successfully."
    else
        echo "Helm is already installed."
    fi
}

# Function to create EKS cluster
create_cluster() {
    echo "Creating EKS cluster: $CLUSTER_NAME in region $REGION"

    eksctl create cluster \
      --name $CLUSTER_NAME \
      --version 1.31 \
      --region $REGION \
      --nodegroup-name $NODEGROUP_NAME \
      --node-type $NODE_TYPE \
      --nodes $DESIRED_NODES \
      --nodes-min $MIN_NODES \
      --nodes-max $MAX_NODES \
      --managed \
      --ssh-access \
      --ssh-public-key $KEY_NAME \
      --with-oidc \
      --vpc-cidr $VPC_CIDR \
      --vpc-public-subnets $SUBNET_CIDR_PUBLIC \
      --vpc-private-subnets $SUBNET_CIDR_PRIVATE \
      --asg-access \
      --full-ecr-access \
      --appmesh-access \
      --alb-ingress-access \
      --external-dns-access \
      --verbose 4

    echo "EKS cluster creation initiated. This may take several minutes."
}

# Function to verify cluster
verify_cluster() {
    echo "Verifying EKS cluster..."

    # Wait until the cluster is active
    while true; do
        STATUS=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query "cluster.status" --output text)
        echo "Cluster status: $STATUS"
        if [ "$STATUS" == "ACTIVE" ]; then
            echo "Cluster is active."
            break
        elif [ "$STATUS" == "FAILED" ]; then
            echo "Cluster creation failed."
            exit 1
        else
            echo "Waiting for cluster to become active..."
            sleep 60
        fi
    done

    # Update kubeconfig
    echo "Updating kubeconfig..."
    aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME
    echo "kubeconfig updated."

    # Get nodes
    echo "Fetching cluster nodes..."
    kubectl get nodes
}

# Function to install AWS Load Balancer Controller
install_load_balancer_controller() {
    echo "Installing AWS Load Balancer Controller..."

    # Add EKS Helm repository
    helm repo add eks https://aws.github.io/eks-charts
    helm repo update

    # Create IAM policy for Load Balancer Controller
    echo "Creating IAM policy for AWS Load Balancer Controller..."
    curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
    POLICY_ARN=$(aws iam create-policy \
        --policy-name AWSLoadBalancerControllerIAMPolicy \
        --policy-document file://iam_policy.json \
        --query 'Policy.Arn' \
        --output text)
    echo "IAM Policy created with ARN: $POLICY_ARN"

    # Create IAM service account
    echo "Creating IAM service account for AWS Load Balancer Controller..."
    eksctl create iamserviceaccount \
      --cluster=$CLUSTER_NAME \
      --namespace=kube-system \
      --name=aws-load-balancer-controller \
      --attach-policy-arn=$POLICY_ARN \
      --approve \
      --override-existing-serviceaccounts

    # Install AWS Load Balancer Controller using Helm
    echo "Installing AWS Load Balancer Controller via Helm..."
    helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
      -n kube-system \
      --set clusterName=$CLUSTER_NAME \
      --set serviceAccount.create=false \
      --set serviceAccount.name=aws-load-balancer-controller \
      --set region=$REGION \
      --set vpcId=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query "cluster.resourcesVpcConfig.vpcId" --output text)

    echo "AWS Load Balancer Controller installed successfully."
}

# Function to deploy Kubernetes manifests
deploy_manifests() {
    echo "Deploying Kubernetes manifests..."

    # Ensure you're in the project directory where k8s manifests are located
    # Modify the path as per your project structure
    PROJECT_DIR=~/Code/devops-webapp/k8s
    if [ ! -d "$PROJECT_DIR" ]; then
        echo "Kubernetes manifests directory not found at $PROJECT_DIR"
        echo "Please ensure your k8s manifests are located at $PROJECT_DIR or update the PROJECT_DIR variable."
        exit 1
    fi

    cd $PROJECT_DIR

    # Apply Secrets
    echo "Applying Secrets..."
    kubectl apply -f secret.yaml

    # Apply Deployment and Service
    echo "Applying Deployment and Service..."
    kubectl apply -f deployment.yaml
    kubectl apply -f service.yaml

    # Apply Ingress
    echo "Applying Ingress..."
    kubectl apply -f ingress.yaml

    echo "Kubernetes manifests deployed successfully."
}

# Function to verify deployment
verify_deployment() {
    echo "Verifying Kubernetes deployment..."

    # Check pods
    echo "Checking pods..."
    kubectl get pods

    # Check services
    echo "Checking services..."
    kubectl get services

    # Check ingress
    echo "Checking ingress..."
    kubectl get ingress

    echo "Deployment verification completed."
}

# Main Execution Flow
main() {
    install_eksctl
    install_helm
    create_cluster
    verify_cluster
    install_load_balancer_controller
    deploy_manifests
    verify_deployment

    echo "EKS Cluster and application deployment completed successfully!"
    echo "You can access your application via the ALB's DNS name retrieved from the Ingress resource."
}

# Execute the main function
main
