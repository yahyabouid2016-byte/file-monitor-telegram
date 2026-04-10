# ============================================
# FileWatcher.ps1 - Real-Time File Monitor
# Monitors file events on shared folder and
# sends alerts via n8n webhook to Telegram
# ============================================

$folder = "C:\your-TARGET"
$url = "YOUR_N8N_WEBHOOK_URL"

$fsw = New-Object IO.FileSystemWatcher $folder
$fsw.IncludeSubdirectories = $true
$fsw.EnableRaisingEvents = $true

$action = {
    $path = $Event.SourceEventArgs.FullPath
    $type = $Event.SourceEventArgs.ChangeType
    $time = Get-Date -Format "HH:mm:ss"

    $smbUser = Get-SmbOpenFile | Where-Object {
        $path -like "*$($_.Path.Replace(':', ''))*"
    } | Select-Object -ExpandProperty ClientUserName -ErrorAction SilentlyContinue

    if (-not $smbUser) { $smbUser = "Utilisateur Réseau Inconnu" }

    $body = @{
        utilisateur = "L'utilisateur: $smbUser"
        fichier     = "Fichier: $path"
        evenement   = "Action: $type à $time"
    }

    Invoke-RestMethod -Uri $url -Method Post -Body ($body | ConvertTo-Json) -ContentType "application/json"
}

Register-ObjectEvent $fsw -EventName "Created" -Action $action
Register-ObjectEvent $fsw -EventName "Deleted" -Action $action
Register-ObjectEvent $fsw -EventName "Changed" -Action $action
Register-ObjectEvent $fsw -EventName "Renamed" -Action $action

Write-Host "Monitoring Global en cours sur $folder 
while ($true) { Start-Sleep 1 }
