[pscustomobject]@{
    Name = 'ConvertADUsersToCustomUserObjects' #also gets added to StartRSJobParams as Name at runtime
    Message = 'Convert AD Users to Custom User Objects' #not used anywhere, yet...
    PreJobCommands = [ScriptBlock]{} #run before the job is called. Runs in the control runspace . . . 
    JobSplit = 4 #how many jobs you want to run for your data, if 1, this is ignored
    JobSplitDataVariableName = 'ADUsers' #the data to split among the jobsplit jobs. if JobsSplit is 1, this is ignored  
    ArgumentList='' #you can add arguments here instead of in the StartRSJobParams.  Difference is, here it is an array of strings, evaluated at job start time for matchinv variables.
    StartRSJobParams = @{
        ErrorAction = 'Stop'  #optional, recommended to stop
        FunctionsToLoad = @('Convert-ADUserToCustomUserObject','Convert-ProxyAddressToCustomAlias','Get-AdObjectDomain','Test-IDAvailability','Test-ProxyAddressAvailability') 
        ModulesToImport = @() #optional
        PSSnapinsToImport = @()
        ArgumentList = $decoystring,$TestForDuplicateID,$DuplicateIDFound,$TestForDuplicateProxyAddress,$DuplicateProxyAddressFound #due to a bug in poshRSJob, first argument may be lost, these must exist when the job metadata object is created or they will be NULL
        Throttle = 5 #optional
        ScriptBlock = [ScriptBlock]{ #scriptblock for the job to run
            param($TestForDuplicateID,$DuplicateIDFound,$TestForDuplicateProxyAddress,$DuplicateProxyAddressFound)#note first argument is not referenced
            $Settings = $using:Settings #you can use arguments with param() block along with $using:
            $ADUsers = $using:YourSplitData | Select-Object -Property *
            $ConvertADUsersToCustomUserObjectParams = @{
                ADUser = $ADUsers
                GroupRoleMapHashByDN = $Using:GroupRoleMapHashByDN
                ExchangeMailboxesHashByEDGUID = $Using:OLMailboxesHashByEDGUID
                OPGUIDToOLGUIDHashByOPGUID = $Using:OPGUIDToOLGUIDHashByOPGUID
                NotesUsersHashByInternetAddress = $Using:NotesUsersHashByInternetAddress
                ADDomainDNSRootToNetBiosNameHash = $using:ADDomainDNSRootToNetBiosNameHash
            }
            $CustomUserObjects = Convert-ADUserToCustomUserObject @ConvertADUsersToCustomUserObjectParams
            Write-Output -InputObject $CustomUserObjects    
        }
    }
    DependsOnJobs = @('CreateGroupRoleMapHashByDN','GetADUsers','CreateOLMailboxesHashByEDGUID','CreateOPGUIDTOOLGUIDHashByOPGUID','CreateNotesUsersHashByInternetAddress','CreateADDomainDNSRootToNetBiosNameHash') #this is used to determine when the job can be run
    OnCondition = @() #this determines if the job should be run, any values here need to be true in Conditions
    OnNotCondition = @() #this determines if the job should be run, any values here need to be false in Conditions
    ResultsVariableName = 'CustomUserObjects' #name of the output variable to which the output will be received 
    ResultsKeyVariableNames = @() #if output is a hashtable and you want to have variables for different keys, use this
    ResultsValidation = [hashtable]@{
        ValidateType = [array]
        ValidateElementCountExpression = '-gt 1'
        ValidateElementMember = @()
        ValidatePath = $true
        ValidateScript = [scriptblock]{} #Not implemented yet . . .
    }
    JobFailureRetryLimit = $null #Will use the default if NULL otherwise set to an integer
    RemoveVariablesAtCompletion = @('ADUsers','GroupRoleMapHashByDN','OPGUIDToOLGUIDHashByOPGUID','OLMailboxesHashByEDGUID','NotesUsersHashByInternetAddress') #loop removes these variables on successful completion of the job, used for memory management when dealing with large data sets
    PostJobCommands = [ScriptBlock]{} #this code runs after the job successfully completes.  runs in the control runspace
}
#add variable dependency logic for variable deletion: DependsOnVariable attribute.  Variables would be auto-deleted after the last job that needs them is completed successfully
#add job failure handling - needs attribute(s) on the jobs as well as handling in the processing loop