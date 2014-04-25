Param
(
    [Parameter(Position=0)]$ProductName,
    [Parameter(Position=0)]$ApplicationDescriptorAssembly,  
    [Parameter(Position=0)]$ProductBinariesDir="C:\Work\TeamCity-extensions\Platform\lib"
)

<#ScriptPrologue#> Set-StrictMode -Version Latest; $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
function GetDirectoryNameOfFileAbove($markerfile) { $result = ""; $path = $MyInvocation.ScriptName; while(($path -ne "") -and ($path -ne $null) -and ($result -eq "")) { if(Test-Path $(Join-Path $path $markerfile)) {$result=$path}; $path = Split-Path $path }; if($result -eq ""){throw "Could not find marker file $markerfile in parent folders."} return $result; }
$ProductHomeDir = GetDirectoryNameOfFileAbove "Product.Root"

# stub implementation - gets all assemblies from ProductBinariesDir
function GetAssembliesToTest()
{
    $FilesToTest =  Get-ChildItem -Path $ProductBinariesDir\*.* -Filter *.dll
    
    $FilesToTest = $FilesToTest | Sort-Object -Property Length -Descending #start with biggest assembly
    $FilesToTest | Out-String | Write-Host
	return $FilesToTest
}


return GetAssembliesToTest