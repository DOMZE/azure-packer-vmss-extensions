Param(
    [string] [Parameter(Mandatory=$true)] $ResourceGroupLocation,
    [string] [Parameter(Mandatory=$true)] $ResourceGroupName,
    [string] $TemplateFile = 'azuredeploy.jsonc',
    [string] $TemplateParametersFile = 'azuredeploy.parameters.jsonc',
    [string] $ExtensionTemplateFile = 'azuredeploy.vmssextension.jsonc',
    [string] $ExtensionTemplateParametersFile = 'azuredeploy.vmssextension.parameters.json',
    [string] [Parameter(Mandatory=$true)] $SshPublicKeyLocation,
    [switch] $ValidateOnly 
)

function Format-ValidationOutput {
    param ($ValidationOutput, [int] $Depth = 0)
    Set-StrictMode -Off
    return @($ValidationOutput | Where-Object { $_ -ne $null } | ForEach-Object { @('  ' * $Depth + ': ' + $_.Message) + @(Format-ValidationOutput @($_.Details) ($Depth + 1)) })
}

# Create or update the resource group using the specified template file and template parameters file
$resourceGroup = New-AzResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -Verbose -Force

$adminSshKey = Get-Content -Path $SshPublicKeyLocation | ConvertTo-SecureString -AsPlainText -Force

if ($ValidateOnly) {
    $ErrorMessages = Format-ValidationOutput (Test-AzResourceGroupDeployment -ResourceGroupName $resourceGroup.ResourceGroupName `
                                                                             -TemplateFile $TemplateFile `
                                                                             -TemplateParameterFile $TemplateParametersFile `
                                                                             -administratorSSHKey $adminSshKey)
    if ($ErrorMessages) {
        Write-Output '', 'Validation returned the following errors:', @($ErrorMessages), '', 'Template is invalid.'
    }
    else {
        Write-Output '', 'Template is valid.'
    }

    $ErrorMessages = Format-ValidationOutput (Test-AzResourceGroupDeployment -ResourceGroupName $resourceGroup.ResourceGroupName `
                                                                             -TemplateFile $ExtensionTemplateFile `
                                                                             -TemplateParameterFile $ExtensionTemplateParametersFile `
                                                                             -vmssName "vmss-test-resource")
    if ($ErrorMessages) {
        Write-Output '', 'Validation returned the following errors:', @($ErrorMessages), '', 'VMSS extension template is invalid.'
    }
    else {
        Write-Output '', 'VMSS extension template is valid.'
    }    
}
else {
    Write-Host "Main resources deployment in resource group '$($resourceGroup.ResourceGroupName)'" -ForegroundColor Cyan
    $outputs = New-AzResourceGroupDeployment -Name ((Get-ChildItem $TemplateFile).BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')) `
                                            -ResourceGroupName $resourceGroup.ResourceGroupName `
                                            -TemplateFile $TemplateFile `
                                            -TemplateParameterFile $TemplateParametersFile `
                                            -administratorSSHKey $adminSshKey `
                                            -Force `
                                            -Verbose `
                                            -ErrorVariable ErrorMessages

    if ($ErrorMessages) {
        Write-Output '', 'Deployment returned the following errors:', @($ErrorMessages), '', 'Deployment unsuccessful.'
        exit(1)
    }
    else {
        Write-Output '', 'Deployment successful'
    }

    $vmssName = $outputs.Outputs["vmssName"].Value

    Write-Host "Waiting 5 minutes for the RBAC propagation on the storage account"
    Start-Sleep -Seconds 300

    Write-Host "VMSS Extension resources deployment in resource group '$($resourceGroup.ResourceGroupName)'" -ForegroundColor Cyan
    New-AzResourceGroupDeployment -Name ((Get-ChildItem $ExtensionTemplateFile).BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')) `
                                -ResourceGroupName $resourceGroup.ResourceGroupName `
                                -TemplateFile $ExtensionTemplateFile `
                                -TemplateParameterFile $ExtensionTemplateParametersFile `
                                -vmssName $vmssName `
                                -Force `
                                -Verbose `
                                -ErrorVariable ErrorMessages

    if ($ErrorMessages) {
        Write-Output '', 'Extension deployment returned the following errors:', @($ErrorMessages), '', 'Extension deployment unsuccessful.'
        exit(1)
    }
    else {
        Write-Output '', 'Extension deployment successful'
    }
}