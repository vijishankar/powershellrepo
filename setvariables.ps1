[CmdletBinding()]
    param (
        [string]$workspace,
        [string]$path,
        [string]$bearerToken,
        [string]$organization,
        [string]$project
    )
    
Import-Module -Name ./VariableGroups.psd1 -Force
Write-Host "Generation variables for path: $path"
foreach ($file in Get-ChildItem -Path $path -Filter *.json*) {

    Write-Host "Merging and pushing primary variables for $file"
    $content = Get-Content -Path $file -Raw
    $variables = $content | ConvertFrom-Json -AsHashTable   
    $template = Get-Content -Path "$workspace/self/$($variables.template)" -Raw
    foreach ($key in $variables.substitution.Keys) {
        $template = $template -creplace "<ToUpper\($key\)>", $variables.substitution[$key].ToString().ToUpper()
        $template = $template -creplace "<$key>", $variables.substitution[$key]
    }
    write-host "Configuration:" $template
    $variables = $template | ConvertFrom-Json -AsHashTable
    $variables `
    | Update-VariableGroup -bearerToken $bearerToken -adoOrganization $organization -adoProject $project
}
