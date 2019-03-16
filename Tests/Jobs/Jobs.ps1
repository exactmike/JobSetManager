[pscustomobject]@{Name = 'TestJob1'
    Message = "Runs a Test Job 1"
    PreJobCommands = [ScriptBlock]{
        $null = Get-Command Get-Command -ErrorAction Stop
    }
    StartJobParams = @{
        ScriptBlock = {
            1..5 | foreach-object {[pscustomobject]@{ItemID = $_ ; time = Get-Date; JobName = 'TestJob1'}}
        }
    }
    DependsOnJobs = @()
    OnCondition = @()
    OnNotCondition = @()
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
[pscustomobject]@{Name = 'TestJob2'
    Message = "Runs a Test Job 2"
    PreJobCommands = [ScriptBlock]{
        $null = Get-Command Get-Command -ErrorAction Stop
    }
    StartJobParams = @{
        ScriptBlock = {
            $hashtable = @{}
            1..5 | foreach-object {[pscustomobject]@{ItemID = $_ ; time = Get-Date; JobName = 'TestJob2'}} |
            ForEach-Object -Process {$hashtable.$($_.ItemID) = $_}
            $hashtable
        }
    }
    DependsOnJobs = @()
    OnCondition = @()
    OnNotCondition = @()
    ResultsVariableName = 'TestJob2Items'
    ResultsValidation = @{
        ValidateType = [hashtable]
        ValidateElementCountExpression = '-eq 5'
    }
    RemoveVariablesAtCompletion = @()
    PostJobCommands = [ScriptBlock]{
        $null = Get-Command Get-Command -ErrorAction Stop
    }
}
[pscustomobject]@{Name = 'TestJob3'
    Message = "Runs a Test Job 3"
    PreJobCommands = [ScriptBlock]{
        $null = Get-Command Get-Command -ErrorAction Stop
    }
    StartJobParams = @{
        ScriptBlock = {
            $using:TestJob1Items | Measure-object -property ItemID -Maximum -Minimum -Average -Sum -blat
        }
    }
    DependsOnJobs = @('TestJob1')
    OnCondition = @()
    OnNotCondition = @()
    ResultsVariableName = 'TestJob3Object'
    ResultsValidation = @{
        ValidateType = [Microsoft.PowerShell.Commands.GenericMeasureInfo]
    }
    RemoveVariablesAtCompletion = @()
    PostJobCommands = [ScriptBlock]{
        $null = Get-Command Get-Command -ErrorAction Stop
    }
}
[pscustomobject]@{Name = 'TestJob4'
    Message = "Runs a Test Job 4"
    PreJobCommands = [ScriptBlock]{
        $null = Get-Command Get-Command -ErrorAction Stop
    }
    StartJobParams = @{
        ScriptBlock = {
            $ToProcess = $using:TestJob2Items
            $ToProcess.Values | foreach-object {{$_}.invoke()}
        }
    }
    DependsOnJobs = @('TestJob2')
    OnCondition = @()
    OnNotCondition = @('')
    ResultsVariableName = 'TestJob4Object'
    ResultsValidation = @{
        ValidateElementMember = @('time')
    }
    RemoveVariablesAtCompletion = @()
    PostJobCommands = [ScriptBlock]{
        $null = Get-Command Get-Command -ErrorAction Stop
    }
}