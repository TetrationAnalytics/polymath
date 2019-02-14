#Requires -Version 3.0

new-module -name ChefDKBootstrap -scriptblock {
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

if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
  [Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
    Break
}

function Polly {
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

  Clear-Host

  Write-Host "Polymath 0.1 - Reconstitute machine configs from scripts"
  Write-Host "--------------------------------------------------------"

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
      Write_Host "==> Uninstalling Chef Workstation $installedVersion. This will take several minutes..."
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

  # Add Chef Worstation to the path
  $env:Path += ";C:\opscode\chef-workstation\bin"

  $tempInstallDir = Join-Path -path $env:TEMP -childpath 'polymath'
  $berksfilePath = Join-Path -path $tempInstallDir -childPath 'Berksfile'
  $chefConfigPath = Join-Path -path $tempInstallDir -childPath 'client.rb'

  # create the temporary installation directory
  if (!(Test-Path $tempInstallDir -pathType container)) {
    New-Item -ItemType 'directory' -path $tempInstallDir
  }

  # Set HOME to be c:\users\<username> so cookbook gem installs are on the c:\
  # drive
  $env:HOME = $env:USERPROFILE

  $berksfile = @"
  source 'https://supermarket.chef.io'
"@

  $chefConfig = @"
  cookbook_path File.join(Dir.pwd, 'berks-cookbooks')
"@

  # Install the bootstrap cookbooks using Berkshelf
  # $env:BERKSHELF_CHEF_CONFIG = $chefConfigPath
  # berks vendor
  # if ( -not $? ) { Pop-Location;  die "Error running berks to download cookbooks." }

  # Cleanup
  if (Test-Path $tempInstallDir) {
    Remove-Item -Recurse $tempInstallDir
  }

  Remove-Item env:BERKSHELF_CHEF_CONFIG
}
}
set-alias polly -value Polly
export-modulemember -function 'Polly' -alias 'polly'
