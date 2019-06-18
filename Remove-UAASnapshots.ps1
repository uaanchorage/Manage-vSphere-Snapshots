<#
    Created By: John Zetterman
    Last Modified: 6/12/2019
#>

Function Get-UAASnapshots {
    [CmdletBinding(DefaultParameterSetName="default")]

    Param
    (
        [Parameter(Mandatory=$false, Position=0, ParameterSetName="default")]
        [string]$Datacenter,
        
        [Parameter(Mandatory=$true, Position=0, ParameterSetName="Specific VM")]
        [Parameter(Mandatory=$true, Position=0, ParameterSetName="Specific Snapshot")]
        [string[]]$VirtualMachine,

        [Parameter(Mandatory=$true, Position=1, ParameterSetName="Specific Snapshot")]
        [string]$SnapshotName,

        [Parameter(Mandatory=$false, Position=1, ParameterSetName="default")]
        [Parameter(Mandatory=$false, Position=1, ParameterSetName="Specific VM")]
        [int]$OlderThan = 0
    )

    Write-Debug "Using ParameterSetName: $($PSCmdlet.ParameterSetName)"

    switch ($PSCmdlet.ParameterSetName)
    {
        "Specific VM"
        {
            Write-Debug "Processing VM: $VirtualMachine"
            $Snapshots = Get-VM -Name $VirtualMachine | Get-Snapshot | Where-Object {$_.Created -lt (Get-Date).AddDays(-$OlderThan)}
        }

        "Specific Snapshot"
        {
            Write-Debug "Processing Snapshot: $SnapshotName"
            $Snapshots = Get-Snapshot -VM $VirtualMachine -Name $SnapshotName | Where-Object {$_.Created -lt (Get-Date).AddDays(-$OlderThan)}
        }

        default
        {
            if ($Datacenter)
            {
                $Snapshots = Get-Datacenter -Name $Datacenter | Get-VM | Get-Snapshot | Where-Object {$_.Created -lt (Get-Date).AddDays(-$OlderThan)}
            }
            else
            {
                $Snapshots = Get-VM | Get-Snapshot | Where-Object {$_.Created -lt (Get-Date).AddDays(-$OlderThan)}
            }
        }
    }

    Return $Snapshots

    <#
    .SYNOPSIS

    Gets a list of existing snapshots from vCenter.

    .DESCRIPTION

    Returns a list of snapshots from vCenter. Results can be filtered by 
    vSphere Datacenter, Days Old, or VM Name.

    .INPUTS

    None. You cannot pipe objects to Get-UAASnapshots.

    .OUTPUTS

    VMware.VimAutomation.ViCore.Impl.V1.VirtualMachine.SnapshotImpl. Get-UAASnapshots returns a custom
    VMware object containing the results of the function.

    .EXAMPLE

    PS> Get-UAASnapshots -Datacenter 'Anchorage Datacenter' -OlderThan 2 | Select VM, Name, Created

    VM                              Name                                             Created
    --                              ----                                             -------
    AR-TEST                         AR-TEST_vm-117097_1                              5/21/2019 11:36:48 AM
    anc-licensing04                 VM Snapshot 1%252f4%252f2019, 10:15:38 AM        1/4/2019 10:15:54 AM 
    Arctic                          Before License Manager                           6/5/2017 6:57:46 AM

    .EXAMPLE

    PS> Get-UAASnapshots -SnapshotName AR-TEST | Select VM, Name, Created                                  

    VM      Name                Created
    --      ----                -------
    AR-TEST AR-TEST_vm-117097_1 5/21/2019 11:36:48 AM

    .LINK

    https://github.com/uaanchorage/Manage-vSphere-Snapshots

    #>
}

Function Remove-UAASnapshots {
    [CmdletBinding(DefaultParameterSetName="default", SupportsShouldProcess=$True)]

    Param
    (
        [Parameter(Mandatory=$false, Position=0, ParameterSetName="default")]
        [string]$Datacenter,

        [Parameter(Mandatory=$true, Position=0, ParameterSetName="Specific VM")]
        [Parameter(Mandatory=$true, Position=0, ParameterSetName="Specific Snapshot")]
        [string]$VirtualMachine,

        [Parameter(Mandatory=$true, Position=1, ParameterSetName="Specific Snapshot")]
        [string]$SnapshotName,
        
        [Parameter(Mandatory=$true, Position=1, ParameterSetName="default")]
        [Parameter(Mandatory=$true, Position=1, ParameterSetName="Specific VM")]
        [int]$OlderThan,
        
        [Parameter(Mandatory=$false, Position=2, ParameterSetName="default")]
        [Parameter(Mandatory=$false, Position=2, ParameterSetName="Specific VM")]
        [switch]$RemoveChildren,

        [Parameter(Mandatory=$false, Position=3, ParameterSetName="default")]
        [Parameter(Mandatory=$false, Position=3, ParameterSetName="Specific VM")]
        [Parameter(Mandatory=$false, Position=3, ParameterSetName="Specific Snapshot")]
        [switch]$EmailNotification
    )

    Write-Debug "Using ParameterSetName: $($PSCmdlet.ParameterSetName)"

    $RemovedSnapshots = @()

    switch ($PSCmdlet.ParameterSetName) 
    {
        "Specific VM"
        {
            if ($RemoveChildren)
            {
                $Snapshots = Get-UAASnapshots -SnapshotName $VirtualMachine -OlderThan $OlderThan | Where-Object {$null -eq $_.Parent}
                ForEach ($Snapshot in $Snapshots)
                {
                    $RemovedObjectList = New-Object psobject
                    $RemovedObjectList | Add-Member -MemberType NoteProperty -Name VirtualMachine -Value $Snapshot.VM
                    $RemovedObjectList | Add-Member -MemberType NoteProperty -Name SnapshotName -Value $Snapshot.Name
                    $RemovedObjectList | Add-Member -MemberType NoteProperty -Name ChildSnapshots -Value $true
                    Write-Debug "VM Name: $($Snapshot.VirtualMachine)"
                    Write-Debug "Snapshot Name: $($Snapshot.Name)"
                    Write-Debug "Child Snapshots: Yes"
                    $Snapshot | Remove-Snapshot -RemoveChildren -Confirm:$false

                    $RemovedSnapshots += $RemovedObjectList
                }
            }
            else
            {
                $Snapshots = Get-UAASnapshots -SnapshotName $VirtualMachine -OlderThan $OlderThan | Where-Object {$null -eq $_.Parent}
                ForEach ($Snapshot in $Snapshots) 
                {
                    $RemovedObjectList = New-Object psobject
                    $RemovedObjectList | Add-Member -MemberType NoteProperty -Name VirtualMachine -Value $Snapshot.VM
                    $RemovedObjectList | Add-Member -MemberType NoteProperty -Name SnapshotName -Value $Snapshot.Name
                    $RemovedObjectList | Add-Member -MemberType NoteProperty -Name ChildSnapshots -Value $false
                    Write-Debug "VM Name: $($Snapshot.VirtualMachine)"
                    Write-Debug "Snapshot Name: $($Snapshot.Name)"
                    Write-Debug "Child Snapshots: No"
                    $Snapshot | Remove-Snapshot -Confirm:$false

                    $RemovedSnapshots += $RemovedObjectList
                }
            }
        }

        "Specific Snapshot"
        {
            $Snapshot = Get-UAASnapshots -VirtualMachine $VirtualMachine -SnapshotName $SnapshotName
            $RemovedObjectList = New-Object psobject
            $RemovedObjectList | Add-Member -MemberType NoteProperty -Name VirtualMachine -Value $Snapshot.$VM
            $RemovedObjectList | Add-Member -MemberType NoteProperty -Name SnapshotName -Value $Snapshot.Name
            $RemovedObjectList | Add-Member -MemberType NoteProperty -Name ChildSnapshots -Value $false
            Write-Debug "VM Name: $($Snapshot.VirtualMachine)"
            Write-Debug "Snapshot Name: $($Snapshot.SnapshotName)"
            Write-Debug "Child Snapshots: No"
            $Snapshot | Remove-Snapshot -Confirm:$false

            $RemovedSnapshots += $RemovedObjectList
        }

        default
        {
            if ($Datacenter -and $RemoveChildren)
            {
                $Snapshots = Get-UAASnapshots -Datacenter $Datacenter -OlderThan $OlderThan | Where-Object {$null -eq $_.Parent}
                ForEach ($Snapshot in $Snapshots)
                {
                    $RemovedObjectList = New-Object psobject
                    $RemovedObjectList | Add-Member -MemberType NoteProperty -Name VirtualMachine -Value $Snapshot.VM
                    $RemovedObjectList | Add-Member -MemberType NoteProperty -Name SnapshotName -Value $Snapshot.Name
                    $RemovedObjectList | Add-Member -MemberType NoteProperty -Name ChildSnapshots -Value $true
                    $RemovedObjectList | Add-Member -MemberType NoteProperty -Name Created -Value $Snapshot.Created
                    Write-Debug "VM Name: $($Snapshot.VirtualMachine)"
                    Write-Debug "Snapshot Name: $($Snapshot.Name)"
                    Write-Debug "Child Snapshots: Yes"
                    $Snapshot | Remove-Snapshot -RemoveChildren -Confirm:$false

                    $RemovedSnapshots += $RemovedObjectList
                }
            }
            elseif ($Datacenter)
            {
                $Snapshots = Get-UAASnapshots -Datacenter $Datacenter -OlderThan $OlderThan | Where-Object {$null -eq $_.Parent}
                ForEach ($Snapshot in $Snapshots)
                {
                    $RemovedObjectList = New-Object psobject
                    $RemovedObjectList | Add-Member -MemberType NoteProperty -Name VirtualMachine -Value $Snapshot.VM
                    $RemovedObjectList | Add-Member -MemberType NoteProperty -Name SnapshotName -Value $Snapshot.Name
                    $RemovedObjectList | Add-Member -MemberType NoteProperty -Name ChildSnapshots -Value $false
                    Write-Debug "VM Name: $($Snapshot.VirtualMachine)"
                    Write-Debug "Snapshot Name: $($Snapshot.Name)"
                    Write-Debug "Child Snapshots: No"
                    $Snapshot | Remove-Snapshot -Confirm:$false

                    $RemovedSnapshots += $RemovedObjectList
                }
            }
            elseif ($RemoveChildren)
            {
                $Snapshots = Get-UAASnapshots -OlderThan $OlderThan | Where-Object {$null -eq $_.Parent}
                ForEach ($Snapshot in $Snapshots)
                {
                    $RemovedObjectList = New-Object psobject
                    $RemovedObjectList | Add-Member -MemberType NoteProperty -Name VirtualMachine -Value $Snapshot.VM
                    $RemovedObjectList | Add-Member -MemberType NoteProperty -Name SnapshotName -Value $Snapshot.Name
                    $RemovedObjectList | Add-Member -MemberType NoteProperty -Name ChildSnapshots -Value $true
                    Write-Debug "VM Name: $($Snapshot.VirtualMachine)"
                    Write-Debug "Snapshot Name: $($Snapshot.Name)"
                    Write-Debug "Child Snapshots: Yes"
                    $Snapshot | Remove-Snapshot -RemoveChildren -Confirm:$false

                    $RemovedSnapshots += $RemovedObjectList
                }
            }
            else 
            {
                $Snapshots = Get-UAASnapshots -OlderThan $OlderThan | Where-Object {$null -eq $_.Parent}
                ForEach ($Snapshot in $Snapshots)
                {
                    $RemovedObjectList = New-Object psobject
                    $RemovedObjectList | Add-Member -MemberType NoteProperty -Name VirtualMachine -Value $Snapshot.VM
                    $RemovedObjectList | Add-Member -MemberType NoteProperty -Name SnapshotName -Value $Snapshot.Name
                    $RemovedObjectList | Add-Member -MemberType NoteProperty -Name ChildSnapshots -Value $false
                    Write-Debug "VM Name: $($Snapshot.VirtualMachine)"
                    Write-Debug "Snapshot Name: $($Snapshot.Name)"
                    Write-Debug "Child Snapshots: No"
                    $Snapshot | Remove-Snapshot -Confirm:$false

                    $RemovedSnapshots += $RemovedObjectList
                }
            }
        }
    }

    $css = @"
    <STYLE>
    TABLE {border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;} 
    TH {border-width: 1px;padding: 3px;border-style: solid;border-color: black;background-color: #34495e; color:#ffffff;} 
    TD {border-width: 1px;padding: 3px;border-style: solid;border-color: black;} 
    TR:Nth-Child(Even) {Background-Color: #dddddd;}
    </STYLE>
"@

    $EmailBody = $RemovedSnapshots | ConvertTo-Html -Head $css -PreContent "Below is a summary of the snapshots that were removed from vCenter during script execution:<br /><br />" -PostContent "<br />File Name: $($MyInvocation.MyCommand). <br />Execution completed at $(Get-Date)" | Out-String

    if ($EmailNotification -and ($null -ne $RemovedSnapshots))
    {
        Send-MailMessage -To 'jmzetterman@alaska.edu' -From 'NoReply@uaa.alaska.edu' -Subject 'vCenter Snapshot Removal Summary' -Body $EmailBody -BodyAsHtml -SmtpServer 'aspam-out.uaa.alaska.edu'
    }
    else
    {
        Write-Host "Did not send notification." -ForegroundColor Red
    }


    Return $RemovedSnapshots

    <#
    .SYNOPSIS

    Remove a list of existing snapshots from vCenter.

    .DESCRIPTION

    Returns a list of snapshots that were removed from vCenter. Results can be 
    filtered by vSphere Datacenter, Days Old, VM Name, or Snapshot Name.

    .INPUTS

    None. You cannot pipe objects to Remove-UAASnapshots.

    .OUTPUTS

    System.Array. Get-UAASnapshots returns an array of objects containing
    the results of the function.

    .EXAMPLE

    PS C:\Users\jmzetterman.UA\Documents\OneDrive Personal\OneDrive\UAAGit> Remove-UAASnapshots -VirtualMachine AR-TEST -SnapshotName AR-TEST_vm-117097_1

    Name                           State      % Complete Start Time   Finish Time
    ----                           -----      ---------- ----------   -----------
    RemoveSnapshot_Task            Completed         100 10:32:27 AM  10:32:40 AM

    .EXAMPLE

    PS> Remove-UAASnapshots -Datacenter 'Anchorage Datacenter' -OlderThan 0 -RemoveChildren                        

    VirtualMachine SnapshotName   ChildSnapshots Created
    -------------- ------------   -------------- -------
    anc-vm01       VM Snapshot 1  True 7/10/2017 1:23:22 AM
    anc-vm02       VM Snapshot 1  True 6/8/2018  3:53:51 PM

    .LINK

    https://github.com/uaanchorage/Manage-vSphere-Snapshots

    #>
}

Function Send-UAANotification {
    Param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string]$ToAddress,

        [Parameter(Mandatory=$true, Position=1)]
        [string]$FromAddress,

        [Parameter(Mandatory=$true, Position=2)]
        [string]$EmailSubject,
        
        [Parameter(Mandatory=$true, Position=3)]
        [string]$EmailBody,
        
        [Parameter(Mandatory=$false, Position=4)]
        [string]$SMTPServer,

        [Parameter(Mandatory=$false, Position=4)]
        [switch]$BodyAsHtml
    )

    Send-MailMessage -From $FromAddress -To $ToAddress -Subject $EmailSubject -Body $EmailBody -SmtpServer $SMTPServer
}