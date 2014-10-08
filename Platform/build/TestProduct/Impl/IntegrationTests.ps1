Param
(
    [Parameter(Position=0)]$NUnitCpu = $null, # Inherit from current runtime by default
    [Parameter(Position=0)]$NUnitRuntime = $null, # Inherit from current runtime by default
    
    [Parameter(Position=0, Mandatory=$true)][String[]]$FilesToTest, # "path_to_dll1", "path_to_dll2"
    [Parameter(Position=0)]$CountOfMachinesToStart = 1,
    [Parameter(Position=0, Mandatory=$true)]$cloneNamePattern,
    [Parameter(Position=0, Mandatory=$true)]$VmName,
    [Parameter(Position=0)]$NUnitIncludeCategory = "",
    [Parameter(Position=0)]$NUnitExcludeCategory = "",
    [Parameter(Position=0, Mandatory=$true)][String[]]$ViServerData, #"server_adress", "login", "pass"
    [Parameter(Position=0, Mandatory=$true)][String[]]$GuestCredentials #"guest_login", "guest_pass"
)

<#ScriptPrologue#> Set-StrictMode -Version Latest; $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
function GetDirectoryNameOfFileAbove($markerfile) { $result = ""; $path = $MyInvocation.ScriptName; while(($path -ne "") -and ($path -ne $null) -and ($result -eq "")) { if(Test-Path $(Join-Path $path $markerfile)) {$result=$path}; $path = Split-Path $path }; if($result -eq ""){throw "Could not find marker file $markerfile in parent folders."} return $result; }
$ProductHomeDir = GetDirectoryNameOfFileAbove "Product.Root"

function Run
{
    # Poweroff before starting new machines and tests ensures that machines started at previous build are removed
    & "$ProductHomeDir\Platform\build\TestProduct\Impl\IntegrationTests.PowerOff.ps1" -cloneNamePattern $cloneNamePattern -ViServerData $ViServerData

    Try {
        & "$ProductHomeDir\Platform\build\TestProduct\Impl\IntegrationTests.PowerOnRun.ps1" -FilesToTest $FilesToTest `
            -cloneNamePattern $cloneNamePattern -VmName $VmName -CountOfMachinesToStart $CountOfMachinesToStart -NUnitExcludeCategory $NUnitExcludeCategory -NUnitIncludeCategory $NUnitIncludeCategory `
            -NUnitCpu $NUnitCpu -NUnitRuntime $NUnitRuntime `
            -ViServerData $ViServerData -GuestCredentials $GuestCredentials
        
        & "$ProductHomeDir\Platform\build\TestProduct\Impl\IntegrationTests.CopyLogs.ps1" -cloneNamePattern $cloneNamePattern -ViServerData $ViServerData -GuestCredentials $GuestCredentials
    }
    Catch {throw}
    Finally {
        & "$ProductHomeDir\Platform\build\TestProduct\Impl\IntegrationTests.PowerOff.ps1" -cloneNamePattern $cloneNamePattern -ViServerData $ViServerData
    }
}


Write-Host $ViServerData[0]

Run