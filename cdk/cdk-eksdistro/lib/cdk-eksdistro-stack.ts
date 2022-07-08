import * as ec2 from "aws-cdk-lib/aws-ec2";
import * as cdk from 'aws-cdk-lib';
import * as iam from 'aws-cdk-lib/aws-iam'
import * as path from 'path';
import { KeyPair } from 'cdk-ec2-key-pair';
import { Asset } from 'aws-cdk-lib/aws-s3-assets';

import { Duration, Stack, StackProps } from 'aws-cdk-lib';
import { Construct } from 'constructs';

export class CdkEksDistroStack extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);


    // Create a Key Pair to be used with this EC2 Instance
    const key = new KeyPair(this, 'KeyPair', {
       name: 'cdk-eksd-key-pair',
       description: 'Key Pair created with CDK Deployment',
    });
    key.grantReadOnPublicKey

    const vpc = ec2.Vpc.fromLookup(this, 'DefaultVPC', { isDefault: true });
    
    // Allow SSH (TCP Port 22) access from anywhere
    const securityGroup = new ec2.SecurityGroup(this, 'SecurityGroup', {
      vpc,
      description: 'Allow SSH (TCP port 22) in',
      allowAllOutbound: true
    });
    securityGroup.addIngressRule(ec2.Peer.anyIpv4(), ec2.Port.tcp(22), 'Allow SSH Access')

    const role = new iam.Role(this, 'ec2-EKSD-Role', {
      assumedBy: new iam.ServicePrincipal('ec2.amazonaws.com')
    })
    
    role.addManagedPolicy(iam.ManagedPolicy.fromAwsManagedPolicyName('AmazonSSMManagedInstanceCore'))
    role.addManagedPolicy(iam.ManagedPolicy.fromAwsManagedPolicyName('AmazonEC2FullAccess'))
    role.addManagedPolicy(iam.ManagedPolicy.fromAwsManagedPolicyName('AmazonRoute53FullAccess'))
    role.addManagedPolicy(iam.ManagedPolicy.fromAwsManagedPolicyName('AmazonS3FullAccess'))
    role.addManagedPolicy(iam.ManagedPolicy.fromAwsManagedPolicyName('IAMFullAccess'))
    role.addManagedPolicy(iam.ManagedPolicy.fromAwsManagedPolicyName('AmazonVPCFullAccess'))
    role.addManagedPolicy(iam.ManagedPolicy.fromAwsManagedPolicyName('AmazonSQSFullAccess'))
    role.addManagedPolicy(iam.ManagedPolicy.fromAwsManagedPolicyName('AmazonEventBridgeFullAccess'))
    role.addManagedPolicy(iam.ManagedPolicy.fromAwsManagedPolicyName('AdministratorAccess'))

    // CPU Type X86_64
    const ami = new ec2.AmazonLinuxImage({
      generation: ec2.AmazonLinuxGeneration.AMAZON_LINUX_2,
      cpuType: ec2.AmazonLinuxCpuType.X86_64
    });
    

    // Create the instance using the Security Group, AMI, and KeyPair defined in the VPC created
    const ec2Instance = new ec2.Instance(this, 'Instance', {
      vpc,
      instanceType: ec2.InstanceType.of(ec2.InstanceClass.T3, ec2.InstanceSize.LARGE),
      machineImage: ami,
      init: ec2.CloudFormationInit.fromElements(
          ec2.InitCommand.shellCommand('sudo yum update -y'),
          ec2.InitCommand.shellCommand('sudo yum install git -y'),
          ec2.InitCommand.shellCommand('sudo yum install jq -y')
      ),
      blockDevices: [
          {
            deviceName: '/dev/xvda',
            volume: ec2.BlockDeviceVolume.ebs(50),
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
    new cdk.CfnOutput(this, 'Download Key Command', { value: 'aws secretsmanager get-secret-value --secret-id ec2-ssh-key/cdk-eksd-key-pair/private --query SecretString --output text > cdk-eksd-key-pair.pem && chmod 400 cdk-eksd-key-pair.pem' })
    new cdk.CfnOutput(this, 'SSH command', { value: 'ssh -i cdk-eksd-key-pair.pem -o IdentitiesOnly=yes ec2-user@' + ec2Instance.instancePublicIp })
    new cdk.CfnOutput(this, 'EC2 Public IP address', { value: ec2Instance.instancePublicIp })
    new cdk.CfnOutput(this, 'kubeconfig scp command', { value: 'scp -i cdk-eksd-key-pair.pem ec2-user@' + ec2Instance.instancePublicIp + ':$HOME/.kube/config $HOME/.kube/config' })

  }
}
