Param
(
    [Parameter(Position=0, Mandatory=$true)]$cloneNamePattern,
    [Parameter(Position=0, Mandatory=$true)][String[]]$ViServerData,
    [Parameter(Position=0, Mandatory=$true)][String[]]$GuestCredentials
)

<#ScriptPrologue#> Set-StrictMode -Version Latest; $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
function GetDirectoryNameOfFileAbove($markerfile) { $result = ""; $path = $MyInvocation.ScriptName; while(($path -ne "") -and ($path -ne $null) -and ($result -eq "")) { if(Test-Path $(Join-Path $path $markerfile)) {$result=$path}; $path = Split-Path $path }; if($result -eq ""){throw "Could not find marker file $markerfile in parent folders."} return $result; }
$ProductHomeDir = GetDirectoryNameOfFileAbove "Product.Root"
$ArtifactsDir = $ProductHomeDir | Join-Path -ChildPath "Artifacts"
function Get-ScriptDirectory { Split-Path $script:MyInvocation.MyCommand.Path }

function CopyLogs([string]$IpAddress, [string]$UserName, [string]$Password)
{
    Write-Host "Coping Logs from" $IpAddress ", using login:" $UserName "and password:" $Password
    # Copy Logs from VM
    LoadTypes
    $remoteEnv = New-Object JetBrains.OsTestFramework.RemoteEnvironment($IpAddress, $UserName, $Password, "$ProductHomeDir\Platform\tools\PsTools\PsExec.exe");
    Try {$remoteEnv.CopyFileFromGuestToHost(("C:\Tmp\JetLogs"), "$ArtifactsDir\JetLogs");} Catch { Write-Host $error[0]}
    Try {  $remoteEnv.CopyFileFromGuestToHost(("C:\Tmp\JetGolds"), "$ArtifactsDir\JetGolds");} Catch { Write-Host $error[0]}
}

function LoadTypes()
{
    $TempDir = [System.IO.Path]::GetTempPath()+ "\InTest"
    If (Test-Path $TempDir){
        Remove-Item $TempDir\* -recurse
    }
    Else{
        New-Item -ItemType directory -Path $TempDir
    }

    $nugetPath=[System.IO.Path]::GetTempPath()+"nuget.exe"
    If (-not (Test-Path $nugetPath)){
        $webclient = New-Object System.Net.WebClient
        $webclient.DownloadFile("http://nuget.org/nuget.exe", $nugetPath);
    }

    & $nugetPath install OsTestFramework -OutputDirectory $TempDir

    $OsTestsFrameworkDll = (Get-ChildItem "JetBrains.OsTestFramework.dll" -Recurse -Path $TempDir).FullName
    $ZetaLongPathsDll = (Get-ChildItem "ZetaLongPaths*" -Path $TempDir).FullName + "\lib\Net20\ZetaLongPaths.dll"
 
    $Assem = ($OsTestsFrameworkDll, $ZetaLongPathsDll)
    Add-Type -Path $Assem
}

function Run
{
    & (Join-Path (Get-ScriptDirectory) "InTest\ViServer.Connect.ps1") -ViServerAddress $ViServerData[0] -ViServerLogin $ViServerData[1] -ViServerPasword $ViServerData[2] | Out-Null
    
    $vms = @(Get-VM -Name $cloneNamePattern*)
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