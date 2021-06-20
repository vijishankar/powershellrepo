
function Get-VariableGroup {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [String]
    $variableGroup,
  
    [Parameter(Mandatory = $true)]
    [String]
    $patToken,
  
    [Parameter(Mandatory = $false)]
    [String]
    $adoOrganization = 'https://dev.azure.com/TemCloudTechSolns/',
  
    [Parameter(Mandatory = $false)]
    [String]
    $adoProject = 'infinityauto'
  )
  
  begin {
    $b64pat = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($patToken)"))

    $hdrs = @{
      Accept = 'application/json'
      Authorization = "Basic $b64pat"
    }

    $apiVer = 'api-version=5.1-preview.1'

    if (-not $adoOrganization.EndsWith('/'))
    {
      $adoOrganization = $adoOrganization + '/'
    }

    # Get the project id
    $projects = Invoke-RestMethod -Method GET -Uri "$($adoOrganization)_apis/projects?$apiVer" -Headers $hdrs

    $projectId = ($projects.value | Where-Object { $_.name -eq $adoProject } | Select-Object -First 1).id

  }
  process {

    $uri = [Uri]"$adoOrganization/$projectId/_apis/distributedtask/variablegroups?groupName=$variableGroup&$apiVer"

    $resp = Invoke-WebRequest -Method Get -Uri $uri -Headers $hdrs

    $grp = (ConvertFrom-Json -InputObject $resp.Content -NoEnumerate -AsHashTable).value | Select-Object -First 1

    $grp.Remove('variableGroupProjectReferences')

    $grp.createdBy = $grp.createdBy.displayName
    $grp.modifiedBy = $grp.modifiedBy.displayName
    $variables = @{}
    $grp.variables.Keys | ForEach-Object {
      $variables.$_ = $grp.variables.$_.value
    }
    $grp.Remove('variables')
    $grp.variables = $variables

    $vars = New-Object PSObject -Property $grp

    return $vars
  }
  
  end {
  }
}

function Find-VariableGroup {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [String]
    $variableGroup,
  
    [Parameter(Mandatory = $true)]
    [String]
    $patToken,
  
    [Parameter(Mandatory = $false)]
    [String]
    $adoOrganization = 'https://dev.azure.com/TemCloudTechSolns/',
  
    [Parameter(Mandatory = $false)]
    [String]
    $adoProject = 'infinityauto'
  )
  
  begin {
    $b64pat = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($patToken)"))

    $hdrs = @{
      Accept = 'application/json'
      Authorization = "Basic $b64pat"
    }

    $apiVer = 'api-version=5.1-preview.1'

    if (-not $adoOrganization.EndsWith('/'))
    {
      $adoOrganization = $adoOrganization + '/'
    }

    # Get the project id
    $projects = Invoke-RestMethod -Method GET -Uri "$($adoOrganization)_apis/projects?$apiVer" -Headers $hdrs

    $projectId = ($projects.value | Where-Object { $_.name -eq $adoProject } | Select-Object -First 1).id

  }
  process {

    $uri = [Uri]"$adoOrganization/$projectId/_apis/distributedtask/variablegroups?groupName=$variableGroup&$apiVer"

    $resp = Invoke-WebRequest -Method Get -Uri $uri -Headers $hdrs
    $result = $resp.Content | ConvertFrom-Json
    $count = $result.count -as [int]
    if ($count -gt 0) {
      return $result.value[0].id
    }
    else {
      return -1
    }
  }
  
  end {
  }
}

function Update-VariableGroup {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true, ValueFromPipeline=$true)]
    [PSObject]
    $variableGroup = 'VariableGroupYML',

    [Parameter(Mandatory = $true, parametersetname='PAT')]
    [String]
    $patToken = 'u6vhayt3r5zeylhudym27xzq2j37s4p5zj7l4tse5hnhr7zsjyeq',

    [Parameter(Mandatory = $true, parametersetname='Bearer')]
    [String]
    $bearerToken,

    [Parameter(Mandatory = $false)]
    [String]
    $adoOrganization = 'https://dev.azure.com/DevopsCPTTraining/',
  
    [Parameter(Mandatory = $false)]
    [String]
    $adoProject = 'EngageDemo'
  )
  
  begin {
    $hdrs = @{ Accept = 'application/json' }

    switch ($PsCmdlet.ParameterSetName)
    {
      'PAT' {
        $b64pat = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($patToken)"))
        $hdrs.Authorization = "Basic $b64pat"
      }
      'Bearer' {
        $hdrs.Authorization = "Bearer $bearerToken"
      }
    }

    $apiVer = 'api-version=5.1-preview.1'

    if (-not $adoOrganization.EndsWith('/'))
    {
      $adoOrganization = $adoOrganization + '/'
    }

    # Get the project id
    $projects = Invoke-RestMethod -Method GET -Uri "$($adoOrganization)_apis/projects?$apiVer" -Headers $hdrs

    $projectId = ($projects.value | Where-Object { $_.name -eq $adoProject } | Select-Object -First 1).id

  }
  
  process {
    # Convert to HashTable
    $grp = $variableGroup | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashTable

    if ($null -eq $grp.id)
    {
      # If we don't have an id, we need to get this.
      $currentGroup = Get-VariableGroup -variableGroup $grp.name -patToken $patToken -adoOrganization $adoOrganization -adoProject $adoProject
      $grp.id = $currentGroup.id
    }

    $uri = [Uri]"$($adoOrganization)$projectId/_apis/distributedtask/variablegroups/$($grp.id)?$apiVer"

    $grp.Remove('id')
    $grp.Remove('createdBy')
    $grp.Remove('createdOn')
    $grp.Remove('modifiedBy')
    $grp.Remove('modifiedOn')
    $grp.Remove('isShared')

    $grp.type = "Vsts"

    $variables = [ordered]@{}

    $variables = EnumerateVariables -basename '' -variablesIn $grp.variables -variablesOut $variables

    $grp.Remove('variables')

    $grp.variables = $variables

    $data = ConvertTo-Json -InputObject $grp -Depth 100 -Compress

    $resp = Invoke-RestMethod -Method Put -Uri $uri -Headers $hdrs -Body $data -ContentType 'application/json'
  
    return $vars
  }
  
  end {
  }
}

function Add-VariableGroup {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true, ValueFromPipeline=$true)]
    [PSObject]
    $variableGroup,

    [Parameter(Mandatory = $true, parametersetname='PAT')]
    [String]
    $patToken,

    [Parameter(Mandatory = $true, parametersetname='Bearer')]
    [String]
    $bearerToken,

    [Parameter(Mandatory = $false)]
    [String]
    $adoOrganization = 'https://dev.azure.com/TemCloudTechSolns/',
  
    [Parameter(Mandatory = $false)]
    [String]
    $adoProject = 'infinityauto'
  )
  
  begin {
    $hdrs = @{ Accept = 'application/json' }

    switch ($PsCmdlet.ParameterSetName)
    {
      'PAT' {
        $b64pat = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($patToken)"))
        $hdrs.Authorization = "Basic $b64pat"
      }
      'Bearer' {
        $hdrs.Authorization = "Bearer $bearerToken"
      }
    }

    $apiVer = 'api-version=5.1-preview.1'

    if (-not $adoOrganization.EndsWith('/'))
    {
      $adoOrganization = $adoOrganization + '/'
    }
  }
  
  process {
    # Convert to HashTable
    $grp = $variableGroup | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashTable

    $uri = [Uri]"$($adoOrganization)$adoProject/_apis/distributedtask/variablegroups?$apiVer"
  
    $grp.Remove('id')
    $grp.Remove('createdBy')
    $grp.Remove('createdOn')
    $grp.Remove('modifiedBy')
    $grp.Remove('modifiedOn')
    $grp.Remove('isShared')

    $grp.type = "Vsts"

    $variables = [ordered]@{}

    $variables = EnumerateVariables -basename '' -variablesIn $grp.variables -variablesOut $variables

    $grp.Remove('variables')

    $grp.variables = $variables

    $data = ConvertTo-Json -InputObject $grp -Depth 100 -Compress
    Set-Content -Path "test.json" -Value $data
    $resp = Invoke-RestMethod -Method Post -Uri $uri -Headers $hdrs -Body $data -ContentType 'application/json'

    return $vars
  }
  
  end {
  }
}

function EnumerateVariables {
  param ([string] $basename, [HashTable] $variablesIn, [HashTable] $variablesOut)

  foreach ($v in $variablesIn.Keys)
  {
    if (($variablesIn.$v.GetType().Name) -eq 'Hashtable')
    {
      $variablesOut = EnumerateVariables -basename "$basename$v." -variablesIn $variablesIn.$v -variablesOut $variablesOut
    }
    else
    {
      $variablesOut.Add("$basename$v", @{
        value = $variablesIn.$v
      })
    }
  }

  return $variablesOut
}

Export-ModuleMember -Function Get-VariableGroup
Export-ModuleMember -Function Update-VariableGroup
Export-ModuleMember -Function Add-VariableGroup
Export-ModuleMember -Function Find-VariableGroup
