#!/usr/bin/env bash

echo 'performing security updates'
yum -y update --security

echo 'installing tools'
yum -y install epel-release awscli NetworkManager vim sysstat

echo "enable NetworkManager"

systemctl reload-daemon
systemctl enable NetworkManager
systemctl start NetworkManager

echo "aws region is {{ ref('AWS::Region') }}"

mkdir /var/install
aws --region {{ ref('AWS::Region') }} s3 cp s3://{{ ref('OpenShiftInstallS3BucketName') }}/aws-cfn-bootstrap-1.4-8.3.el7.centos.noarch.rpm /var/install
yum -y install /var/install/aws-cfn-bootstrap-1.4-8.3.el7.centos.noarch.rpm

echo 'installing dependencies'
yum -y install wget git net-tools bind-utils iptables-services bridge-utils bash-completion

echo 'disable epel'
sed -i -e "s/^enabled=1/enabled=0/" /etc/yum.repos.d/epel.repo

echo 'install docker'
yum -y install docker

sed -i -e "s/^OPTIONS=.*/OPTIONS='--selinux-enabled --insecure-registry 172.30.0.0\/16'/" /etc/sysconfig/docker

echo 'configure docker data volume'

cat <<EOF > /etc/sysconfig/docker-storage-setup
DEVS=/dev/xvdk
VG=docker-vg
EOF

docker-storage-setup

rm -rf /var/lib/docker/*

echo 'install ansible'

yum -y --enablerepo=epel install ansible1.9 pyOpenSSL python-pip

/opt/aws/bin/cfn-init -e $? --stack {{ ref('AWS::StackId') }} --resource OpenShiftNode --region {{ ref('AWS::Region') }}
