Remove-Module JobSetManager
Import-Module JobSetManager -Force
Invoke-JSMProcessingLoop -JobDefinition $jobs -SleepSecondsBetweenJobCheck 5 -Interactive -JobFailureRetryLimit 3