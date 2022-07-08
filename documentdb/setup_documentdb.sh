export DBCLUSTER_NAME=moviesdb-cluster
export DBCLUSTER_MASTERUSERNAME=movies
export DBCLUSTER_MASTERUSERPWD=movies123
export DBCLUSTER_PORT=27017
export DBCLUSTER_SECURITY_GROUP_NAME=MoviesDBClusterSecurityGroup

# Create a security group for the Movies DB in Amazon DocumentDB and assign an inbound rule for the cluster port
export DBCLUSTER_SECURITY_GROUP_ID=$(aws ec2 create-security-group --group-name $DBCLUSTER_SECURITY_GROUP_NAME --description "DocumentDB cluster security group" | jq -r '.GroupId')
aws ec2 authorize-security-group-ingress \
    --group-name $DBCLUSTER_SECURITY_GROUP_NAME \
    --protocol tcp \
    --port $DBCLUSTER_PORT \
    --cidr 0.0.0.0/0

# The following command create-db-cluster creates an Amazon DocumentDB cluster
aws docdb create-db-cluster \
    --db-cluster-identifier $DBCLUSTER_NAME \
    --engine docdb \
    --master-username $DBCLUSTER_MASTERUSERNAME \
    --master-user-password $DBCLUSTER_MASTERUSERPWD \
    --vpc-security-group-ids $DBCLUSTER_SECURITY_GROUP_ID

export DBCLUSTER_ENDPOINT=$(aws docdb describe-db-clusters --db-cluster-identifier $DBCLUSTER_NAME | jq -r '.DBClusters[].Endpoint')
export DBCLUSTER_PORT=$(aws docdb describe-db-clusters --db-cluster-identifier $DBCLUSTER_NAME | jq -r '.DBClusters[].Port')

# Creates a new instance in the Amazon DocumentDB cluster
aws docdb create-db-instance \
    --db-cluster-identifier $DBCLUSTER_NAME \
    --db-instance-class db.r5.xlarge \
    --db-instance-identifier $DBCLUSTER_NAME-instance \
    --engine docdb
    
# To encrypt data in transit and use TLS to access Amazon DocumentDB we need to download the public key from below the location below into the node-rest-api folder
wget -P ../node-rest-api/  https://s3.amazonaws.com/rds-downloads/rds-combined-ca-bundle.pem 
cp ../node-rest-api/rds-combined-ca-bundle.pem .

# This variable will be used to connect to Amazon DocumentDB using mongosh and will replace the Mongoose connection string in the ../node-rest-api/app.js file
export DBCLUSTER_CONNECTION_STRING="mongodb://$DBCLUSTER_MASTERUSERNAME:$DBCLUSTER_MASTERUSERPWD@$DBCLUSTER_ENDPOINT:$DBCLUSTER_PORT/movies?tls=true&tlsCAFile=rds-combined-ca-bundle.pem&retryWrites=false"
export DBCLUSTER_CONNECTION_STRING_ESCAPE="mongodb://$DBCLUSTER_MASTERUSERNAME:$DBCLUSTER_MASTERUSERPWD@$DBCLUSTER_ENDPOINT:$DBCLUSTER_PORT/movies?tls=true\&tlsCAFile=rds-combined-ca-bundle.pem\&retryWrites=false"

# Installing mongo shell on the AWS Cloud9 environment
wget https://downloads.mongodb.com/compass/mongosh-1.1.7-linux-x64.tgz
tar -xvf mongosh-1.1.7-linux-x64.tgz
sudo cp mongosh-1.1.7-linux-x64/bin/mongosh /usr/local/bin/
