$cloneNamePattern = "123"
$CountOfMachinesToStart=1
$VmName = "Win7x64+VS11Pro"
$NUnitIncludeCategory = ""
$NUnitExcludeCategory = ""

$FilesToTest = Get-ChildItem "C:\Work\ReSharper\Perseus\InTestsDataForVmBin\*Tests.Integration.Cases*.dll"
Write-Host $FileSToTest

. C:\Work\TeamCity-extensions\Platform\build\TestProduct\Impl\IntegrationTests.ps1 -GuestCredentials "user","123" -FilesToTest $FilesToTest -cloneNamePattern $cloneNamePattern -VmName $VmName -ViServerData "vcenter.labs.intellij.net","LABS\vm-ReSharper-link-cl","eyndIdhyChamgi"
