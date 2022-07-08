#!/bin/bash -xe

# Update with optional user data that will run on instance start.
# Learn more about user-data: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html
# sudo tail -f /var/log/cloud-init-output.log
# sudo cat /var/log/cloud-init-output.log


### Install dependencies
#sudo cloud-init status --wait #block custom scripts until cloud-init is done.
#sudo yum update -y
#sudo yum install git -y
#sudo yum install jq -y

## Running as non-root user
sudo -u ec2-user -i <<'EOF'

## Installing kubectl (1.22)
echo "Installing kubectl (1.22)"
curl -o kubectl https://s3.us-west-2.amazonaws.com/amazon-eks/1.22.6/2022-03-09/bin/linux/amd64/kubectl
chmod +x ./kubectl
mkdir -p $HOME/bin && cp ./kubectl $HOME/bin/kubectl 
export PATH=$PATH:$HOME/bin && echo 'export PATH=$PATH:$HOME/bin' >> ~/.bashrc

## Installing eksctl
echo "Installing eksctl"
curl "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" \
    --silent --location \
    | tar xz -C $HOME/bin
#sudo mv /tmp/eksctl /usr/local/bin/

## Installing eksctl anywhere
echo "Installing eksctl anywhere"
export EKSA_RELEASE="0.8.2" OS="$(uname -s | tr A-Z a-z)" RELEASE_NUMBER=10
curl "https://anywhere-assets.eks.amazonaws.com/releases/eks-a/${RELEASE_NUMBER}/artifacts/eks-a/v${EKSA_RELEASE}/${OS}/amd64/eksctl-anywhere-v${EKSA_RELEASE}-${OS}-amd64.tar.gz" \
    --silent --location \
    | tar xz ./eksctl-anywhere
mv ./eksctl-anywhere $HOME/bin

EOF

### Install docker
sudo yum update -y
sudo amazon-linux-extras install docker -y
sudo service docker start
sudo usermod -a -G docker ec2-user
sudo systemctl enable docker

## Add environment variables required for EKS-A installation (running as non-root user)
sudo -u ec2-user -i <<'EOF'
export AWS_REGION=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region')
echo "export AWS_REGION=${AWS_REGION}" >> ~/.bashrc
echo 'export CLUSTER_NAME=eksa-dev-cluster' >> ~/.bashrc
EOF

### Create a development cluster with EKS Anywhere and registering EKS Connector (running as non-root user)
sudo -u ec2-user -i <<'EOF'
# EKS-A Cluster creation
echo "EKS-A Cluster creation"
eksctl anywhere generate clusterconfig $CLUSTER_NAME --provider docker > $CLUSTER_NAME.yaml
eksctl anywhere create cluster -f $CLUSTER_NAME.yaml  
#echo 'export KUBECONFIG=$HOME/${CLUSTER_NAME}/${CLUSTER_NAME}-eks-a-cluster.kubeconfig' >> ~/.bashrc
mkdir $HOME/.kube && cp $HOME/${CLUSTER_NAME}/${CLUSTER_NAME}-eks-a-cluster.kubeconfig $HOME/.kube/config

export EC2_PUBLIC_IP=$(curl -s http://checkip.amazonaws.com)
#export EC2_PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

sed -i "s/127.0.0.1/$EC2_PUBLIC_IP/g" $HOME/.kube/config
sed -i "s/localhost/$EC2_PUBLIC_IP/g" $HOME/.kube/config
EOF


## EKS Connector registration (running as non-root user)
sudo -u ec2-user -i <<'EOF'
echo "EKS Connector registration"
eksctl register cluster --name ${CLUSTER_NAME} --provider EKS_ANYWHERE --region $AWS_REGION

## https://docs.aws.amazon.com/eks/latest/userguide/connector-grant-access.html
## Granting access for the user accessing through the AWS Console

# 1. Amazon EKS Connector cluster role
# Replace references of %IAM_ARN% with the Amazon Resource Name (ARN) of your IAM user or role
export IAM_ARN="arn:aws:iam::111222333444:user/aboavent"
echo "      - \"${IAM_ARN}\"" >> eks-connector-clusterrole.yaml

# 2. Configure an IAM user to access the connected cluster
# View Kubernetes resources in all namespaces – The eks-connector-console-dashboard-full-access-clusterrole 
# cluster role gives access to all namespaces and resources that can be visualized in the console

cat << EKSCONNECTORCONSOLEACCESS >> eks-connector-console-dashboard-full-access-group.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
    name: eks-connector-console-dashboard-full-access-clusterrole-binding
subjects:
- kind: User
  name: "${IAM_ARN}"
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: eks-connector-console-dashboard-full-access-clusterrole
  apiGroup: rbac.authorization.k8s.io
---
EKSCONNECTORCONSOLEACCESS

# Apply the full access YAML files to the EKS-A cluster
kubectl apply -f eks-connector.yaml,eks-connector-clusterrole.yaml,eks-connector-console-dashboard-full-access-group.yaml

# Checking EKS Connector status for the EKS Anywhere cluster
export SLEEPTIME=30 # sleep until EKS connector is properly installed
echo "Sleeping $SLEEPTIME seconds until EKS connector is brought up"
sleep $SLEEPTIME
kubectl get po -n eks-connector
kubectl get statefulset eks-connector -n eks-connector
aws eks describe-cluster --name ${CLUSTER_NAME} --region $AWS_REGION

EOF
