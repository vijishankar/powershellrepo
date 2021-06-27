param (
  [Parameter(Mandatory = $true)]
  [String]
  $TemplateFile,

  [Parameter(Mandatory = $true)]
  [String]
  $OutputDirectory,

  [Parameter(Mandatory = $false)]
  [String]
  $KeyVaultId = '',

  [Parameter(Mandatory = $false)]
  [String]
  $pipelinePrefix = '',

  [Parameter(Mandatory = $false)]
  [String]
  $appPrefix = ''
)

Write-Host "##vso[task.setvariable variable=ArmTemplateFile;]"
Write-Host "##vso[task.setvariable variable=ArmTemplateParametersFile;]"

try {

  $tp = [ordered]@{
    '$schema'      = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#'
    contentVersion = '1.0.0.0'
    parameters     = [ordered]@{ }
  }

  $templateName = Resolve-Path $TemplateFile | Split-Path -LeafBase

  New-Item -Path $OutputDirectory -Type Directory -Force | Out-Null
  if (-not [String]::IsNullOrEmpty($appPrefix)) {
    $parametersFile = Join-Path $OutputDirectory "$appPrefix.$templateName.params.json"
    $outTemplateFile = Join-Path $OutputDirectory "$appPrefix.$templateName.json"
  }
  else {
    $parametersFile = Join-Path $OutputDirectory "$($templateName).params.json"
    $outTemplateFile = Join-Path $OutputDirectory "$($templateName).json"
  }
  $t = Get-Content $TemplateFile -Raw | ConvertFrom-Json -AsHashtable

  if (($t.parameters.Keys | Where-Object { $t.parameters[$_].type -eq 'securestring' }).Length -gt 0 -and $KeyVaultId.Length -eq 0) {
    Write-Host "##vso[task.complete result=SucceededWithIssues;]No KeyVaultId specified."
    Exit 0
  }

  Copy-Item $TemplateFile $outTemplateFile

  $t.parameters.Keys | `
    #    Where-Object { $_.ToUpper().Replace('-', '_') -in $envVarNames } | `
    ForEach-Object {
      $p = $_
      # Search for an environment variable of the form and in the order
      # 1. PIPELINEPREFIX_APPPREFIX_PARAMNANE
      # 2. PIPELINEPREFIX_PARAMNANE
      # 3. PARAMNANE
      $val = $null
      if (-not [String]::IsNullOrEmpty($pipelinePrefix) -and -not [String]::IsNullOrEmpty($appPrefix)) {
        Write-Verbose "Looking for env:$($pipelinePrefix.ToUpper())_$($appPrefix.ToUpper())_$($_.ToUpper().Replace('-', '_'))"
        $val = [System.Environment]::GetEnvironmentVariable("$($pipelinePrefix.ToUpper())_$($appPrefix.ToUpper())_$($_.ToUpper().Replace('-', '_'))")
      }
      if (($null -eq $val) -and (-not [String]::IsNullOrEmpty($pipelinePrefix))) {
        Write-Verbose "Looking for env:$($pipelinePrefix.ToUpper())_$($_.ToUpper().Replace('-', '_'))"
        $val = [System.Environment]::GetEnvironmentVariable("$($pipelinePrefix.ToUpper())_$($_.ToUpper().Replace('-', '_'))")
      }
      if ($null -eq $val) {
        Write-Verbose "Looking for env:$($_.ToUpper().Replace('-', '_'))"
        $val = [System.Environment]::GetEnvironmentVariable("$($_.ToUpper().Replace('-', '_'))")
      }
      if ($null -eq $val) {
        Write-Warning "No value found for $p"
      }

      if ($null -ne $val) {
        Write-Verbose "$p = `"$val`""
        switch ($t.parameters[$_].type) {
          'string' {
            $tp.parameters.$p = @{
              value = $val
            }
          }
          'int' {
            $tp.parameters.$p = @{
              value = $([int]::Parse($val))
            }
          }
          'bool' {
            $tp.parameters.$P = @{
              value = $([bool]::Parse($val))
            }
          }
          'securestring' {
            $tp.parameters.$p = @{
              reference = [ordered]@{
                keyVault   = @{ id = $KeyVaultId }
                secretName = $val
              }
            }
          }
          'array' {
            $tp.parameters.$p = @{
              value = @($val.Split(',', [StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object { $_.Trim() })
            }
          }
          'object' {
            $tp.parameters.$p = @{
              value = ConvertFrom-Json $val -AsHashtable
            }
          }
        }
      }
    }

    $tp | ConvertTo-Json -Depth 100 | Set-Content -Path $parametersFile -Encoding utf8

    Write-Host "##vso[task.setvariable variable=ArmTemplateFile;]$outTemplateFile"
    Write-Host "##vso[task.setvariable variable=ArmTemplateParametersFile;]$parametersFile"
    Write-Host "##vso[task.setvariable variable=OutputDirectory;]$OutputDirectory"
  }
  catch {
    $scripterror = $_
    Write-Host "##vso[task.logissue type=error]$($scripterror.Exception.Message)"
    Write-Host "##vso[task.logissue type=error]$($scripterror.ScriptStackTrace)"
    Write-Host "##vso[task.logissue type=error]$($scripterror.ErrorDetails)"
    Write-Host "##vso[task.complete result=Failed;]"
  }
