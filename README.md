# EC2 Instance Spawner

This PowerShell script allows you to easily spawn AWS EC2 instances with specified parameters. It supports choosing the Amazon Machine Image (AMI), instance type, subnet, security groups and key pairs. It also has functionality to handle and retrieve password for Windows instances.

## Prerequisites

- [AWS CLI](https://aws.amazon.com/cli/) installed and configured.
- [OpenSSL](https://www.openssl.org/) installed and configured.
- PowerShell installed.
- You must have necessary permissions to create and manage EC2 instances, VPCs, Subnets, KeyPairs, and Security Groups in your AWS Account.

## Parameters

The script accepts the following parameters:

- `InstanceType`: The type of instance to launch (default: `"t3.micro"`).
- `Image`: ID of the AMI to use (optional).
- `SecurityGroupIds`: ID of the security group to use (optional).
- `SubnetId`: ID of the subnet to use (optional).
- `Count`: Number of instances to launch (default: `1`).

If the `Image`, `SecurityGroupIds` or `SubnetId` parameters are not provided, the script will prompt the user to choose them interactively.

## Functions

The script contains several helper functions:

- `Select-AMI`: Allows the user to choose an AMI if the `Image` parameter is not provided.
- `Select-SubnetId`: Allows the user to choose a subnet if the `SubnetId` parameter is not provided.
- `Select-Key`: Allows the user to choose a key pair.
- `Get-EC2InstancePassword`: Retrieves the password for a Windows instance.
- `Spawn-Instance`: Creates the instance and outputs its details.

## Usage

To use the script, open your PowerShell terminal and navigate to the directory containing the script.

Run script specifying parameters:

```powershell
.\scriptname.ps1 -InstanceType t3.micro -Image ami-0989fb15ce71ba39e -SecurityGroupIds sg-05bd95c26abcbfe16 -SubnetId subnet-a02adf9e -Count 1
```

## Notes

- The script uses the default VPC if the subnet is not specified.
- For Windows instances, it attempts to retrieve the plaintext password for RDP. The user will be prompted to specify the path to the keypair file for this.
- Please ensure that you have necessary permissions and credits available in your AWS account to spawn instances.
- **Be aware of AWS costs that can incur by running instances.**