function Get-Resource {
    Param([string]$URI, [string]$Token)

    $authValue = "token $Token"
    
    $Headers = @{
        Authorization = $authValue
        Accept = "application/vnd.github.v3+json"
    }

    $Response = Invoke-WebRequest `
        -Uri $URI `
        -Headers $Headers `
        -Method GET
    return $Response
}

$ProjectBranchesResponse = Get-Resource `
    "https://api.github.com/orgs/Org-Digital/repos" `
    "ghp_7xxxxxxxxxxxxxxxxxxxxx"

$ProjectBranches = $ProjectBranchesResponse.Content | ConvertFrom-Json

Write-Host $ProjectBranches[0].owner