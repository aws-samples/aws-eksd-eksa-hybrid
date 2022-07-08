import * as ec2 from "aws-cdk-lib/aws-ec2";
import * as cdk from 'aws-cdk-lib';
import * as iam from 'aws-cdk-lib/aws-iam'
import * as path from 'path';
import { KeyPair } from 'cdk-ec2-key-pair';
import { Asset } from 'aws-cdk-lib/aws-s3-assets';
import { Duration, Stack, StackProps } from 'aws-cdk-lib';
import { Construct } from 'constructs';

export class CdkEksAnywhereStack extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    // Create a Key Pair to be used with this EC2 Instance
    const key = new KeyPair(this, 'KeyPair', {
       name: 'cdk-eksa-key-pair',
       description: 'Key Pair created with CDK Deployment',
    });
    key.grantReadOnPublicKey

    // Look for default VPC
    const vpc = ec2.Vpc.fromLookup(this, 'DefaultVPC', { isDefault: true });
    
    // Security group for the EC2 instance hosting the EKS Anywhere cluster
    const securityGroup = new ec2.SecurityGroup(this, 'SecurityGroup', {
      vpc,
      description: 'Allow SSH (TCP port 22) in and kubectl connection to the EKS Anywhere cluster from the AWS Cloud9 environment',
      allowAllOutbound: true
    });
    securityGroup.addIngressRule(ec2.Peer.anyIpv4(), ec2.Port.tcp(22), 'Allow SSH Access')
    securityGroup.addIngressRule(ec2.Peer.anyIpv4(), ec2.Port.tcpRange(30000,50000), 'Allow kubectl Access')

    const role = new iam.Role(this, 'ec2-EKSA-Role', {
      assumedBy: new iam.ServicePrincipal('ec2.amazonaws.com')
    })

    //role.addManagedPolicy(iam.ManagedPolicy.fromAwsManagedPolicyName('AmazonSSMManagedInstanceCore'))
    // This policy allows Amazon EKS to manage AWS resources for EKS connector
    //role.addManagedPolicy(iam.ManagedPolicy.fromAwsManagedPolicyName('AmazonEKSClusterPolicy'))
    role.addManagedPolicy(iam.ManagedPolicy.fromAwsManagedPolicyName('AdministratorAccess'))

    // CPU Type X86_64
    const ami = new ec2.AmazonLinuxImage({
      generation: ec2.AmazonLinuxGeneration.AMAZON_LINUX_2,
      cpuType: ec2.AmazonLinuxCpuType.X86_64
    });
    
    // Create the instance using the Security Group, AMI, and KeyPair defined earlier
    const ec2Instance = new ec2.Instance(this, 'Instance', {
      vpc,
      instanceType: ec2.InstanceType.of(ec2.InstanceClass.M5, ec2.InstanceSize.XLARGE2),
      machineImage: ami,
      init: ec2.CloudFormationInit.fromElements(
          ec2.InitCommand.shellCommand('sudo yum update -y'),
          ec2.InitCommand.shellCommand('sudo yum install git -y'),
          ec2.InitCommand.shellCommand('sudo yum install jq -y')
      ),
      blockDevices: [
          {
            deviceName: '/dev/xvda',
            volume: ec2.BlockDeviceVolume.ebs(100),
          }
      ],     
      securityGroup: securityGroup,
      keyName: key.keyPairName,
      role: role
    });

    // Create an asset that will be used as part of User Data to run on first load
    const asset = new Asset(this, 'Asset', { path: path.join(__dirname, '../src/config.sh') });
    const localPath = ec2Instance.userData.addS3DownloadCommand({
      bucket: asset.bucket,
      bucketKey: asset.s3ObjectKey,
    });

    ec2Instance.userData.addExecuteFileCommand({
      filePath: localPath,
      arguments: '--verbose -y'
    });
    asset.grantRead(ec2Instance.role);

    // Create outputs for connecting
    new cdk.CfnOutput(this, 'Download Key Command', { value: 'aws secretsmanager get-secret-value --secret-id ec2-ssh-key/cdk-eksa-key-pair/private --query SecretString --output text > cdk-eksa-key-pair.pem && chmod 400 cdk-eksa-key-pair.pem' })
    new cdk.CfnOutput(this, 'SSH command', { value: 'ssh -i cdk-eksa-key-pair.pem -o IdentitiesOnly=yes ec2-user@' + ec2Instance.instancePublicIp })
    new cdk.CfnOutput(this, 'EC2 Public IP address', { value: ec2Instance.instancePublicIp })
    new cdk.CfnOutput(this, 'kubeconfig scp command', { value: 'scp -i cdk-eksa-key-pair.pem ec2-user@' + ec2Instance.instancePublicIp + ':$HOME/.kube/config $HOME/.kube/config' })

  }
}
