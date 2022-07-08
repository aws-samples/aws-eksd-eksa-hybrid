#!/usr/bin/env node
import * as cdk from 'aws-cdk-lib';
import { CdkEksDistroStack } from '../lib/cdk-eksdistro-stack';
import { CdkRoute53Stack } from '../lib/cdk-route53-stack';


/*
if (!process.env.AWS_REGION) {
    console.error("Please specify the AWS region with the AWS_REGION environment variable");
    process.exit(1);
}
*/

const app = new cdk.App();

// Route53 Stack - requirement for running the EKS Distro stack
const stackRoute53 = new CdkRoute53Stack(app, 'CdkRoute53Stack');

// EKS Distro Stack
const stackEKSD = new CdkEksDistroStack(app, 'CdkEksDistroStack', { 
  env: { 
    account: process.env.CDK_DEPLOY_ACCOUNT || process.env.CDK_DEFAULT_ACCOUNT, 
    region: process.env.CDK_DEPLOY_REGION || process.env.CDK_DEFAULT_REGION 
}});
stackEKSD.addDependency(stackRoute53);



