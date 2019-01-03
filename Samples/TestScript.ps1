Import-Module PoshRSJob
Import-Module JobSetManager -Force
$global:testsynchashtable1 = [hashtable]::Synchronized(@{})
$global:testsynchashtable2 = [hashtable]::Synchronized(@{})
$global:decoystring = 'decoystring' #this is for a bug that exists/existed in PoshRSJob
$settings = @{}
$Jobs = @(
    [pscustomobject]@{
        Name = 'TestAccessToSynchronizedHashtable' #also gets added to StartRSJobParams as Name at runtime
        PreJobCommands = [ScriptBlock]{} #run before the job is called. Runs in the control runspace . . .
        JobSplit = 1 #how many jobs you want to run for your data, if 1, this is ignored
        JobSplitDataVariableName = $null #the data to split among the jobsplit jobs. if JobsSplit is 1, this is ignored
        ArgumentList=@('decoystring','testsynchashtable1','testsynchashtable2') #you can add arguments here instead of in the StartRSJobParams.  Difference is, here it is an array of strings, evaluated at job start time for matchinv variables.
        StartRSJobParams = @{
            ErrorAction = 'Stop'  #optional, recommended to stop
            ScriptBlock = [ScriptBlock]{ #scriptblock for the job to run
                param($testsynchashtable1,$testsynchashtable2)#note first argument is not referenced
                [System.Threading.Monitor]::Enter($testsynchashtable1.SyncRoot)
                $testsynchashtable1.table1 = $true
                [System.Threading.Monitor]::Exit($testsynchashtable1.SyncRoot)
                [System.Threading.Monitor]::Enter($testsynchashtable2.SyncRoot)
                $testsynchashtable2.table2 = $true
                [System.Threading.Monitor]::Exit($testsynchashtable2.SyncRoot)
            }
        }
        DependsOnJobs = @() #this is used to determine when the job can be run
        OnCondition = @() #this determines if the job should be run, any values here need to be true in Conditions
        OnNotCondition = @() #this determines if the job should be run, any values here need to be false in Conditions
        ResultsVariableName = 'null' #name of the output variable to which the output will be received
        ResultsKeyVariableNames = @() #if output is a hashtable and you want to have variables for different keys, use this
        ResultsValidation = [hashtable]@{
        }
        RemoveVariablesAtCompletion = @() #loop removes these variables on successful completion of the job
        PostJobCommands = [ScriptBlock]{} #this code runs after the job successfully completes.  runs in the control runspace
    }
)
#test-getVariable -job $jobs[0]
Invoke-JobProcessingLoop -Settings $settings -JobDefinitions $Jobs -SleepSecondsBetweenJobCheck 5 -Interactive
$decoystring
$testsynchashtable1
$testsynchashtable2