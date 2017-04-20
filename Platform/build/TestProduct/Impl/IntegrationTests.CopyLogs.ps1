Param
(
    [Parameter(Position=0, Mandatory=$true)]$cloneNamePattern,
    [Parameter(Position=0, Mandatory=$true)][String[]]$ViServerData,
    [Parameter(Position=0, Mandatory=$true)][String[]]$GuestCredentials,
    [Parameter(Position=0)]$ArtifactsDir
)

<#ScriptPrologue#> Set-StrictMode -Version Latest; $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
function GetDirectoryNameOfFileAbove($markerfile) { $result = ""; $path = $MyInvocation.ScriptName; while(($path -ne "") -and ($path -ne $null) -and ($result -eq "")) { if(Test-Path $(Join-Path $path $markerfile)) {$result=$path}; $path = Split-Path $path }; if($result -eq ""){throw "Could not find marker file $markerfile in parent folders."} return $result; }

$ProductHomeDir = GetDirectoryNameOfFileAbove "Product.Root"
if ($ArtifactsDir -eq $null){
    $ArtifactsDir = $ProductHomeDir | Join-Path -ChildPath "Artifacts"
}
Write-Host "ArtifactsDir: $ArtifactsDir will be used."

function Get-ScriptDirectory { Split-Path $script:MyInvocation.MyCommand.Path }

function global:PSUsing {
    param (
        [System.IDisposable] $inputObject = $(throw "The parameter -inputObject is required."),
        [ScriptBlock] $scriptBlock = $(throw "The parameter -scriptBlock is required.")
    )
 
    Try {
        &$scriptBlock
    } Finally {
        if ($inputObject -ne $null) {
            if ($inputObject.psbase -eq $null) {
                $inputObject.Dispose()
            } else {
                $inputObject.psbase.Dispose()
            }
        }
    }
}

function CopyLogs([string]$IpAddress, [string]$UserName, [string]$Password)
{
    Write-Host "Coping Logs from" $IpAddress ", using login:" $UserName "and password:" $Password
    # Copy Logs from VM
    LoadTypes
    PSUsing ($netPath = New-Object JetBrains.OsTestFramework.Network.MappedNetworkPath $IpAddress, $UserName, $Password, "C:\") {
      
      $jetLogs = Join-Path -Path $netPath.GuestNetworkPath -ChildPath "Tmp\JetLogs"
      $jetGolds = Join-Path -Path $netPath.GuestNetworkPath -ChildPath "Tmp\JetGolds"
      $jetScreenshots = Join-Path -Path $netPath.GuestNetworkPath -ChildPath "Tmp\JetScreenshots"
      $crashTraces = Join-Path -Path $netPath.GuestNetworkPath -ChildPath "Tmp\CaptureTraces\output_crash"
      $hangTraces = Join-Path -Path $netPath.GuestNetworkPath -ChildPath "Tmp\CaptureTraces\output"
      $hangTraces64 = Join-Path -Path $netPath.GuestNetworkPath -ChildPath "Tmp\CaptureTraces.x64\output"
      $activityLogBase = Join-Path -Path $netPath.GuestNetworkPath -ChildPath "Users\User\AppData\Roaming\Microsoft\VisualStudio"

      $DestPath = "$ArtifactsDir\$IpAddress"
      Try {[JetBrains.OsTestFramework.Common.FileOperations]::CopyFiles($jetLogs, "$DestPath\JetLogs")} Catch { Write-Host $error[0]}
      Try {[JetBrains.OsTestFramework.Common.FileOperations]::CopyFiles($jetGolds, "$DestPath\JetGolds")} Catch { Write-Host $error[0]}
      Try {[JetBrains.OsTestFramework.Common.FileOperations]::CopyFiles($jetScreenshots, "$DestPath\JetScreenshots")} Catch { Write-Host $error[0]}
      Try {robocopy $crashTraces "$DestPath\crashTraces" *.txt /s} Catch { Write-Host $error[0]}
      Try {robocopy $hangTraces "$DestPath\hangTraces" *.txt /s} Catch { Write-Host $error[0]}
      Try {robocopy $hangTraces64 "$DestPath\hangTraces.x64" *.txt /s} Catch { Write-Host $error[0]}
      Try {robocopy $activityLogBase "$DestPath\activityLogs" ActivityLog* /E /S} Catch { Write-Host $error[0]}
    }
}

function LoadTypes()
{
  $AssemblyName1 = "JetBrains.OsTestFramework"
  $AssemblyName2 = "ZetaLongPaths"
  if(([appdomain]::currentdomain.getassemblies() | Where {$_ -match $AssemblyName1}) -eq $null) {
    $TempDir = [System.IO.Path]::GetTempPath()+ "\InTest"
    If (Test-Path $TempDir){
        Remove-Item $TempDir\* -recurse
    }
    Else{
        New-Item -ItemType directory -Path $TempDir
    }

    $nugetPath=[System.IO.Path]::GetTempPath()+"nuget.exe"
    Write-Host $nugetPath
    If (-not (Test-Path $nugetPath)){
        $webclient = New-Object System.Net.WebClient
        $webclient.DownloadFile("http://nuget.org/nuget.exe", $nugetPath);
    }

    $configPath = Join-Path $ProductHomeDir "NuGet.config"
    & $nugetPath install OsTestFramework -OutputDirectory $TempDir -ConfigFile $configPath

    $OsTestsFrameworkDll = (Get-ChildItem ($AssemblyName1+".dll") -Recurse -Path $TempDir).FullName
    $ZetaLongPathsDll = (Get-ChildItem ($AssemblyName2+"*") -Path $TempDir).FullName + "\lib\Net20\"+$AssemblyName2+".dll"
 
    $Assem = ($OsTestsFrameworkDll, $ZetaLongPathsDll)
    Add-Type -Path $Assem
  }
}

function Run
{
    & (Join-Path (Get-ScriptDirectory) "InTest\ViServer.Connect.ps1") -ViServerAddress $ViServerData[0] -ViServerLogin $ViServerData[1] -ViServerPasword $ViServerData[2] | Out-Null
    
    $vms = @(Get-VM -Name $cloneNamePattern*_clone_*)
    foreach ($vm in $vms)
    {
        if ($vm.PowerState -ne "PoweredOff")
        {
            $ips =$vm.Guest.ipaddress
            foreach ($ip in $ips){
                if ($ip.StartsWith('172.')){
                    CopyLogs $ip $GuestCredentials[0] $GuestCredentials[1]
        }}}
    }
}

Run