#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { CdkEksAnywhereStack } from '../lib/cdk-eksanywhere-stack';

const app = new cdk.App();

// EKS Anywhere Stack
const stackEKSD = new CdkEksAnywhereStack(app, 'CdkEksAnywhereStack', { 
  env: { 
    account: process.env.CDK_DEPLOY_ACCOUNT || process.env.CDK_DEFAULT_ACCOUNT, 
    region: process.env.CDK_DEPLOY_REGION || process.env.CDK_DEFAULT_REGION 
}});
