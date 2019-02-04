Remove-Module JobSetManager
Import-Module JobSetManager -Force
Invoke-JSMProcessingLoop -JobDefinitions $jobs -SleepSecondsBetweenJobCheck 5 -Interactive -JobFailureRetryLimit 3