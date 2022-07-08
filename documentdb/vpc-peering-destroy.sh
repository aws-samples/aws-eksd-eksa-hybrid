# Remove Routes from EKS and EKS-D to DocumentDB VPC(default) 
aws ec2 delete-route --route-table-id $EKS_RouteTableId --destination-cidr-block $DOCUMENTDB_VPC_CIDR 
aws ec2 delete-route --route-table-id $EKSD_RouteTableId --destination-cidr-block $DOCUMENTDB_VPC_CIDR 

# Remove Routes from DocumentDB VPC(default) to EKS and EKS-D
aws ec2 delete-route --route-table-id $DocumentDB_RouteTableId --destination-cidr-block $EKS_VPC_CIDR 
aws ec2 delete-route --route-table-id $DocumentDB_RouteTableId --destination-cidr-block $EKSD_VPC_CIDR 

# delete both EKS-D and EKS VPC peering connection with Amazon DocumentDB(default VPC).
aws ec2 delete-vpc-peering-connection --vpc-peering-connection-id $EKSD_PEERING_CONNECTION_ID
aws ec2 delete-vpc-peering-connection --vpc-peering-connection-id $EKS_PEERING_CONNECTION_ID
