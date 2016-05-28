#!/usr/bin/env ruby

require 'bundler/setup'
require 'cloudformation-ruby-dsl/cfntemplate'
require 'cloudformation-ruby-dsl/spotprice'
require 'cloudformation-ruby-dsl/table'

template do
  value AWSTemplateFormatVersion: '2010-09-09'

  value Description: 'VPC that has two public subnets and two private subnets in different AZs'

  parameter 'VPCName',
            Description: 'OpenShift instance type',
            Type: 'String'

  resource 'VPC', Type: 'AWS::EC2::VPC', Properties: {
    CidrBlock: '10.0.0.0/16',
    Tags: [
      { Key: 'Name', Value: ref('VPCName') },
      {
        Key: 'Application',
        Value: aws_stack_id
      },
      { Key: 'Network', Value: 'Public' }
    ]
  }

  resource 'PublicSubnet1', Type: 'AWS::EC2::Subnet', Properties: {
    VpcId: ref('VPC'),
    CidrBlock: '10.0.0.0/24',
    AvailabilityZone: select('0', get_azs(ref('AWS::Region'))),
    Tags: [
      { Key: 'Name', Value: join('-', ref('VPCName'), 'public-a') },
      {
        Key: 'Application',
        Value: aws_stack_id
      },
      { Key: 'Network', Value: 'Public' }
    ]
  }

  resource 'PublicSubnet2', Type: 'AWS::EC2::Subnet', Properties: {
    VpcId: ref('VPC'),
    CidrBlock: '10.0.2.0/24',
    AvailabilityZone: select('1', get_azs(ref('AWS::Region'))),
    Tags: [
      { Key: 'Name', Value: join('-', ref('VPCName'), 'public-b') },
      {
        Key: 'Application',
        Value: aws_stack_id
      },
      { Key: 'Network', Value: 'Public' }
    ]
  }

  resource 'InternetGateway', Type: 'AWS::EC2::InternetGateway', Properties: {
    Tags: [
      {
        Key: 'Application',
        Value: aws_stack_id
      },
      { Key: 'Network', Value: 'Public' }
    ]
  }

  resource 'GatewayToInternet', Type: 'AWS::EC2::VPCGatewayAttachment', Properties: {
    VpcId: ref('VPC'),
    InternetGatewayId: ref('InternetGateway')
  }

  resource 'PublicRouteTable', Type: 'AWS::EC2::RouteTable', Properties: {
    VpcId: ref('VPC'),
    Tags: [
      {
        Key: 'Application',
        Value: aws_stack_id
      },
      { Key: 'Network', Value: 'Public' }
    ]
  }

  resource 'PublicRoute', Type: 'AWS::EC2::Route', DependsOn: 'GatewayToInternet', Properties: {
    RouteTableId: ref('PublicRouteTable'),
    DestinationCidrBlock: '0.0.0.0/0',
    GatewayId: ref('InternetGateway')
  }

  resource 'PublicSubnetRouteTableAssociation1', Type: 'AWS::EC2::SubnetRouteTableAssociation', Properties: {
    SubnetId: ref('PublicSubnet1'),
    RouteTableId: ref('PublicRouteTable')
  }

  resource 'PublicSubnetRouteTableAssociation2', Type: 'AWS::EC2::SubnetRouteTableAssociation', Properties: {
    SubnetId: ref('PublicSubnet2'),
    RouteTableId: ref('PublicRouteTable')
  }

  resource 'PublicNetworkAcl', Type: 'AWS::EC2::NetworkAcl', Properties: {
    VpcId: ref('VPC'),
    Tags: [
      {
        Key: 'Application',
        Value: aws_stack_id
      },
      { Key: 'Network', Value: 'Public' }
    ]
  }

  resource 'InboundHTTPPublicNetworkAclEntry', Type: 'AWS::EC2::NetworkAclEntry', Properties: {
    NetworkAclId: ref('PublicNetworkAcl'),
    RuleNumber: '100',
    Protocol: '6',
    RuleAction: 'allow',
    Egress: 'false',
    CidrBlock: '0.0.0.0/0',
    PortRange: { From: '80', To: '80' }
  }

  resource 'InboundHTTPSPublicNetworkAclEntry', Type: 'AWS::EC2::NetworkAclEntry', Properties: {
    NetworkAclId: ref('PublicNetworkAcl'),
    RuleNumber: '101',
    Protocol: '6',
    RuleAction: 'allow',
    Egress: 'false',
    CidrBlock: '0.0.0.0/0',
    PortRange: { From: '443', To: '443' }
  }

  resource 'InboundSSHPublicNetworkAclEntry', Type: 'AWS::EC2::NetworkAclEntry', Properties: {
    NetworkAclId: ref('PublicNetworkAcl'),
    RuleNumber: '102',
    Protocol: '6',
    RuleAction: 'allow',
    Egress: 'false',
    CidrBlock: '0.0.0.0/0',
    PortRange: { From: '22', To: '22' }
  }

  resource 'InboundDynamicPortsPublicNetworkAclEntry', Type: 'AWS::EC2::NetworkAclEntry', Properties: {
    NetworkAclId: ref('PublicNetworkAcl'),
    RuleNumber: '103',
    Protocol: '6',
    RuleAction: 'allow',
    Egress: 'false',
    CidrBlock: '0.0.0.0/0',
    PortRange: { From: '1024', To: '65535' }
  }

  resource 'OutboundPublicNetworkAclEntry', Type: 'AWS::EC2::NetworkAclEntry', Properties: {
    NetworkAclId: ref('PublicNetworkAcl'),
    RuleNumber: '100',
    Protocol: '6',
    RuleAction: 'allow',
    Egress: 'true',
    CidrBlock: '0.0.0.0/0',
    PortRange: { From: '0', To: '65535' }
  }

  resource 'PublicSubnetNetworkAclAssociation1', Type: 'AWS::EC2::SubnetNetworkAclAssociation', Properties: {
    SubnetId: ref('PublicSubnet1'),
    NetworkAclId: ref('PublicNetworkAcl')
  }

  resource 'PublicSubnetNetworkAclAssociation2', Type: 'AWS::EC2::SubnetNetworkAclAssociation', Properties: {
    SubnetId: ref('PublicSubnet2'),
    NetworkAclId: ref('PublicNetworkAcl')
  }

  resource 'PrivateSubnet1', Type: 'AWS::EC2::Subnet', Properties: {
    VpcId: ref('VPC'),
    CidrBlock: '10.0.1.0/24',
    AvailabilityZone: select('0', get_azs(ref('AWS::Region'))),
    Tags: [
      { Key: 'Name', Value: join('-', ref('VPCName'), 'private-a') },
      {
        Key: 'Application',
        Value: aws_stack_id
      },
      { Key: 'Network', Value: 'Private' }
    ]
  }

  resource 'PrivateSubnet2', Type: 'AWS::EC2::Subnet', Properties: {
    VpcId: ref('VPC'),
    CidrBlock: '10.0.3.0/24',
    AvailabilityZone: select('1', get_azs(ref('AWS::Region'))),
    Tags: [
      { Key: 'Name', Value: join('-', ref('VPCName'), 'private-b') },
      {
        Key: 'Application',
        Value: aws_stack_id
      },
      { Key: 'Network', Value: 'Private' }
    ]
  }

  resource 'PrivateRouteTable1', Type: 'AWS::EC2::RouteTable', Properties: {
    VpcId: ref('VPC'),
    Tags: [
      {
        Key: 'Application',
        Value: aws_stack_id
      },
      { Key: 'Network', Value: 'Private' }
    ]
  }

  resource 'PrivateRouteTable2', Type: 'AWS::EC2::RouteTable', Properties: {
    VpcId: ref('VPC'),
    Tags: [
      {
        Key: 'Application',
        Value: aws_stack_id
      },
      { Key: 'Network', Value: 'Private' }
    ]
  }

  resource 'PrivateSubnetRouteTableAssociation1', Type: 'AWS::EC2::SubnetRouteTableAssociation', Properties: {
    SubnetId: ref('PrivateSubnet1'),
    RouteTableId: ref('PrivateRouteTable1')
  }

  resource 'PrivateSubnetRouteTableAssociation2', Type: 'AWS::EC2::SubnetRouteTableAssociation', Properties: {
    SubnetId: ref('PrivateSubnet2'),
    RouteTableId: ref('PrivateRouteTable2')
  }

  resource 'PrivateNetworkAcl', Type: 'AWS::EC2::NetworkAcl', Properties: {
    VpcId: ref('VPC'),
    Tags: [
      {
        Key: 'Application',
        Value: aws_stack_id
      },
      { Key: 'Network', Value: 'Private' }
    ]
  }

  resource 'InboundPrivateNetworkAclEntry', Type: 'AWS::EC2::NetworkAclEntry', Properties: {
    NetworkAclId: ref('PrivateNetworkAcl'),
    RuleNumber: '100',
    Protocol: '6',
    RuleAction: 'allow',
    Egress: 'false',
    CidrBlock: '0.0.0.0/0',
    PortRange: { From: '0', To: '65535' }
  }

  resource 'OutboundPrivateNetworkAclEntry', Type: 'AWS::EC2::NetworkAclEntry', Properties: {
    NetworkAclId: ref('PrivateNetworkAcl'),
    RuleNumber: '100',
    Protocol: '6',
    RuleAction: 'allow',
    Egress: 'true',
    CidrBlock: '0.0.0.0/0',
    PortRange: { From: '0', To: '65535' }
  }

  resource 'PrivateSubnetNetworkAclAssociation1', Type: 'AWS::EC2::SubnetNetworkAclAssociation', Properties: {
    SubnetId: ref('PrivateSubnet1'),
    NetworkAclId: ref('PrivateNetworkAcl')
  }

  resource 'PrivateSubnetNetworkAclAssociation2', Type: 'AWS::EC2::SubnetNetworkAclAssociation', Properties: {
    SubnetId: ref('PrivateSubnet2'),
    NetworkAclId: ref('PrivateNetworkAcl')
  }

  output 'VpcId',
         Description: 'VPC',
         Value: ref('VPC')

  output 'PublicSubnets',
         Description: 'Public subnet',
         Value: join(',', ref('PublicSubnet1'), ref('PublicSubnet2'))

  output 'PrivateSubnets',
         Description: 'Private subnet',
         Value: join(',', ref('PrivateSubnet1'), ref('PrivateSubnet2'))

  output 'AZs',
         Description: 'Availability zones',
         Value: join(',', get_att('PrivateSubnet1', 'AvailabilityZone'), get_att('PrivateSubnet2', 'AvailabilityZone'))
end.exec!
