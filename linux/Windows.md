# 1. Powershell 问题

activate.ps1 cannot be loaded because running scripts is disabled on this system. For more information, see about_Ex ecution_Policies at https:/go.microsoft.com/fwlink/?LinkID=135170.

```bash
PS C:\> Get-ExecutionPolicy -List
        Scope ExecutionPolicy
        ----- ---------------
MachinePolicy       Undefined
   UserPolicy       Undefined
      Process    Unrestricted
  CurrentUser       Undefined
 LocalMachine      Restricted
 
PS C:\> Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser

Execution Policy Change
The execution policy helps protect you from scripts that you do not trust. Changing the execution policy might expose
you to the security risks described in the about_Execution_Policies help topic at
https:/go.microsoft.com/fwlink/?LinkID=135170. Do you want to change the execution policy?
[Y] Yes  [A] Yes to All  [N] No  [L] No to All  [S] Suspend  [?] Help (default is "N"): A
```

