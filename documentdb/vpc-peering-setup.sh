#!/usr/bin/env bash

# This script shows how to build the Docker image and push it to ECR to be used 
# within the EKS clusters as a REST API to consume the Amazon DocumentDB Sample Movies collection.

# The first argument to this script is the image name. This will be used as the image on the local
# machine and combined with the account and region to form the repository name for ECR.
# The second argument is the connection string used to connect to Amazon DocumentDB in the app.js file
export EKSD_DOMAIN=$1
export EKS_DOMAIN=$2

if [[ "$EKSD_DOMAIN" == "" ]] || [[ "$EKSD_DOMAIN" == "" ]]
then
    echo "Usage: $0 <EKS-D domain name> <EKS domain name>"
    exit 1
fi

## Get DocumentDB VPC (default VPC) ID and CIDR to be used during route setup
export DOCUMENTDB_VPC_ID=$(aws ec2 describe-vpcs --query 'Vpcs[?IsDefault == `true`].VpcId' --output text)
export DOCUMENTDB_VPC_CIDR=$(aws ec2 describe-vpcs --query 'Vpcs[?IsDefault == `true`].CidrBlock' --output text)

## Get EKS-D VPC ID and CIDR using EKS-D Domain name used during cluster creation
#export EKSD_DOMAIN="eksd.aboavent.net"
export EKSD_VPC_ID=$(aws ec2 describe-vpcs --query "Vpcs[?Tags[?Key=='Name']|[?Value=='$EKSD_DOMAIN']].VpcId" --output text)
export EKSD_VPC_CIDR=$(aws ec2 describe-vpcs --query "Vpcs[?Tags[?Key=='Name']|[?Value=='$EKSD_DOMAIN']].CidrBlock" --output text)

## Get EKS VPC ID and CIDR using EKS-D Domain name used during cluster creation
#export EKS_DOMAIN="eks-prod"
export EKS_VPC_ID=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=*$EKS_DOMAIN* --query 'Vpcs[].VpcId' --output text)
export EKS_VPC_CIDR=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=*$EKS_DOMAIN* --query 'Vpcs[].CidrBlock' --output text)

## create a VPC peering connection between EKS-D VPC and DocumentDB VPC(default)
export EKSD_PEERING_CONNECTION_ID=$(aws ec2 create-vpc-peering-connection --vpc-id $EKSD_VPC_ID --peer-vpc-id $DOCUMENTDB_VPC_ID --tag-specifications "ResourceType=vpc-peering-connection,Tags=[{Key=Name,Value=eksd-documentdb-peering}]" | jq -r '.VpcPeeringConnection.VpcPeeringConnectionId' )

## create a VPC peering connection between EKS VPC and DocumentDB VPC(default)
export EKS_PEERING_CONNECTION_ID=$(aws ec2 create-vpc-peering-connection --vpc-id $EKS_VPC_ID --peer-vpc-id $DOCUMENTDB_VPC_ID --tag-specifications "ResourceType=vpc-peering-connection,Tags=[{Key=Name,Value=eks-documentdb-peering}]" | jq -r '.VpcPeeringConnection.VpcPeeringConnectionId' )

## accepts the specified VPC peering connection request for EKS-D and EKS
aws ec2 accept-vpc-peering-connection --vpc-peering-connection-id $EKS_PEERING_CONNECTION_ID
aws ec2 accept-vpc-peering-connection --vpc-peering-connection-id $EKSD_PEERING_CONNECTION_ID


### Look up the the route tables that will be changed with new routes pointing to the peering connection

# Return the EKS Public Route Table
export EKS_RouteTableId=$(aws ec2 describe-route-tables --filters Name=tag:Name,Values=*Public* --query "RouteTables[?VpcId == '$EKS_VPC_ID'].RouteTableId" --output text)

# Return the EKS-D Public Route Table
export EKSD_RouteTableId=$(aws ec2 describe-route-tables --filters Name=tag:Name,Values=$EKSD_DOMAIN --query "RouteTables[?VpcId == '$EKSD_VPC_ID'].RouteTableId" --output text)

# Return the route table associated with the DocumentDB VPC(default)
export DocumentDB_RouteTableId=$(aws ec2 describe-route-tables --query "RouteTables[?VpcId == '$DOCUMENTDB_VPC_ID'].RouteTableId" --output text)


# Creates a route in the EKS Public route table. 
# The route matches traffic for the default VPC CIDR block and routes it to VPC peering connection. 
# This route enables traffic to be directed to the peer VPC in the VPC peering connection. 
aws ec2 create-route --route-table-id $EKS_RouteTableId --destination-cidr-block $DOCUMENTDB_VPC_CIDR --vpc-peering-connection-id $EKS_PEERING_CONNECTION_ID
aws ec2 create-route --route-table-id $EKSD_RouteTableId --destination-cidr-block $DOCUMENTDB_VPC_CIDR --vpc-peering-connection-id $EKSD_PEERING_CONNECTION_ID

# Routes from DocumentDB VPC(default) to EKS and EKS-D
aws ec2 create-route --route-table-id $DocumentDB_RouteTableId --destination-cidr-block $EKS_VPC_CIDR --vpc-peering-connection-id $EKS_PEERING_CONNECTION_ID
aws ec2 create-route --route-table-id $DocumentDB_RouteTableId --destination-cidr-block $EKSD_VPC_CIDR --vpc-peering-connection-id $EKSD_PEERING_CONNECTION_ID
