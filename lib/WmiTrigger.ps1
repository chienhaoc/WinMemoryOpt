function Register-MemoryWmiEvent {
    param (
        [int]$ThresholdPercent,
        [scriptblock]$Action
    )
    
    # Unregister existing event subscription
    Unregister-MemoryWmiEvent
    
    $os = Get-CimInstance Win32_OperatingSystem
    $totalMemoryKB = $os.TotalVisibleMemorySize
    $thresholdMemoryKB = [Math]::Round($totalMemoryKB * (100 - $ThresholdPercent) / 100)
    
    # WQL query to detect when free physical memory falls below the threshold KB value
    $query = "SELECT * FROM __InstanceModificationEvent WITHIN 5 WHERE TargetInstance ISA 'Win32_OperatingSystem' AND TargetInstance.FreePhysicalMemory < $thresholdMemoryKB"
    
    # Register the CIM indication event
    Register-CimIndicationEvent -Query $query -SourceIdentifier "MemoryThresholdEvent" -Action $Action
    Write-OptLog "INFO" "Registered WMI Event Trigger. Threshold: $ThresholdPercent% (Free memory < $thresholdMemoryKB KB)"
}

function Unregister-MemoryWmiEvent {
    $sub = Get-EventSubscriber -SourceIdentifier "MemoryThresholdEvent" -ErrorAction SilentlyContinue
    if ($sub) {
        Unregister-Event -SourceIdentifier "MemoryThresholdEvent" -ErrorAction SilentlyContinue
        Write-OptLog "INFO" "Unregistered WMI Event Trigger."
    }
}





