#!/usr/bin/env bash

# This script shows how to build the Docker image and push it to ECR to be used 
# within the EKS clusters as a REST API to consume the Amazon DocumentDB Sample Movies collection.

# The first argument to this script is the image name. This will be used as the image on the local
# machine and combined with the account and region to form the repository name for ECR.
# The second argument is the connection string used to connect to Amazon DocumentDB in the app.js file
image=$1
CONNECTION_STRING=$2

if [ "$image" == "" ]
then
    echo "Usage: $0 <image-name>"
    exit 1
fi

if [ "$CONNECTION_STRING" == "" ]
then
    echo "No connection string has been provided to be used by Mongoose to connect to Amazon DocumentDB."
    exit 1
fi

# Get the account number associated with the current IAM credentials
account=$(aws sts get-caller-identity --query Account --output text)

if [ $? -ne 0 ]
then
    exit 255
fi


# Get the region defined in the current configuration (default to us-west-2 if none defined)
region=$(aws configure get region)
region=${region:-us-west-2}

fullname="${account}.dkr.ecr.${region}.amazonaws.com/${image}:latest"

# If the repository doesn't exist in ECR, create it.
aws ecr describe-repositories --repository-names "${image}" > /dev/null 2>&1

if [ $? -ne 0 ]
then
    aws ecr create-repository --repository-name "${image}" > /dev/null
fi

# Get the login command from ECR and execute it directly
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin ${account}.dkr.ecr.${region}.amazonaws.com

# Replace the Mongoose connection string in the ../node-rest-api/app.js file
sed -i "s|CONNECTIONSTRING|$CONNECTION_STRING|g" ./app.js

# Build the docker image locally with the image name and then push it to ECR
# with the full name.

docker build  -t ${image} .

# After the build completes, it tags the image so that you can push the image to the repository
docker tag ${image} ${fullname}

docker push ${fullname}

# Points the K8S ReplicationController to the image pushed into ECR
# change our delimiter from / to | to avoid escaping issues with the image name which contains /
sed -i "s|YOUR-CONTAINER-IMAGE|$fullname|g" ./k8s/node-rest-api-deployment.yaml
