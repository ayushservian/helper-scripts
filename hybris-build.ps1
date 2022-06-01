function build {
    Write-Host  "HTTP ccv2 build api and extract build number"
    Write-Host "\nStarting CCV2 build number - build_code: "
    Write-Host "Validating Build Status.. Please wait"

    $keyVaultSAPCCV2Token = $env:SAPCCV2Token
    $Headers = @{
        Authorization = "Bearer $keyVaultSAPCCV2Token"
        "Content-Type" = "application/json"
    }


    # $URI = "https://portalrotapi.hana.ondemand.com/v2/subscriptions/12345123412341324/builds"


    # $Body = @{
    #     branch =  "$env:Source_Branch"
    #     name = "$env:BUILD_NAME"
    # }

    # Write-Host "Calling $URI"
    # $BuildApiResponse = Invoke-WebRequest `
    #                     -Uri $URI `
    #                     -Headers $Headers `
    #                     -Body $($Body | ConvertTo-Json) `
    #                     -Method POST

    # $Build = $BuildApiResponse.Content | ConvertFrom-Json
    # Write-Host $Build.code

    # $env:BuildCode = $Build.code
    $build_code = $env:BuildCode
    $URI = "https://portalrotapi.hana.ondemand.com/v2/subscriptions/12345123412341324/builds/$build_code"

    $BuildApiResponse = Invoke-WebRequest `
                        -Uri $URI `
                        -Headers $Headers `
                        -Method GET
    $Build = $BuildApiResponse.Content | ConvertFrom-Json

    $isStatusSuccess = $Build.status -eq "SUCCESS"
    If ($isStatusSuccess) {
        Write-Host  "Success - go to next step"
    } else {
        Write-Host  "Failed - send teams notification?"
        Write-Host "##vso[task.complete result=Failed;]Failed"
    }

    Write-Host "Use built in teams notification connected to service hooks on azure devops"
    
}

function Get-Resource {
    Param([string]$URI, [string]$Token, [bool]$BasicOrBearer)

    
    $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($Token + ":"))
    $authValue = If ($BasicOrBearer -eq $null) {"Basic $encodedCreds"} else { "Bearer $Token"}
    
    $Headers = @{
        Authorization = $authValue
    }

    $Response = Invoke-WebRequest `
        -Uri $URI `
        -Headers $Headers `
        -Method GET
    return $Response
}

function SonarQualityCheck {
    $KeyVaultSecret = $env:TOKEN + ":"
    $Branch = $env:BRANCH_NAME
    $ProjectKey = "projkey"

    $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($KeyVaultSecret))
    $basicAuthValue = "Basic $encodedCreds"
    $Headers = @{ Authorization = $basicAuthValue }

    $ProjectStatusResponse = Invoke-WebRequest `
                                -Uri "https://codequality.yoursite.com.au/api/qualitygates/project_status?projectKey=$ProjectKey" `
                                -Headers $Headers `
                                -Method GET
                                
    $ProjectStatus = $ProjectStatusResponse.Content | ConvertFrom-Json

    $ProjectBranchesResponse = Invoke-WebRequest `
                                -Uri "https://codequality.yoursite.com.au/api/project_branches/list?project=$ProjectKey" `
                                -Headers $Headers `
                                -Method GET
                                
    $ProjectBranches = $ProjectBranchesResponse.Content | ConvertFrom-Json

    Write-Host $ProjectBranchesResponse.Content

    $branchDetails = $ProjectBranches.branches | Where-Object name -eq $Branch

    Write-Host "Overall project quality gate status" $ProjectStatus.projectStatus.status
    Write-Host "Branch quality gate status" $branchDetails.status.qualityGateStatus

    if(($ProjectStatus.projectStatus.status -ne "OK"))
    {
        Write-Host "FAIL: Overall Project quality failed" -ForegroundColor Red
        Write-Host "##vso[task.complete result=Failed;]Failed"
    } 
    if(($branchDetails.status.qualityGateStatus -ne "OK") )
    {
        Write-Host "FAIL: Branch quality gate failed" -ForegroundColor Red
        Write-Host "##vso[task.complete result=Failed;]Failed"
    }
}

function CleanUp {
    $registryName = 'yourACR'
    $doNotDeleteTags = '7'
    $skipLastTags = 4

    $repoArray = @('imagecleanuptest')
    #az acr repository list --name $registryName --output json | ConvertFrom-Json

    foreach ($repo in $repoArray)
    {
        $tagsArray = (az acr repository show-tags --name $registryName --repository $repo --orderby time_asc --output json | ConvertFrom-Json ) | Select-Object -SkipLast $skipLastTags

        foreach($tag in $tagsArray)
        {

            if ($donotdeletetags -contains $tag)
            {
                Write-Output ("This tag is marked important and so not deleted: $tag")
            }
            else
            {
                Write-Output ("Deleting $registryName -> $repo with tag $tag")
                # az acr repository delete --name $registryName --image $repo":"$tag --yes
                $Purge_CMD = "acr purge --filter '$($repo):$($tag)' --ago 0d"
                Write-Host $Purge_CMD
                az acr run `
                    --cmd $Purge_CMD `
                    --registry $registryName `
                    /dev/null
            }
    
        }
    }
}

function CleanUpSmaller {
    $registryName = 'yourACR'
    $skipLastTags = 4

    $repoArray = @('imagecleanuptest')
    #az acr repository list --name $registryName --output json | ConvertFrom-Json

    foreach ($repo in $repoArray)
    {
        Write-Output ("Deleting $registryName -> $repo")
        # az acr repository delete --name $registryName --image $repo":"$tag --yes
        $Purge_CMD = "acr purge --filter '$($repo):.*' --keep $($skipLastTags) --ago 0d"
        Write-Host $Purge_CMD
        az acr run `
            --cmd $Purge_CMD `
            --registry $registryName `
            /dev/null
    }
}

function DockerImagePush {
    Param([Int]$NumberOfTags, [Int]$StartingTag)

    Write-Host $NumberOfTags
    docker pull docker/whalesay
    az acr login -n yourACR
    if($null -eq $StartingTag){
        $Tag = 0
    } else {
        $Tag = $StartingTag
    }
    while ($NumberOfTags -gt $Tag) {
        $Tag++;
        Write-Host "Writing tag: $Tag"
        docker tag docker/whalesay yourACR.azurecr.io/imagecleanuptest:$Tag
        docker push yourACR.azurecr.io/imagecleanuptest:$Tag
    }

}

DockerImagePush $args[0] $args[1]
# CleanUp
CleanUpSmaller

# $env:Source_Branch = "feature/prefix-7277-CI-pipeline" #$(Build.SourceBranch)
# $env:BUILD_NAME = "prefix-7278-1"
# $env:SAPCCV2Token = "ccv2token"
# $env:BuildCode = "20220505.12"
# build

# $env:TOKEN = "sometoken" 
# $env:BRANCH_NAME = "prefix-7277-CI-pipeline"
# SonarQualityCheck