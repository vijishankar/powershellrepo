[CmdletBinding()]
    param (
        [string]$workspace,
        [string]$path,
        [string]$bearerToken,
        [string]$organization,
        [string]$project
    )
Write-Output $workspace
Write-Output $path
Write-Output $bearerToken
Write-Output $organization
Write-Output $project
 
Import-Module -Name ./VariableGroups.psd1 -Force
Write-Host "Generation variables for path: $path"
foreach ($file in Get-ChildItem -Path $path -Filter variables.json*) {

    Write-Host "Merging and pushing primary variables for $file"
    $content = Get-Content -Path $file -Raw
    Write-Host $file
    $variables = $content | ConvertFrom-Json -AsHashTable   
   # Write-Host $variables.template
    $template = Get-Content -Path "/home/vsts/work/1/s/$($variables.template)" -Raw
    Write-Host $workspace
   # $template = Get-Content -Path $file | ConvertFrom-Json -AsHashTable
    
    foreach ($key in $variables.substitution.Keys) {
        $template = $template -creplace "<ToUpper\($key\)>", $variables.substitution[$key].ToString().ToUpper()
        $template = $template -creplace "<$key>", $variables.substitution[$key]
    }
    write-host "Configuration:" $template
    $variables = $template | ConvertFrom-Json -AsHashTable
    $variables `
    | Update-VariableGroup -bearerToken $bearerToken -adoOrganization $organization -adoProject $project
}
