#!/usr/bin/env ruby

require 'bundler/setup'
require 'cloudformation-ruby-dsl/cfntemplate'
require 'cloudformation-ruby-dsl/spotprice'
require 'cloudformation-ruby-dsl/table'

template do
  value AWSTemplateFormatVersion: '2010-09-09'

  value Description: 'OpenShift service on a single master and node instance'

  parameter 'KeyName',
            Description: 'Name of an existing EC2 KeyPair to enable SSH access to the OpenShift host',
            Type: 'AWS::EC2::KeyPair::KeyName'

  parameter 'OpenShiftInstanceType',
            Description: 'OpenShift instance type',
            Type: 'String',
            Default: 't2.large'

  parameter 'OpenShiftAMI',
            Description: 'OpenShift AMI ID',
            Type: 'AWS::EC2::Image::Id',
            Default: 'ami-fedafc9d'

  parameter 'VpcId',
            Description: 'VPC to deploy the OpenShift host in.',
            Type: 'AWS::EC2::VPC::Id'

  parameter 'AvailabilityZone',
            Description: 'Availability zone to deploy the OpenShift data volume.',
            Type: 'AWS::EC2::AvailabilityZone::Name'

  parameter 'PublicSubnet1',
            Description: 'Public subnet to deploy the OpenShift host in.',
            Type: 'AWS::EC2::Subnet::Id'

  parameter 'PublicSubnet1Cidr',
            Description: 'Public subnet CIDR to deploy the OpenShift host in.',
            Type: 'String'

  parameter 'OpenShiftInstallS3BucketName',
            Description: 'S3 Bucket containing installation files.',
            Type: 'String'

  resource 'OpenShiftRole', Type: 'AWS::IAM::Role', Properties: {
    AssumeRolePolicyDocument: {
      Statement: [
        {
          Effect: 'Allow',
          Principal: { Service: 'ec2.amazonaws.com' },
          Action: 'sts:AssumeRole'
        }
      ]
    },
    Path: '/',
    Policies: [
      {
        PolicyName: 'openshift',
        PolicyDocument: {
          Statement: [
            {
              Effect: 'Allow',
              Action: ['ec2:*'],
              Resource: ['*']
            },
            {
              Effect: 'Allow',
              Action: ['elasticloadbalancing:*'],
              Resource: ['*']
            },
            {
              Effect: 'Allow',
              Action: ['cloudwatch:PutMetricAlarm', 'cloudwatch:PutMetricData', 'ec2:DescribeInstances', 'ec2:DescribeTags'],
              Resource: ['*']
            },
            {
              Effect: 'Allow',
              Action: ['logs:CreateLogGroup', 'logs:CreateLogStream', 'logs:PutLogEvents', 'logs:DescribeLogStreams'],
              Resource: ['arn:aws:logs:*:*:*']
            },
            {
              Effect: 'Allow',
              Action: ['s3:GetObject'],
              Resource: [join('', 'arn:aws:s3:::', ref('OpenShiftInstallS3BucketName'), '/*')]
            }
          ]
        }
      }
    ]
  }

  resource 'OpenShiftMasterInstanceProfile', Type: 'AWS::IAM::InstanceProfile', Properties: {
    Path: '/',
    Roles: [ref('OpenShiftRole')]
  }

  resource 'OpenShiftMasterDataVolume', Type: 'AWS::EC2::Volume', Properties: {
    Size: 100,
    AvailabilityZone: ref('AvailabilityZone'),
    Tags: [
      { Key: 'Name', Value: 'OpenShiftMasterDataVolume' }
    ]
  }

  resource 'OpenShiftMasterDataVolumeMount', Type: 'AWS::EC2::VolumeAttachment', Properties: {
    InstanceId: ref('OpenShiftMaster'),
    VolumeId: ref('OpenShiftMasterDataVolume'),
    Device: '/dev/sdk'
  }

  resource 'OpenShiftMaster', Type: 'AWS::EC2::Instance', Properties: {
    InstanceType: ref('OpenShiftInstanceType'),
    KeyName: ref('KeyName'),
    ImageId: ref('OpenShiftAMI'),
    IamInstanceProfile: ref('OpenShiftMasterInstanceProfile'),
    UserData: base64(interpolate(file('openshift-master-userdata.sh'))),
    NetworkInterfaces: [
      {
        GroupSet: [ref('OpenShiftMasterecurityGroup')],
        AssociatePublicIpAddress: 'true',
        DeviceIndex: '0',
        DeleteOnTermination: 'true',
        SubnetId: ref('PublicSubnet1')
      }
    ],
    Tags: [
      { Key: 'Name', Value: 'OpenShift Master' },
      { Key: 'OpenShift', Value: 'true' }
    ]
  }

  resource 'OpenShiftNodeDataVolume', Type: 'AWS::EC2::Volume', Properties: {
    Size: 100,
    AvailabilityZone: ref('AvailabilityZone'),
    Tags: [
      { Key: 'Name', Value: 'OpenShiftNodeDataVolume' }
    ]
  }

  resource 'OpenShiftNodeDataVolumeMount', Type: 'AWS::EC2::VolumeAttachment', Properties: {
    InstanceId: ref('OpenShiftNode'),
    VolumeId: ref('OpenShiftNodeDataVolume'),
    Device: '/dev/sdk'
  }

  resource 'OpenShiftNodeInstanceProfile', Type: 'AWS::IAM::InstanceProfile', Properties: {
    Path: '/',
    Roles: [ref('OpenShiftRole')]
  }

  resource 'OpenShiftNode', Type: 'AWS::EC2::Instance', Properties: {
    InstanceType: ref('OpenShiftInstanceType'),
    KeyName: ref('KeyName'),
    ImageId: ref('OpenShiftAMI'),
    IamInstanceProfile: ref('OpenShiftNodeInstanceProfile'),
    UserData: base64(interpolate(file('openshift-node-userdata.sh'))),
    NetworkInterfaces: [
      {
        GroupSet: [ref('OpenShiftNodeSecurityGroup')],
        AssociatePublicIpAddress: 'true',
        DeviceIndex: '0',
        DeleteOnTermination: 'true',
        SubnetId: ref('PublicSubnet1')
      }
    ],
    Tags: [
      { Key: 'Name', Value: 'OpenShift Node' },
      { Key: 'OpenShift', Value: 'true' }
    ]
  }

  resource 'OpenShiftMasterecurityGroup', Type: 'AWS::EC2::SecurityGroup', Properties: {
    GroupDescription: 'Enable access to the OpenShift host',
    VpcId: ref('VpcId'),
    SecurityGroupIngress: [
      { IpProtocol: 'tcp', FromPort: '22', ToPort: '22', CidrIp: '0.0.0.0/0' },
      { IpProtocol: 'tcp', FromPort: '53', ToPort: '53', CidrIp: ref('PublicSubnet1Cidr') },
      { IpProtocol: 'udp', FromPort: '53', ToPort: '53', CidrIp: ref('PublicSubnet1Cidr') },
      { IpProtocol: 'tcp', FromPort: '80', ToPort: '80', CidrIp: '0.0.0.0/0' },
      { IpProtocol: 'tcp', FromPort: '443', ToPort: '443', CidrIp: '0.0.0.0/0' },
      { IpProtocol: 'tcp', FromPort: '1936', ToPort: '1936', CidrIp: ref('PublicSubnet1Cidr') },
      { IpProtocol: 'udp', FromPort: '4789', ToPort: '4789', CidrIp: ref('PublicSubnet1Cidr') },
      { IpProtocol: 'tcp', FromPort: '8443', ToPort: '8443', CidrIp: ref('PublicSubnet1Cidr') },
      { IpProtocol: 'tcp', FromPort: '10250', ToPort: '10250', CidrIp: ref('PublicSubnet1Cidr') },
      { IpProtocol: 'tcp', FromPort: '10255', ToPort: '10255', CidrIp: ref('PublicSubnet1Cidr') },
      { IpProtocol: 'udp', FromPort: '10255', ToPort: '10255', CidrIp: ref('PublicSubnet1Cidr') },
      { IpProtocol: 'tcp', FromPort: '24224', ToPort: '24224', CidrIp: ref('PublicSubnet1Cidr') }
    ]
  }

  resource 'OpenShiftNodeSecurityGroup', Type: 'AWS::EC2::SecurityGroup', Properties: {
    GroupDescription: 'Enable access to the OpenShift host',
    VpcId: ref('VpcId'),
    SecurityGroupIngress: [
      { IpProtocol: 'tcp', FromPort: '22', ToPort: '22', CidrIp: '0.0.0.0/0' },
      { IpProtocol: 'tcp', FromPort: '80', ToPort: '80', CidrIp: '0.0.0.0/0' },
      { IpProtocol: 'tcp', FromPort: '443', ToPort: '443', CidrIp: '0.0.0.0/0' },
      { IpProtocol: 'udp', FromPort: '4789', ToPort: '4789', CidrIp: ref('PublicSubnet1Cidr') },
      { IpProtocol: 'tcp', FromPort: '10250', ToPort: '10250', CidrIp: ref('PublicSubnet1Cidr') },
      { IpProtocol: 'tcp', FromPort: '10255', ToPort: '10255', CidrIp: ref('PublicSubnet1Cidr') },
      { IpProtocol: 'udp', FromPort: '10255', ToPort: '10255', CidrIp: ref('PublicSubnet1Cidr') },
      { IpProtocol: 'udp', FromPort: '10255', ToPort: '10255', CidrIp: ref('PublicSubnet1Cidr') }
    ]
  }

  resource 'OpenShiftMasterIPAddress', Type: 'AWS::EC2::EIP', Properties: {
    InstanceId: ref('OpenShiftMaster')
  }

  output 'OpenShiftMasterInstanceId',
         Description: 'InstanceId of the OpenShift master',
         Value: ref('OpenShiftMaster')

  output 'OpenShiftNodeInstanceId',
         Description: 'InstanceId of the OpenShift node',
         Value: ref('OpenShiftNode')

  output 'OpenShiftMasterDataVolumeId',
         Description: 'VolumeId of the OpenShift master data',
         Value: ref('OpenShiftMasterDataVolume')

  output 'OpenShiftNodeDataVolumeId',
         Description: 'VolumeId of the OpenShift node data',
         Value: ref('OpenShiftNodeDataVolume')

  output 'OpenShiftMasterPublicIp',
         Description: 'Public IP address of the OpenShift master',
         Value: get_att('OpenShiftMaster', 'PublicIp')

  output 'OpenShiftNodePublicIp',
         Description: 'Public IP address of the OpenShift node',
         Value: get_att('OpenShiftNode', 'PublicIp')
end.exec!
