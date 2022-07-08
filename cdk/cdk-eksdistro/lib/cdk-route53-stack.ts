import cdk = require('aws-cdk-lib');
import route53 = require('aws-cdk-lib/aws-route53');
import iam = require('aws-cdk-lib/aws-iam');

import { Duration, Stack, StackProps } from 'aws-cdk-lib';
import { Construct } from 'constructs';


export class CdkRoute53Stack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
  //constructor(scope: cdk.App, id: string, props?: cdk.StackProps) {
    super(scope, id, props);
    
    const crossAccountRoute53 = this.node.tryGetContext('crossAccountRoute53');
    const zoneName = this.node.tryGetContext('zoneName');
    const subZoneName = this.node.tryGetContext('subZoneName');


    if (crossAccountRoute53) {
        
        const IsParentAccount = this.node.tryGetContext('IsParentAccount');

        if (IsParentAccount) {
            const childAccountId = this.node.tryGetContext('childAccountId'); 

            
            // Parent hosted zone is created. Child hosted zone will be exported into this record
            const parentZone = new route53.PublicHostedZone(this, 'HostedZone', {
                  zoneName: zoneName, // 'aboavent.net'
                  crossAccountZoneDelegationPrincipal: new iam.AccountPrincipal(childAccountId),
                  crossAccountZoneDelegationRoleName: 'MyRoute53DelegationRole',
            }); 
             
        } else {
          
          // Child hosted zone is created
          const subZone = new route53.PublicHostedZone(this, 'SubZone', {
              zoneName: subZoneName // E.g.: 'eksd.aboavent.net'
          });
          
          // import the delegation role by constructing the roleArn
          const parentAccountId = this.node.tryGetContext('parentAccountId');

          const delegationRoleArn = Stack.of(this).formatArn({
            region: '', // IAM is global in each partition
            service: 'iam',
            account: parentAccountId, 
            resource: 'role',
            resourceName: 'MyRoute53DelegationRole',
          });
          const delegationRole = iam.Role.fromRoleArn(this, 'DelegationRole', delegationRoleArn);
          
          // Export the record under the parent Hosted Zone in a different AWS account
          new route53.CrossAccountZoneDelegationRecord(this, 'delegate', {
            delegatedZone: subZone,
            parentHostedZoneName: zoneName, // E.g.: 'aboavent.net' or you can use parentHostedZoneId
            delegationRole,
          });
          
        }
        
    } else {
        
        // Parent hosted zone creation
        //new route53.PublicHostedZone(this, 'HostedZone', {
        //    zoneName: zoneName // E.g.: 'aboavent.net'
        //});
        
        // Child hosted zone is created
        new route53.PublicHostedZone(this, 'SubZone', {
            zoneName: subZoneName // E.g.: 'eksd.aboavent.net'
        });
    
    }
    
  }
}
