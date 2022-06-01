function Api-Call {
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

$ProjectBranchesResponse = Api-Call `
    "https://api.github.com/orgs/Bunnings-Digital/repos" `
    "ghp_7xxxxxxxxxxxxxxxxxxxxx"

$ProjectBranches = $ProjectBranchesResponse.Content | ConvertFrom-Json

Write-Host $ProjectBranches[0].owner