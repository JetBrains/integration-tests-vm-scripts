param 
(
    [Parameter(Position=0, Mandatory=$true)]$VmName,
    [Parameter(Position=0, Mandatory=$true)]$cloneName
)

<#ScriptPrologue#> Set-StrictMode -Version Latest; $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
function Get-ScriptDirectory { Split-Path $script:MyInvocation.MyCommand.Path }
function GetDirectoryNameOfFileAbove($markerfile) { $result = ""; $path = $MyInvocation.ScriptName; while(($path -ne "") -and ($path -ne $null) -and ($result -eq "")) { if(Test-Path $(Join-Path $path $markerfile)) {$result=$path}; $path = Split-Path $path }; if($result -eq ""){throw "Could not find marker file $markerfile in parent folders."} return $result; }
$ProductHomeDir = GetDirectoryNameOfFileAbove "Product.Root"

function StartVM()
{
    Write-Host -BackgroundColor Gray -ForegroundColor DarkBlue " + Starting VM "

    $config = (& ("$ProductHomeDir\Platform\tools\OsTestFramework.Config\OsTestFramework.GetConfig.ps1") -VmName $VmName)

    if (-not $VmName.Contains("+"))
    {
        throw "VmName must be formed as 'machine_name'+'snapshot_name'." 
    }
    else
    {
        $name = $VmName.split("+")[0];
        $snapshotName = $VmName.split("+")[1];
        Write-Host -BackgroundColor Gray -ForegroundColor DarkBlue " Starting in VIServer " 'name: '$name 'snapshotName:' $snapshotName

        $ht = (& (Join-Path (Get-ScriptDirectory) "CloneStartVM.ps1") -name $name -cloneName $cloneName -snapshotName $snapshotName -ViServerAddress $config.ViServerData.ViServerAddress -ViServerLogin $config.ViServerData.ViServerLogin -ViServerPasword $config.ViServerData.ViServerPasword)
        
        Write-Host -BackgroundColor Gray -ForegroundColor DarkBlue " CloneStart done. "

        $obj = @{IpAddress=$ht["Ip"];UserName=$config.LoginInGuestLogin;Password=$config.LoginInGuestPassword}
        return $obj
    }
}

function Run()
{
    $return = StartVM($VmName)
    Return $return
}

Run