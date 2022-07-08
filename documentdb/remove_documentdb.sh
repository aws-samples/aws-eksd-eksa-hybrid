aws docdb delete-db-instance --db-instance-identifier $DBCLUSTER_NAME-instance
aws docdb delete-db-cluster --db-cluster-identifier $DBCLUSTER_NAME --skip-final-snapshot
sleep 5
aws ec2 delete-security-group --group-name MoviesDBClusterSecurityGroup 
