param (
    [string]$InstanceType = "t3.micro",
    [string]$Image,
    [string]$SecurityGroupIds,
    [string]$SubnetId,
    [int]$Count = 1
)

function Select-AMI {
    if ($Image) {
        if (-not (aws ec2 describe-images --image-ids $Image --query 'Images[0].ImageId' --output text)) {
            Write-Host "Invalid AMI specified. Exiting."
            Exit
        }
        return $Image
    }
    else {
        # Specify AMI options
        $AmiOptions = @{
            "ubuntu" = "ami-0989fb15ce71ba39e"
            "windows" = "ami-0d886e76c1d93140c"
            "kali" = "ami-0e53e1d4b55fb9170"
        }

        # Prompt the user to choose an AMI
        Write-Host "Available AMI options:"
        $AmiOptions.Keys | ForEach-Object {
            Write-Host "- $_"
        }

        $chosenAmi = Read-Host "Choose an AMI"

        if (-not $AmiOptions.ContainsKey($chosenAmi)) {
            Write-Host "Invalid AMI choice. Exiting."
            Exit
        }

        return $AmiOptions[$chosenAmi]
    }
}

function Select-SubnetId {
    # Get the subnets in the default VPC
    $subnetsJson = aws ec2 describe-subnets --filters Name=vpc-id,Values=$DefaultVPC | ConvertFrom-Json

    if ($subnetsJson.Subnets.Length -eq 0) {
        Write-Error "No subnets found in the default VPC."
        return $null
    }

    # Create a list of subnet objects with ID and CIDR
    $subnetList = $subnetsJson.Subnets | ForEach-Object { New-Object PSObject -Property @{
        Id = $_.SubnetId;
        Cidr = $_.CidrBlock;
    } }

    # Prompt the user to select a subnet
    $subnetSelectionMenu = @{}
    Write-Host "Select a subnet:"
    for ($i=1; $i -le $subnetList.Count; $i++) {
        $subnetSelectionMenu.Add($i, $subnetList[$i-1])
        Write-Host "${i}: $($subnetList[$i-1].Id) ($($subnetList[$i-1].Cidr))"
    }

    [int]$userSelection = Read-Host "Enter the number of your selection"
    return $subnetSelectionMenu[$userSelection].Id
}

function Select-Key {
    # Get the list of available key pairs
    $KeyPairs = aws ec2 describe-key-pairs --query 'KeyPairs[*].KeyName' --output text

    # Prompt the user to choose a key pair
    Write-Host "Available Key Pairs:"
    $KeyPairs | ForEach-Object {
        Write-Host "- $_"
    }

    $ChosenKeyPair = Read-Host "Choose a Key Pair"

    if ($KeyPairs -notcontains $ChosenKeyPair) {
        Write-Host "Invalid Key Pair choice. Exiting."
        Exit
    }

    return $ChosenKeyPair
}

function Get-EC2InstancePassword {
    param (
        [Parameter(Mandatory=$true)][string]$InstanceId,
        [Parameter(Mandatory=$true)][string]$KeypairPath,
        [Parameter(Mandatory=$true)][string]$PasswordDataFilePath
    )

    # Initialize PasswordData as null
    $PasswordData = $null

    # Keep trying to get password data until it's available
    Write-Host -NoNewline "Waiting for password data to become available..."
    while ([string]::IsNullOrEmpty($PasswordData)) {
        # Get encrypted password data
        $PasswordDataJson = aws ec2 get-password-data --instance-id $InstanceId | ConvertFrom-Json
        $PasswordData = $PasswordDataJson.PasswordData
        Write-Host -NoNewline "."
        Start-Sleep -Seconds 1
    }
    Write-Host "`nExtracting password"

    # Decode Password data and save to file
    $DecodedPasswordData = [System.Convert]::FromBase64String($PasswordData)
    Set-Content -Path $PasswordDataFilePath -Value $DecodedPasswordData -Encoding Byte

    # Decrypt the Password data
    openssl rsa -in $KeypairPath -out "$env:TEMP\$InstanceId-key.dec"
    $DecryptedPassword = openssl pkeyutl -decrypt -inkey "$env:TEMP\$InstanceId-key.dec" -in $PasswordDataFilePath
    Remove-Item -Path "$env:TEMP\$InstanceId-key.dec"

    return $DecryptedPassword.Trim()
}

function Spawn-Instance {
    # Run the AWS CLI command to create EC2 instances
    $InstanceId = $(aws ec2 run-instances --image-id $SelectedAmi --instance-type $InstanceType --key-name $KeyName --security-group-ids $SecurityGroupIds --subnet-id $SubnetId --count $Count --query 'Instances[0].InstanceId' --output text)
    $Instance = $(aws ec2 describe-instances --instance-ids $InstanceId | ConvertFrom-Json)

    # Output the Instance details
    $Instance.Instances | ForEach-Object {
        Write-Host "Instance ID: $InstanceId"
        Write-Host "Public DNS Name: $($Instance.Reservations.Instances.NetworkInterfaces.Association.PublicDnsName)"
        Write-Host "Public IP Address: $($Instance.Reservations.Instances.NetworkInterfaces.Association.PublicIp)"
        Write-Host "Private IP Address: $($Instance.Reservations.Instances.NetworkInterfaces.PrivateIpAddress)"

        # Check if it is a windows instance and extract password
        $platform = aws ec2 describe-images --image-ids $SelectedAmi --query "Images[].PlatformDetails" --output text
        if ($platform -eq "windows") {
            $RetrievePassword = Read-Host "Retrieve plain text password for RDP? (y/n)"
            if ($RetrievePassword.ToLower() -eq "y") {
                $KeypairPath = Read-Host "Specify keypair file path"
                $PasswordDataFilePath = "$env:TEMP\passworddata.bin"
                $Password = Get-EC2InstancePassword -InstanceId $InstanceId -KeypairPath $KeypairPath -PasswordDataFilePath $PasswordDataFilePath
                Remove-Item -Path $PasswordDataFilePath -Force
                Write-Host "=========================================="
                Write-Host "Password: $Password"
            }
        }

        Write-Host "=========================================="
    }
}

$DefaultVPC = aws ec2 describe-vpcs --query 'Vpcs[?IsDefault==`true`].VpcId' --output text
$selectedAmi = Select-AMI

# Use default Security group if not provided
if (-not $SecurityGroupIds) {
    $SecurityGroupIds = aws ec2 describe-security-groups --filters Name=vpc-id,Values=$DefaultVPC --query 'SecurityGroups[?GroupName==`default`].GroupId' --output text
}

# Selecting subnet
if (-not $SubnetId) {
    $SubnetId = Select-SubnetId
}

$KeyName = Select-Key
Spawn-Instance
