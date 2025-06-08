param (
    [Parameter(Mandatory = $true)]
    [string]$CodePath,

    [Parameter(Mandatory = $true)]
    [string]$PublishFolder,

    [string]$UserName="monitor-user",
    [Parameter(Mandatory = $true)]
    [string]$Password,
    [String]$ServiceName = "HelloMonitorService"
)

function New-PublicFolderUser {
    param (
        [Parameter(Mandatory = $true)]
        [string]$UserName,
        [Parameter(Mandatory = $true)]
        [string]$Password,
        [parameter(Mandatory = $true)]
        [string]$publicFolderPath
    )
    try {
    # Create the user
        if (Get-LocalUser -Name $UserName -ErrorAction SilentlyContinue) {
            Write-Host "User '$UserName' already exists. Skipping creation."
            return
        }
        $securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
        New-LocalUser -Name $UserName -Password $securePassword -FullName $UserName -Description "User for PublicFolder access" -ErrorAction Stop

        # Add user to 'Users' group (default permissions)
        Add-LocalGroupMember -Group "Users" -Member $UserName

        # Grant "Log on as a service" right to the user
        $Sid = (Get-LocalUser -Name $UserName).Sid.Value
        $seceditExport = "$env:TEMP\secpol.inf"
        $seceditImport = "$env:TEMP\secpol_new.inf"

        # Export current security policy
        secedit.exe /export /cfg $seceditExport | Out-Null

        # Read and update the SeServiceLogonRight line
        $lines = Get-Content $seceditExport
        $index = $lines.FindIndex({ $_ -match '^SeServiceLogonRight' })
        if ($index -ge 0) {
            if ($lines[$index] -notmatch $Sid) {
                $lines[$index] += ",$Sid"
            }
        } else {
            $lines += "SeServiceLogonRight = $Sid"
        }
        Set-Content -Path $seceditImport -Value $lines

        # Import the updated policy
        secedit.exe /configure /db "$env:TEMP\secpol.sdb" /cfg $seceditImport /areas USER_RIGHTS | Out-Null

        # Clean up temp files
        Remove-Item $seceditExport, $seceditImport -ErrorAction SilentlyContinue
        # Grant permission to PublicFolder
        if (-not (Test-Path $publicFolderPath)) {
            New-Item -Path $publicFolderPath -ItemType Directory
        }
        $acl = Get-Acl $publicFolderPath
        $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("$env:COMPUTERNAME\$UserName", "Modify", "ContainerInherit,ObjectInherit", "None", "Allow")
        $acl.AddAccessRule($accessRule)
        Set-Acl $publicFolderPath $acl
    }
    catch {
        Write-Error "Failed to create user or set permissions: ${_}"
        
    }
}

function Publish-DotNetService {
    param (
        [Parameter(Mandatory = $true)]
        [string]$CodePath,
        [Parameter(Mandatory = $true)]
        [string]$PublishFolder
    )
    try {
        if (-not (Test-Path $CodePath)) {
            throw "CodePath '$CodePath' does not exist."
        }
        dotnet publish $CodePath -c Release -o $PublishFolder
        Write-Host "Service published successfully to $PublishFolder"
    }
    catch {
        Write-Error "Failed to publish .NET service: ${_}"
    }
}

function New-WindowsService {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ServiceName,
        [Parameter(Mandatory = $true)]
        [string]$DisplayName,
        [Parameter(Mandatory = $true)]
        [string]$ExecutablePath = "$PublishFolder\$ServiceName.exe",
        [string]$UserName = "$env:COMPUTERNAME\$UserName"
    )
    try {
        # Remove existing service if exists
        if (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue) {
            Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
            sc.exe delete $ServiceName | Out-Null
            Start-Sleep -Seconds 2
        }

        # Create the service
        New-Service -Name $ServiceName -BinaryPathName "`"$ExecutablePath`"" -DisplayName $DisplayName -StartupType Automatic -Credential (New-Object System.Management.Automation.PSCredential($UserName, (ConvertTo-SecureString -String $Password -AsPlainText -Force)))

        # Set recovery options: restart after 300 seconds (5 minutes)
        sc.exe failure $ServiceName reset= 0 actions= restart/300000

        # Start the service
        Start-Service -Name $ServiceName

        Write-Host "Windows service '$ServiceName' created and started successfully."
    }
    catch {
        Write-Error "Failed to create Windows service: ${_}"
    }
}

Write-Host "Starting deployment of Windows service: $ServiceName"

try {
    Write-Host "Step 1: Creating user '$UserName' and setting permissions on '$PublishFolder'..."
    New-PublicFolderUser -UserName $UserName -Password $Password -publicFolderPath $PublishFolder
    Write-Host "User creation and permission assignment completed."

    Write-Host "Step 2: Publishing .NET service from '$CodePath' to '$PublishFolder'..."
    Publish-DotNetService -CodePath $CodePath -PublishFolder $PublishFolder
    Write-Host ".NET service published successfully."

    Write-Host "Step 3: Creating and starting Windows service '$ServiceName'..."
    New-WindowsService -ServiceName $ServiceName -DisplayName $ServiceName -ExecutablePath "$PublishFolder\$ServiceName.exe" -UserName "$env:COMPUTERNAME\$UserName"
    Write-Host "Windows service '$ServiceName' created and started successfully."
}
catch {
    Write-Error "Deployment failed: ${_}"
}

Write-Host "Deployment script completed."