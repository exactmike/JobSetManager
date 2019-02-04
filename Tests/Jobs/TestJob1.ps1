[pscustomobject]@{Name = 'TestJob1'
    Message = "Runs a Test Job 1"
    PreJobCommands = [ScriptBlock]{
        $null = Get-Command Get-Command -ErrorAction Stop
    }
    StartRSJobParams = @{
        ScriptBlock = {
            1..5 | foreach-object {[pscustomobject]@{ItemID = $_ ; time = Get-Date; JobName = 'TestJob1'}}
        }
    }
    DependsOnJobs = @()
    OnCondition = @()
    OnNotCondition = @('')
    ResultsVariableName = 'TestJob1Items'
    ResultsValidation = @{
        ValidateType = [array]
        ValidateElementCountExpression = '-gt 1'
    }
    RemoveVariablesAtCompletion = @()
    PostJobCommands = [ScriptBlock]{
        $null = Get-Command Get-Command -ErrorAction Stop
    }
}