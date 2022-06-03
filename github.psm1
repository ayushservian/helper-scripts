<# Import this module to use these functions
Import-Module .\github.psm1 -Force

# This is quick throw together hack / "SNAG" day script. Needs refactor / optimizing.

############ EXAMPLE 1 ##############
Get-GitHubStaleBranch -RepositoryName "budp-common" `
| Sort-Object lastCommitAuthor, lastCommitDate `
| Select-Object name, lastCommitDate, lastCommitAuthor, LastCommitMessage `
| Format-Table -AutoSize

############ EXAMPLE 2 ##############
Remove-GitHubStaleBranches -BranchNames <file-name>.txt -RepositoryName budp-hybris -Verbose

Remove-GitHubStaleBranches -BranchNames ../budp-hybris-Delete-Test.txt -RepositoryName budp-hybris -Verbose

produces a log file with name _<file-name>-Deletion.log_
e.g. _budp-hybris-Delete-Test-Deletion.log_, with contents as below:
> Deleting test/branch-to-be-deleted-3...
> Deleted test/branch-to-be-deleted-3
> Deleting test/branch-to-be-deleted-2...
> Error deleting test/branch-to-be-deleted-2 :-> Reference does not exist
> 

also produces a _<file-name>-Retry.txt_  for failed branches to be used for the retrial
e.g. for above it'll have _budp-hybris-Delete-Test-Retry.txt_  with below contents
>test/branch-to-be-deleted-2
>

where _budp-hybris-Delete-Test.txt_ has the below contents:
> test/branch-to-be-deleted-3
> test/branch-to-be-deleted-2
> 


#####################################

############ IMPORTANT ################
Requires the PowerShellForGitHub module https://github.com/Microsoft/PowerShellForGitHub
Install-Module -Name PowerShellForGitHub -Scope CurrentUser

############ CONIGURATION ################
To avoid severe API rate limiting by GitHub, you should configure the module with your own personal access token.
Call Set-GitHubAuthentication, enter anything as the username (the username is ignored but required by the dialog that pops up), and paste in the API token as the password. 
That will be securely cached to disk and will persist across all future PowerShell sessions. If you ever wish to clear it in the future, just call Clear-GitHubAuthentication).


# SNIPPETS while developing the script
$r = Get-GitHubRepository -RepositoryName "budp-common"
$r.size shows size of repo in kB

$b = Get-GitHubRepositoryBranch -RepositoryName "budp-common"

Get-GitHubRepositoryBranch -OwnerName microsoft -RepositoryName PowerShellForGitHub
#>

$OwnerName = "Bunnings-Digital"
Set-GitHubConfiguration -DefaultOwnerName $OwnerName


function Compare-GitHubRepositoryBranch {
    [CmdletBinding()]
    param (
        $RepositoryName,
        $FromBranch,
        $ToBranch # the default or target base branch
    )    
    # Compare branches that are ahead/behind - but the PSGithub module doesnt have a method to call it.
    # So invoke our own Github API call 
    # the per_page seems ignored in the GHRestMethod? returned files.count is 300
    # Invoke-GHRestMethod -UriFragment "/repos/Bunnings-Digital/budp-hybris/compare/master...develop?per_page=1" -Method Get

    $c = Invoke-GHRestMethod -UriFragment "/repos/$($OwnerName)/$($RepositoryName)/compare/$($ToBranch)...$($FromBranch)" -Method Get
    
    [PSCustomObject]@{
        status = $c.status
        aheadyBy = $c.ahead_by
        behindBy = $c.behind_by
        totalCommits = $c.total_commits
    }
}


function Get-GitHubStaleBranch {
    [CmdletBinding()]
    param (
        $RepositoryName,
        $OutFile = $False,
        $staleDays = 30
    )
    
    # TODO - Continuously cache to disk to mimimize Github API calls / API limits

    $File = "../$($RepositoryName)-$(get-date -f yyyyMMddhhmmss)"

    $repoBranches = Get-GitHubRepositoryBranch -OwnerName $OwnerName -RepositoryName $RepositoryName 
    Write-Verbose "Found [$($repoBranches.count)] branches."

    $staleBranchCollection = @()
    $staleDate = (Get-Date).AddDays(0 - $staleDays)
    Write-Verbose "Stale Date: $($staleDate)"

    # Some repos currently have thousands branches, so poll individually to minimize memory use
    # TODO - improve visibility of progess?
    # Convert this to a Process () so object can be pipelined to other functions

    ForEach ($repobranch in $repoBranches) {
        $branch = $repoBranch | Get-GitHubRepositoryBranch

        If ($branch.commit.commit.committer.date -lt $staleDate) {
            Write-Verbose "Found stale branch $($branch.name)" # last commit $($branch.commit.commit.committer.date)"

            $staleBranch = [PSCustomObject]@{
                Name = $branch.name
                LastCommit = $branch.commit.sha
                LastCommitDate = $branch.commit.commit.committer.date
                LastCommitAuthor = $branch.commit.commit.author.name
                LastCommitAuthorEmail = $branch.commit.commit.author.email
                LastCommitAuthorLogin = $branch.commit.author.login
                LastCommitMessage = $branch.commit.commit.message.Trim()
            }
            if ($OutFile)
            {
                Add-Content -Value $staleBranch -Path "$File.log"
            }
            $staleBranchCollection += $staleBranch
        }   

    }

    if ($OutFile)
    {
        $staleBranchCollection `
        | Sort-Object lastCommitAuthor, lastCommitDate `
        | Select-Object name, lastCommitDate, lastCommitAuthor, LastCommitMessage `
        | Format-Table -AutoSize `
        | Out-String `
        | Add-Content -Path "$File.txt"

        $staleBranchCollection `
        | Select-Object name `
        | Out-String `
        | Add-Content -Path "$File-Delete.txt"
    }
    $staleBranchCollection
}

function Remove-GitHubStaleBranches {
    [CmdletBinding()]
    param (
        $RepositoryName,
        $BranchNames
    )
    
    foreach ($BranchName in Get-Content $BranchNames) {
        $Logs = "Deleting $BranchName..."
        Write-Verbose $Logs
        Add-Content -Value $Logs -Path "$($BranchNames.Replace('.txt','-Deletion.log'))"
        try {
            Remove-GitHubRepositoryBranch -OwnerName $OwnerName -RepositoryName $RepositoryName -BranchName $BranchName -Force
            $Logs = "Deleted $BranchName"    
            Write-Verbose $Logs
            Add-Content -Value $Logs -Path "$($BranchNames.Replace('.txt','-Deletion.log'))"
        }
        catch {
            $Logs = "Error deleting $BranchName :-> $(($_ | ConvertFrom-Json).message)"
            Write-Verbose $Logs
            Add-Content -Value $BranchName -Path "$($BranchNames.Replace('.txt','-Retry.txt'))"
            Add-Content -Value $Logs -Path "$($BranchNames.Replace('.txt','-Deletion.log'))"
        }
    }
}
Export-ModuleMember Get-GitHubStaleBranch
Export-ModuleMember Compare-GitHubRepositoryBranch
Export-ModuleMember Remove-GitHubStaleBranches