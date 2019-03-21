# Issues / To Do

- [x] when restarting a job processing loop some start/end times are lost on jobs.  Need to detangle requiredjobs and definedjobs in invoke-jsmprocessingloop
- [ ] make RequiredJobs a hashtable just like the other *jobs variables
- [x] fix the notification settings
- [ ] make set-jsmperiodicreportsetting leave current values in place and only set what is specified each time it is used
- [ ] need a check for non-completed but no longer running JF jobs (JF = Job Framework, rightnow just poshrsjob)
- [ ] Consider adding job variable tracking  - created, removed, currently existing. and being able to temporarially suppress removal for T/S
- [ ] fix Invoke-JSMProcessingLOop restartstopwatch parameter
- [x] remove Invoke-JSMProcessingLOop retainjobfailures parameter
- [ ] JobTypes - make the commands in the JSON a hashtable for easier lookup in the module functions