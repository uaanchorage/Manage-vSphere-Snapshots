<#
    Created By: John Zetterman
    Last Modified: 6/12/2019
#>

Function Get-UAASnapshots {
    [CmdletBinding(DefaultParameterSetName="default")]

    Param (
        [Parameter(Mandatory=$false, Position=0, ParameterSetName="default")]
        [string]$Datacenter,
        
        [Parameter(Mandatory=$true, Position=0, ParameterSetName="Specific VM")]
        [Parameter(Mandatory=$true, Position=0, ParameterSetName="Specific Snapshot")]
        [string[]]$VirtualMachine,

        [Parameter(Mandatory=$true, Position=1, ParameterSetName="Specific Snapshot")]
        [string]$Name,

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
            Write-Debug "Processing Snapshot: $Name"
            $Snapshots = Get-Snapshot -VM $VirtualMachine -Name $Name | Where-Object {$_.Created -lt (Get-Date).AddDays(-$OlderThan)}
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

    VMware.VimAutomation.ViCore.Impl.V1.VM.SnapshotImpl. Get-UAASnapshots returns a custom
    VMware object containing the results of the function.

    .EXAMPLE

    PS> Get-UAASnapshots -Datacenter 'Anchorage Datacenter' -OlderThan 2 | Select VM, Name, Created

    VM                              Name                                             Created
    --                              ----                                             -------
    AR-TEST                         AR-TEST_vm-117097_1                              5/21/2019 11:36:48 AM
    anc-licensing04                 VM Snapshot 1%252f4%252f2019, 10:15:38 AM        1/4/2019 10:15:54 AM 
    Arctic                          Before License Manager                           6/5/2017 6:57:46 AM

    .EXAMPLE

    PS> Get-UAASnapshots -Name AR-TEST | Select VM, Name, Created                                  

    VM      Name                Created
    --      ----                -------
    AR-TEST AR-TEST_vm-117097_1 5/21/2019 11:36:48 AM

    .LINK

    https://github.com/uaanchorage/Manage-vSphere-Snapshots

    #>
}

Function Remove-UAASnapshots {
    [CmdletBinding(DefaultParameterSetName="default", SupportsShouldProcess=$True)]

    Param (
        [Parameter(Mandatory=$false, Position=0, ParameterSetName="default")]
        [string]$Datacenter,

        [Parameter(Mandatory=$true, Position=0, ParameterSetName="Specific VM")]
        [Parameter(Mandatory=$true, Position=0, ParameterSetName="Specific Snapshot")]
        [string]$VirtualMachine,

        [Parameter(Mandatory=$true, Position=1, ParameterSetName="Specific Snapshot")]
        [string]$Name,
        
        [Parameter(Mandatory=$false, Position=1, ParameterSetName="default")]
        [Parameter(Mandatory=$false, Position=1, ParameterSetName="Specific VM")]
        [int]$OlderThan = 0,
        
        [Parameter(Mandatory=$false, Position=2, ParameterSetName="default")]
        [Parameter(Mandatory=$false, Position=2, ParameterSetName="Specific VM")]
        [switch]$RemoveChildren
    )

    Write-Debug "Using ParameterSetName: $($PSCmdlet.ParameterSetName)"

    $RemovedSnapshots = @()

    switch ($PSCmdlet.ParameterSetName) 
    {
        "Specific VM"
        {
            if ($RemoveChildren)
            {
                $Snapshots = Get-UAASnapshots -Name $VirtualMachine -OlderThan $OlderThan | Where-Object {$null -eq $_.Parent}
                ForEach ($Snapshot in $Snapshots)
                {
                    $RemovedObjectList = New-Object psobject
                    $RemovedObjectList | Add-Member -MemberType NoteProperty -Name VM -Value $VirtualMachine
                    $RemovedObjectList | Add-Member -MemberType NoteProperty -Name Name -Value $Snapshot.Name
                    $RemovedObjectList | Add-Member -MemberType NoteProperty -Name ChildSnapshots -Value $true
                    Write-Debug "VM Name: $($Snapshot.VM)"
                    Write-Debug "Snapshot Name: $($Snapshot.Name)"
                    Write-Debug "Child Snapshots: Yes"
                    $Snapshot | Remove-Snapshot -RemoveChildren -Confirm:$false

                    $RemovedSnapshots += $RemovedObjectList
                }
            }
            else
            {
                $Snapshots = Get-UAASnapshots -Name $VirtualMachine -OlderThan $OlderThan | Where-Object {$null -eq $_.Parent}
                ForEach ($Snapshot in $Snapshots) 
                {
                    $RemovedObjectList = New-Object psobject
                    $RemovedObjectList | Add-Member -MemberType NoteProperty -Name VM -Value $VirtualMachine
                    $RemovedObjectList | Add-Member -MemberType NoteProperty -Name Name -Value $Snapshot.Name
                    $RemovedObjectList | Add-Member -MemberType NoteProperty -Name ChildSnapshots -Value $false
                    Write-Debug "VM Name: $($Snapshot.VM)"
                    Write-Debug "Snapshot Name: $($Snapshot.Name)"
                    Write-Debug "Child Snapshots: No"
                    $Snapshot | Remove-Snapshot -Confirm:$false

                    $RemovedSnapshots += $RemovedObjectList
                }
            }
        }

        "Specific Snapshot"
        {
            $Snapshot = Get-UAASnapshots -VM $VirtualMachine -Name $Name
            $RemovedObjectList = New-Object psobject
            $RemovedObjectList | Add-Member -MemberType NoteProperty -Name VM -Value $Snapshot.VM
            $RemovedObjectList | Add-Member -MemberType NoteProperty -Name Name -Value $Snapshot.Name
            $RemovedObjectList | Add-Member -MemberType NoteProperty -Name ChildSnapshots -Value $false
            Write-Debug "VM Name: $($Snapshot.VM)"
            Write-Debug "Snapshot Name: $($Snapshot.Name)"
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
                    $RemovedObjectList | Add-Member -MemberType NoteProperty -Name VM -Value $Snapshot.VM
                    $RemovedObjectList | Add-Member -MemberType NoteProperty -Name Name -Value $Snapshot.Name
                    $RemovedObjectList | Add-Member -MemberType NoteProperty -Name ChildSnapshots -Value $true
                    $RemovedObjectList | Add-Member -MemberType NoteProperty -Name Created -Value $Snapshot.Created
                    Write-Debug "VM Name: $($Snapshot.VM)"
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
                    $RemovedObjectList | Add-Member -MemberType NoteProperty -Name VM -Value $Snapshot.VM
                    $RemovedObjectList | Add-Member -MemberType NoteProperty -Name Name -Value $Snapshot.Name
                    $RemovedObjectList | Add-Member -MemberType NoteProperty -Name ChildSnapshots -Value $false
                    Write-Debug "VM Name: $($Snapshot.VM)"
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
                    $RemovedObjectList | Add-Member -MemberType NoteProperty -Name VM -Value $Snapshot.VM
                    $RemovedObjectList | Add-Member -MemberType NoteProperty -Name Name -Value $Snapshot.Name
                    $RemovedObjectList | Add-Member -MemberType NoteProperty -Name ChildSnapshots -Value $true
                    Write-Debug "VM Name: $($Snapshot.VM)"
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
                    $RemovedObjectList | Add-Member -MemberType NoteProperty -Name VM -Value $Snapshot.VM
                    $RemovedObjectList | Add-Member -MemberType NoteProperty -Name Name -Value $Snapshot.Name
                    $RemovedObjectList | Add-Member -MemberType NoteProperty -Name ChildSnapshots -Value $false
                    Write-Debug "VM Name: $($Snapshot.VM)"
                    Write-Debug "Snapshot Name: $($Snapshot.Name)"
                    Write-Debug "Child Snapshots: No"
                    $Snapshot | Remove-Snapshot -Confirm:$false

                    $RemovedSnapshots += $RemovedObjectList
                }
            }
        }
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

    PS C:\Users\jmzetterman.UA\Documents\OneDrive Personal\OneDrive\UAAGit> Remove-UAASnapshots -VM AR-TEST -Name AR-TEST_vm-117097_1

    Name                           State      % Complete Start Time   Finish Time
    ----                           -----      ---------- ----------   -----------
    RemoveSnapshot_Task            Completed         100 10:32:27 AM  10:32:40 AM

    .EXAMPLE

    PS> Remove-UAASnapshots -Name AR-TEST                           

    VM      Name                Created
    --      ----                -------
    AR-TEST AR-TEST_vm-117097_1 5/21/2019 11:36:48 AM

    .LINK

    https://github.com/uaanchorage/Manage-vSphere-Snapshots

    #>
}