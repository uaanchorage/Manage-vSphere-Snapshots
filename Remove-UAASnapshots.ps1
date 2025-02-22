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
            Write-Debug "[FUNCTION: Get-UAASnapshots] Snapshot Count: $($Snapshots.Count)"
            $DiscoveredSnapshots = New-SnapshotObject($Snapshots)
        }

        "Specific Snapshot"
        {
            Write-Debug "Processing Snapshot: $SnapshotName"
            $Snapshots = Get-Snapshot -VM $VirtualMachine -Name $SnapshotName | Where-Object {$_.Created -lt (Get-Date).AddDays(-$OlderThan)}
            Write-Debug "[FUNCTION: Get-UAASnapshots] Snapshot Count: $($Snapshots.Count)"
            $DiscoveredSnapshots = New-SnapshotObject($Snapshots)
        }

        default
        {
            if ($Datacenter)
            {
                $Snapshots = Get-Datacenter -Name $Datacenter | Get-VM | Get-Snapshot | Where-Object {$_.Created -lt (Get-Date).AddDays(-$OlderThan)}
                Write-Debug "[FUNCTION: Get-UAASnapshots] Snapshot Count: $($Snapshots.Count)"
                $DiscoveredSnapshots = New-SnapshotObject($Snapshots)
            }
            else
            {
                $Snapshots = Get-VM | Get-Snapshot | Where-Object {$_.Created -lt (Get-Date).AddDays(-$OlderThan)}
                Write-Debug "[FUNCTION: Get-UAASnapshots] Snapshot Count: $($Snapshots.Count)"
                $DiscoveredSnapshots = New-SnapshotObject($Snapshots)
            }
        }
    }

    Return $DiscoveredSnapshots

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

    Write-Debug "[FUNCTION: Remove-UAASnapshots] Using ParameterSetName: $($PSCmdlet.ParameterSetName)"

    switch ($PSCmdlet.ParameterSetName) 
    {
        "Specific VM"
        {
            if ($RemoveChildren)
            {
                $Snapshots = Get-UAASnapshots -SnapshotName $VirtualMachine -OlderThan $OlderThan | Where-Object {$null -eq $_.Parent}
                Write-Debug "[FUNCTION: Remove-UaaSnapshots] Snapshot Count: $($Snapshots.Count)"
                $RemovedSnapshots = Remove-UaaSnapshotsHelper($Snapshots, $RemoveChildren)
            }
            else
            {
                $Snapshots = Get-UAASnapshots -SnapshotName $VirtualMachine -OlderThan $OlderThan | Where-Object {$null -eq $_.Parent}
                Write-Debug "[FUNCTION: Remove-UaaSnapshots] Snapshot Count: $($Snapshots.Count)"
                $RemovedSnapshots = Remove-UaaSnapshotsHelper($Snapshots, $RemoveChildren)
            }
        }

        "Specific Snapshot"
        {
            $Snapshots = Get-UAASnapshots -VirtualMachine $VirtualMachine -SnapshotName $SnapshotName
            $RemovedSnapshots = Remove-UaaSnapshotsHelper($Snapshots, $RemoveChildren)
        }

        default
        {
            if ($Datacenter -and $RemoveChildren)
            {
                $Snapshots = Get-UAASnapshots -Datacenter $Datacenter -OlderThan $OlderThan | Where-Object {$null -eq $_.Parent}
                Write-Debug "[FUNCTION: Remove-UaaSnapshots] Snapshot Count: $($Snapshots.Count)"
                $RemovedSnapshots = Remove-UaaSnapshotsHelper($Snapshots, $RemoveChildren)
            }
            elseif ($Datacenter)
            {
                $Snapshots = Get-UAASnapshots -Datacenter $Datacenter -OlderThan $OlderThan | Where-Object {$null -eq $_.Parent}
                Write-Debug "[FUNCTION: Remove-UaaSnapshots] Snapshot Count: $($Snapshots.Count)"
                $RemovedSnapshots = Remove-UaaSnapshotsHelper($Snapshots, $RemoveChildren)
            }
            elseif ($RemoveChildren)
            {
                $Snapshots = Get-UAASnapshots -OlderThan $OlderThan | Where-Object {$null -eq $_.Parent}
                Write-Debug "[FUNCTION: Remove-UaaSnapshots] Snapshot Count: $($Snapshots.Count)"
                $RemovedSnapshots = Remove-UaaSnapshotsHelper($Snapshots, $RemoveChildren)
            }
            else 
            {
                $Snapshots = Get-UAASnapshots -OlderThan $OlderThan | Where-Object {$null -eq $_.Parent}
                Write-Debug "[FUNCTION: Remove-UaaSnapshots] Snapshot Count: $($Snapshots.Count)"
                $RemovedSnapshots = Remove-UaaSnapshotsHelper($Snapshots, $RemoveChildren)
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

    if ($EmailNotification -and ($null -ne $RemovedSnapshots))
    {
        $EmailBody = $RemovedSnapshots | ConvertTo-Html -Head $css -PreContent "Below is a summary of the snapshots that were removed from vCenter during script execution:<br /><br />" -PostContent "<br />File Name: $($MyInvocation.MyCommand). <br />Execution completed at $(Get-Date)" | Out-String
        Send-MailMessage -To 'jmzetterman@alaska.edu' -From 'NoReply@uaa.alaska.edu' -Subject 'vCenter Snapshot Removal Summary' -Body $EmailBody -BodyAsHtml -SmtpServer 'aspam-out.uaa.alaska.edu'
    }
    else
    {
        $EmailBody = $RemovedSnapshots | ConvertTo-Html -PreContent "There were no snapshots detected.<br /><br />" -PostContent "<br />File Name: $($MyInvocation.MyCommand). <br />Execution completed at $(Get-Date)" | Out-String
        Send-MailMessage -To 'jmzetterman@alaska.edu' -From 'NoReply@uaa.alaska.edu' -Subject 'vCenter Snapshot Removal Summary' -Body $EmailBody -BodyAsHtml -SmtpServer 'aspam-out.uaa.alaska.edu'
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

function Remove-UaaSnapshotsHelper {
    [CmdletBinding(DefaultParameterSetName="default", SupportsShouldProcess=$True)]

    Param
    (
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true, ParameterSetName="default")]
        [PSObject[]]$Snapshots,

        [Parameter(Mandatory=$false, Position=1, ParameterSetName="default")]
        [bool]$RemoveChildren
    )

    Write-Debug "[FUNCTION: Remove-UaaSnapshotsHelper] Snapshot Count: $($Snapshots.Count)"
    Write-Debug "[FUNCTION: Remove-UaaSnapshotsHelper] Iterating through snapshots:"
    
    $RemovedSnapshots = @()
    ForEach ($Snapshot in $Snapshots)
    {
        Write-Debug "[FUNCTION: Remove-UaaSnapshotsHelper] Snapshot: $($Snapshot)"
        Write-Debug "Snapshot Properties: $($Snapshot | Get-Member -MemberType Properties)"
        # Set up object for reporting purposes
        $RemovedObjectList = New-Object psobject
        $RemovedObjectList | Add-Member -MemberType NoteProperty -Name VirtualMachine -Value $Snapshot.VirtualMachine
        $RemovedObjectList | Add-Member -MemberType NoteProperty -Name SnapshotName -Value $Snapshot.SnapshotName

        if ($RemoveChildren) {
            $RemovedObjectList | Add-Member -MemberType NoteProperty -Name ChildSnapshots -Value $true
        } else {
            $RemovedObjectList | Add-Member -MemberType NoteProperty -Name ChildSnapshots -Value $false
        }

        Write-Debug "VM Name: $($Snapshot.VirtualMachine)"
        Write-Debug "Snapshot Name: $($Snapshot.SnapshotName)"
        Write-Debug "Child Snapshots: ${RemoveChildren}"

        # Remove the snapshots
        if($RemoveChildren)
        {
            Write-Debug "Removing $($Snapshot.SnapshotName) from $($Snapshot.VirtualMachine)."
            $Snapshot.Snapshot | Remove-Snapshot -RemoveChildren -Confirm:$false
        }
        else {
            Write-Debug "Removing $($Snapshot.SnapshotName) from $($Snapshot.VirtualMachine)."
            Remove-Snapshot $Snapshot.Snapshot -Confirm:$false
        }

        $RemovedSnapshots += $RemovedObjectList

        return $RemovedSnapshots
    }
}

function New-SnapshotObject($Snapshots) {
    Write-Debug "[FUNCTION: New-SnapshotObject] Snapshot Count: $($Snapshots.Count)"
    $DiscoveredSnapshots = @()

    ForEach ($Snapshot in $Snapshots)
    {
        # $DiscoveredObjectList = New-Object psobject
        # $DiscoveredObjectList | Add-Member -MemberType NoteProperty -Name VirtualMachine -Value $Snapshot.VM
        # $DiscoveredObjectList | Add-Member -MemberType NoteProperty -Name SnapshotName -Value $Snapshot.Name
        # $DiscoveredObjectList | Add-Member -MemberType NoteProperty -Name Created -Value $Snapshot.Created
        # $DiscoveredObjectList | Add-Member -MemberType NoteProperty -Name SizeGB -Value $Snapshot.SizeGB
        # $DiscoveredObjectList | Add-Member -MemberType NoteProperty -Name Snapshot -Value $Snapshot
        # $DiscoveredSnapshots += $DiscoveredObjectList
        $DiscoveredObjectList = [PSCustomObject]@{
            VirtualMachine = $Snapshot.VM.Name
            SnapshotName   = $Snapshot.Name
            Created        = $Snapshot.Created
            SizeGB         = $Snapshot.SizeGB
            Snapshot       = $Snapshot
        }
        Write-Debug "[FUNCTION: New-SnapshotObject] Snapshot Property Type: $($DiscoveredObjectList.Snapshot.GetType().FullName)"
        Write-Debug "[FUNCTION: New-SnapshotObject] Snapshot Property Value: $($DiscoveredObjectList.Snapshot)"
        $DiscoveredSnapshots += $DiscoveredObjectList
    }

    Write-Debug "[FUNCTION: New-SnapshotObject] Snapshot Contents: $($DiscoveredSnapshots)"
    return $DiscoveredSnapshots
}