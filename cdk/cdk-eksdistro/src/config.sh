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

## Add environment variables required by kops to the shell initialization file
sudo -u ec2-user -i <<'EOF1'
echo 'export KOPS_STATE_STORE=s3://kops-state-store-eksd-aboavent-net' >> ~/.bashrc
echo 'export KOPS_CLUSTER_NAME=eksd.aboavent.net' >> ~/.bashrc
echo 'export EKSCONNECTOR_CLUSTER_NAME=eksdistro' >> ~/.bashrc
echo 'export RELEASE_BRANCH=1-21' >> ~/.bashrc
echo 'export RELEASE=15' >> ~/.bashrc
export AWS_REGION=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region')
echo "export AWS_REGION=${AWS_REGION}" >> ~/.bashrc
echo 'export AWS_DEFAULT_REGION=$AWS_REGION' >> ~/.bashrc
echo "export IAM_ARN=\"arn:aws:iam::111222333444:user/aboavent\"" >> ~/.bashrc
EOF1

## Clone the EKS-Distro Repository & Create the Cluster Configuration (Running as non-root user)
sudo -u ec2-user -i <<'EOF2'
git clone https://github.com/aws/eks-distro.git
cd eks-distro/development/kops
echo 'cd eks-distro/development/kops' >> ~/.bashrc
echo 'source ./set_environment.sh > /dev/null 2>&1' >> ~/.bashrc
echo "Creating EKS Distro Cluster"
./run_cluster.sh
EOF2

### Wait for the Cluster to come up
sudo -u ec2-user -i <<'EOF3'
#cd eks-distro/development/kops 
echo "Waiting cluster to come up"
./cluster_wait.sh
### Verify Your Cluster is Running EKS-D
echo "Verify pods in the cluster are using the EKS Distro images"
kubectl get po --all-namespaces -o json | jq -r '.items[].spec.containers[].image' | sort -u
echo "EKS Distro cluster verified"
EOF3

echo "EKS Distro installation successfully completed!!"

## EKS Connector registration (running as non-root user)
sudo -u ec2-user -i <<'EOF'
## Installing eksctl
echo "Installing eksctl"
mkdir -p $HOME/bin
curl "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" \
    --silent --location \
    | tar xz -C $HOME/bin
echo "EKS Connector registration"
eksctl register cluster --name ${EKSCONNECTOR_CLUSTER_NAME} --provider OTHER --region $AWS_REGION
## https://docs.aws.amazon.com/eks/latest/userguide/connector-grant-access.html
## Granting access for the user accessing through the AWS Console
# 1. Amazon EKS Connector cluster role
# Replace references of %IAM_ARN% with the Amazon Resource Name (ARN) of your IAM user or role
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
# Apply the full access YAML files to the EKS-D cluster
kubectl apply -f eks-connector.yaml,eks-connector-clusterrole.yaml,eks-connector-console-dashboard-full-access-group.yaml
# Checking EKS Connector status for the EKS Distro cluster
export SLEEPTIME=30 # sleep until EKS connector is properly installed
echo "Sleeping $SLEEPTIME seconds until EKS connector is brought up"
sleep $SLEEPTIME
kubectl get po -n eks-connector
kubectl get statefulset eks-connector -n eks-connector
aws eks describe-cluster --name ${EKSCONNECTOR_CLUSTER_NAME} --region $AWS_REGION
EOF
