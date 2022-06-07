$Projects = az devops project list `
            --org https://dev.azure.com/ORG_NAME `
            | ConvertFrom-Json

foreach($Project in $Projects.value){
    Write-Host "$($Project.name)`r`n"
    az pipelines list -o table `
        --project="$($Project.name)" `
        --org https://dev.azure.com/ORG_NAME
    Write-Host "`r`n"
}