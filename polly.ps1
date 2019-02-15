# Based on https://github.com/Nordstrom/chefdk_bootstrap/blob/master/bootstrap.ps1
#
#Requires -Version 3.0

New-Module -name BootstrapChefWorkstation -ScriptBlock {
    function promptContinue {
        param ($msg="Polymath encountered an error")
        $yn = Read-Host "$Msg. Continue? [y|N]"
        if ( $yn -NotLike 'y*' ) {
            Break
        }
    }

    function die {
        param ($msg="Polymath encountered an error. Exiting")
        Write-host "$msg."
        Break
    }

    function install_chef_workstation {
        # Set targetChefDk to latest version from metadata URL
        $metadataURL = "https://omnitruck.chef.io/stable/chef-workstation/metadata?p=windows&pv=2016&m=x86_64&v=latest"

        if ( $env:http_proxy ) {
          $getMetadata = Invoke-WebRequest -UseBasicParsing $metadataURL -Proxy $env:http_proxy -ProxyUseDefaultCredentials
          if ( -not $? ) { die "Error downloading $metadataURL using proxy $env:http_proxy." }
        } else {
          $getMetadata = Invoke-WebRequest -UseBasicParsing $metadataURL
          if ( -not $? ) { die "Error downloading $metadataURL. Do you need to set `$env:http_proxy ?" }
        }

        $latest_info = $getMetadata.Content
        $CHEF_WORKSTATION_LATEST_PATTERN = "version\s(\d{1,2}\.\d{1,2}\.\d{1,2})"
        $targetChefWorkstation = [regex]::match($latest_info, $CHEF_WORKSTATION_LATEST_PATTERN).Groups[1].Value

        $omniUrl = "https://omnitruck.chef.io/install.ps1"

        # Install chef-workstation unless installed already
        Write-Host "==> Checking Chef Workstation version"
        $app = Get-CimInstance -classname win32_product -filter "Name like 'Chef Workstation%'"
        $installedVersion = $app.Version
        if ( $installedVersion -like "$targetChefWorkstation*" ) {
            Write-Host "Chef Workstation $installedVersion already installed"
        } else {
            if ( $installedVersion -eq $null ) {
              Write-Host "Chef Workstation not found. Installing Chef Workstation $targetChefWorkstation"
            }	else {
              Write-Host "Upgrading Chef Workstation from $installedVersion to $targetChefWorkstation"
              Write-Host "==> Uninstalling Chef Workstation $installedVersion. This will take several minutes..."
              Invoke-CimMethod -InputObject $app -MethodName UnInstall
              if ( -not $? ) { promptContinue "Error uninstalling Chef Workstation $installedVersion" }
            }
            if ( $env:http_proxy ) {
              $installScript = Invoke-WebRequest -UseBasicParsing $omniUrl -Proxy $env:http_proxy -ProxyUseDefaultCredentials
              if ( -not $? ) { die "Error downloading $omniUrl using proxy $env:http_proxy." }
            } else {
             $installScript = Invoke-WebRequest -UseBasicParsing $omniUrl
             if ( -not $? ) { die "Error downloading $omniUrl. Do you need to set `$env:http_proxy ?" }
            }
            $installScript | Invoke-Expression
            if ( -not $? ) { die "Error running installation script" }
            Write-Host "Installing Chef Workstation $targetChefWorkstation. This will take several minutes..."
            install -channel stable -project chef-workstation -version $targetChefWorkstation
            if ( -not $? ) { die "Error installing Chef Workstation $targetChefWorkstation" }
        }
    }

    function uninstall_chef_workstation {
        # Set targetChefDk to latest version from metadata URL
        $metadataURL = "https://omnitruck.chef.io/stable/chef-workstation/metadata?p=windows&pv=2016&m=x86_64&v=latest"

        if ( $env:http_proxy ) {
          $getMetadata = Invoke-WebRequest -UseBasicParsing $metadataURL -Proxy $env:http_proxy -ProxyUseDefaultCredentials
          if ( -not $? ) { die "Error downloading $metadataURL using proxy $env:http_proxy." }
        } else {
          $getMetadata = Invoke-WebRequest -UseBasicParsing $metadataURL
          if ( -not $? ) { die "Error downloading $metadataURL. Do you need to set `$env:http_proxy ?" }
        }

        $latest_info = $getMetadata.Content
        $CHEF_WORKSTATION_LATEST_PATTERN = "version\s(\d{1,2}\.\d{1,2}\.\d{1,2})"
        $targetChefWorkstation = [regex]::match($latest_info, $CHEF_WORKSTATION_LATEST_PATTERN).Groups[1].Value

        $omniUrl = "https://omnitruck.chef.io/install.ps1"

        # Remove chef-workstation unless not preset
        Write-Host "==> Checking Chef Workstation version"
        $app = Get-CimInstance -classname win32_product -filter "Name like 'Chef Workstation%'"
        $installedVersion = $app.Version
        if ( $installedVersion -like "$targetChefWorkstation*" ) {
            Write-Host "==> Uninstalling Chef Workstation $installedVersion. This will take several minutes..."
            Invoke-CimMethod -InputObject $app -MethodName UnInstall
            if ( -not $? ) { promptContinue "Error uninstalling Chef Workstation $installedVersion" }
        }
    }
    
    function generate_berksfile {
        Param(
            [string] $berksfile_dir,
            [string] $chef_supermarket,
            [string] $run_list
        )

        $berksfile = @"
source '$chef_supermarket'

"@
        $berksfilePath = Join-Path -path $berksfile_dir -childPath 'Berksfile'
        # Write out a local Berksfile for Berkshelf to use
        $berksfile | Out-File -FilePath $berksfilePath -Encoding ASCII

        $cookbook_list = New-Object System.Collections.ArrayList
        $run_list.Split(",") | ForEach {
            $cookbook_name = $_
            If($_.lastIndexOf('::') -ne -1) {
                $cookbook_name = $_.Substring(0, $_.lastIndexOf('::'))
            }
            # Make sure list of cookbook names is unique
            # berks errors if duplicate cookbook names are in a Berksfile
            If($cookbook_list -notcontains $cookbook_name) {
                [void]$cookbook_list.add($cookbook_name)
            }
        }
        
        ForEach ($cookbook_name in $cookbook_list) {
           $cookbook_entry = "cookbook '$cookbook_name'"
           $cookbook_entry | Add-Content $berksfilePath -Encoding ASCII
        }
    }

    function Polymath {
        Param(
            [string] $run_list,
            [string] $environment
        )

        If ($run_list -eq 'nukechef') {
            uninstall_chef_workstation
            Return
        } ElseIf ($run_list -eq 'chef') {
            install_chef_workstation
            Return
        }

        Clear-Host

        Write-Host "Polymath 0.1 - Reconstitute machine configs from scripts"
        Write-Host "--------------------------------------------------------"
        
        install_chef_workstation
        
        $tempInstallDir = Join-Path -path $env:TEMP -childpath 'polymath'

        # create the temporary installation directory
        if (!(Test-Path $tempInstallDir -pathType container)) {
            New-Item -ItemType 'directory' -path $tempInstallDir
        }

        generate_berksfile $tempInstallDir https://supermarket.ocean.af $run_list
        
        # Add ChefDK to the path
        $env:Path += ";C:\opscode\chefdk\bin"

        # Install the bootstrap cookbooks using Berkshelf
        Write-Host "==> Downloading cookbook dependencies from Supermarket"
        chef exec berks vendor "$tempInstallDir\berks-cookbooks" --berksfile="$tempInstallDir\Berksfile"
        if ( -not $? ) { Pop-Location;  die "Error running berks to download cookbooks." }
        
         # Secrets need to go alongside cookbooks with Chef local mode
        If($Env:SECRET_STORE_URL -ne $null -and $Env:SECRET_STORE_USERNAME -ne $null -and $Env:SECRET_STORE_PASSWORD -ne $null) {
            Write-Host "==> Downloading secret store"
            Remove-Item "$tempInstallDir\data_bags" -Recurse -ErrorAction Ignore
            Remove-Item "$tempInstallDir\secret_store-master" -Recurse -ErrorAction Ignore
            $webclient = New-Object System.Net.WebClient
            $basic = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($Env:SECRET_STORE_USERNAME + ":" + $Env:SECRET_STORE_PASSWORD));
            $webclient.Headers["Authorization"] = "Basic $basic"
            $webclient.DownloadFile($Env:SECRET_STORE_URL, "$tempInstallDir\secret_store.zip")
            Add-Type -assembly "system.io.compression.filesystem"
            [io.compression.zipfile]::ExtractToDirectory("$tempInstallDir\secret_store.zip", "$tempInstallDir")
            robocopy "$tempInstallDir\secret_store-master\data_bags" "$tempInstallDir\data_bags" /E
        }

        # Cleanup
        if (Test-Path $tempInstallDir) {
            Remove-Item -Recurse $tempInstallDir
        }
    }

    Set-Alias polly -Value Polymath
    Export-ModuleMember -function 'Polymath' -alias 'polly'
}
