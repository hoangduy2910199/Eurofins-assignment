param(
    [string]$SiteName = "MyApp",
    [string]$AppPoolName = "MyAppPool",
    [string]$AppName = "hello",
    [string]$PhysicalPath = "C:\inetpub\wwwroot\$SiteName",
    [string]$AppPath = "C:\inetpub\wwwroot\$SiteName\$AppName",
    [string]$BindingHost = "localhost",
    [string]$HttpsPort = "443",
    [string]$CertThumbprint = "<YOUR_CERT_THUMBPRINT>",
    [string]$LogPath = "C:\IISLogs\$SiteName",
    [string]$UserName = "webappuser",
    [Parameter(Mandatory = $true)]
    [string]$Password,
    [string]$GroupName = "WebAppUsers",
    [string]$PfxPath = "..\assets\localhost.pfx",
    [Parameter(Mandatory = $true)]
    [string]$PfxPassword,
    [string]$SourcePath = "..\app\HelloWorldApi"
)

# Function to create a new IIS application user and assign permissions
function New-IISAppUser {
    param (
        [string]$UserName,
        [string]$Password,
        [string]$GroupName
    )
    try {

        # Create local group if not exists
        if (-not (Get-LocalGroup -Name $GroupName -ErrorAction SilentlyContinue)) {
            New-LocalGroup -Name $GroupName
            Write-Host "Created local group: $GroupName"
        }

        # Create local user if not exists
        if (-not (Get-LocalUser -Name $UserName -ErrorAction SilentlyContinue)) {
            $securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
            New-LocalUser -Name $UserName -Password $securePassword -PasswordNeverExpires
            Write-Host "Created user: $UserName"
        }

        # Add user to group
        Add-LocalGroupMember -Group $GroupName -Member $UserName -ErrorAction SilentlyContinue

        # Grant permissions to physical path
        foreach ($path in @($PhysicalPath, $LogPath)) {
            if (-not (Test-Path $path)) {
                New-Item -ItemType Directory -Path $path -Force | Out-Null
                Write-Host "Created directory: $path"
            }
            if(Test-Path $path) {
                Write-Host "Verified path exists: $path"
            } 
            $acl = Get-Acl $path
            $permission = "$env:COMPUTERNAME\$GroupName","Modify","ContainerInherit,ObjectInherit","None","Allow"
            $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
            $acl.SetAccessRule($accessRule)
            Set-Acl -Path $path -AclObject $acl
            Write-Host "Granted Modify permission to group $GroupName on $path"
        }
    }
    catch {
        Write-Error "Failed to create user or assign permissions: ${_}"
    }
}

function New-AppPoolWithUser {
    param (
        [string]$AppPoolName,
        [string]$UserName,
        [string]$Password
    )
    try {
        Import-Module WebAdministration
        if (-not (Test-Path IIS:\AppPools\$AppPoolName)) {
            New-WebAppPool -Name $AppPoolName
            Set-ItemProperty IIS:\AppPools\$AppPoolName -Name processModel.identityType -Value SpecificUser
            Set-ItemProperty IIS:\AppPools\$AppPoolName -Name processModel.userName -Value $UserName
            Set-ItemProperty IIS:\AppPools\$AppPoolName -Name processModel.password -Value $Password
            Write-Host "Created App Pool: $AppPoolName with SpecificUser: $UserName"
        } else {
            Write-Host "App Pool $AppPoolName already exists."
        }
    }
    catch {
        Write-Error "Failed to create or configure App Pool ${AppPoolName}: ${_}"
    }
}

function New-IISWebsite {
    param (
        [string]$SiteName,
        [string]$PhysicalPath,
        [string]$BindingHost,
        [string]$HttpsPort,
        [string]$AppPoolName,
        [string]$PfxPath = "",
        [string]$PfxPassword = ""
    )
    try {
        Import-Module WebAdministration
        # Import certificate from PFX if provided
        if ($PfxPath -and (Test-Path $PfxPath)) {
            $securePwd = $null
            if ($PfxPassword) {
                $securePwd = ConvertTo-SecureString -String $PfxPassword -AsPlainText -Force
            }
            $cert = Import-PfxCertificate -FilePath $PfxPath -CertStoreLocation Cert:\LocalMachine\My -Password $securePwd
            if ($cert) {
                $CertThumbprint = $cert.Thumbprint
                Write-Host "Imported certificate from $PfxPath with thumbprint $CertThumbprint"
            } else {
                Write-Warning "Failed to import certificate from $PfxPath"
            }
        }

        if (-not (Test-Path IIS:\Sites\$SiteName)) {
            New-Item -Path IIS:\Sites\$SiteName -PhysicalPath $PhysicalPath -Bindings @{protocol="https";bindingInformation="*:${HttpsPort}:${BindingHost}"} -ApplicationPool $AppPoolName
            $cert = Get-Item "Cert:\LocalMachine\My\$CertThumbprint" -ErrorAction SilentlyContinue
            if ($cert) {
                netsh http add sslcert ipport=0.0.0.0:$HttpsPort certhash=$CertThumbprint appid='{00112233-4455-6677-8899-AABBCCDDEEFF}' | Out-Null
                Write-Host "Added HTTPS binding for $SiteName"
            } else {
                Write-Warning "Certificate with thumbprint $CertThumbprint not found. HTTPS binding not fully configured."
            }
            Write-Host "Created website: $SiteName"
        } else {
            Write-Host "Website $SiteName already exists."
        }
        Set-ItemProperty "IIS:\Sites\$SiteName" -Name logFile.directory -Value $LogPath
        Write-Host "Set log file path to: $LogPath"
    }
    catch {
        Write-Error "Failed to create website ${SiteName}: ${_}"
    }
}

function Publish-WebApp {
    param (
        [string]$AppPath,
        [string]$SourcePath
    )
    try {
        if (-not (Test-Path $SourcePath)) {
            throw "Source path $SourcePath does not exist."
        }
        if (-not (Test-Path $AppPath)) {
            New-Item -ItemType Directory -Path $AppPath -Force | Out-Null
        }
        # Copy web app files to target folder
        dotnet publish $SourcePath -c Release -o $AppPath
        Write-Host "Published .NET web app to $AppPath"
    }
    catch {
        Write-Error "Failed to publish web app: ${_}"
    }
}

function New-IISApplication {
    param (
        [string]$SiteName,
        [string]$AppName,
        [string]$AppPath,
        [string]$AppPoolName
    )
    try {
        Import-Module WebAdministration
        $appVirtualPath = "/$AppName"
        if (-not (Get-WebApplication -Site $SiteName -Name $AppName -ErrorAction SilentlyContinue)) {
            New-WebApplication -Site $SiteName -Name $AppName -PhysicalPath $AppPath -ApplicationPool $AppPoolName
            Write-Host "Created IIS application: $appVirtualPath"
        } else {
            Write-Host "IIS application $appVirtualPath already exists."
        }
    }
    catch {
        Write-Error "Failed to create IIS application ${AppName}: ${_}"
    }
}


try {
    # 1. Create IIS App User and assign permissions
    New-IISAppUser -UserName $UserName -Password $Password -GroupName $GroupName

    # 2. Create App Pool with the user
    New-AppPoolWithUser -AppPoolName $AppPoolName -UserName $UserName -Password $Password

    # 3. Create Website
    New-IISWebsite -SiteName $SiteName -PhysicalPath $PhysicalPath -BindingHost $BindingHost -HttpsPort $HttpsPort -AppPoolName $AppPoolName -PfxPath $PfxPath -PfxPassword $PfxPassword

    # 4. Publish Web App to sub application path
    Publish-WebApp -AppPath $AppPath -SourcePath $SourcePath

    # 5. Create IIS Sub Application
    New-IISApplication -SiteName $SiteName -AppName $AppName -AppPath $AppPath -AppPoolName $AppPoolName

    Write-Host "Website and sub application deployment completed successfully. You can access it at https://${BindingHost}:${HttpsPort}/${AppName}"
}
catch {
    Write-Error "Deployment failed: ${_}"
}