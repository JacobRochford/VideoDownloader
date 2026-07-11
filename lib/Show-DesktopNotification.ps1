function Show-DesktopNotification {
    param(
        [string]$Title,
        [string]$Message,
        [ValidateSet('Info','Warning','Error')][string]$Type = 'Info'
    )
    Add-Type -AssemblyName System.Windows.Forms
    $notify = New-Object System.Windows.Forms.NotifyIcon
    $notify.Icon = [System.Drawing.SystemIcons]::Information
    switch ($Type) {
        'Warning' { $notify.Icon = [System.Drawing.SystemIcons]::Warning }
        'Error'   { $notify.Icon = [System.Drawing.SystemIcons]::Error }
    }
    $notify.BalloonTipTitle = $Title
    $notify.BalloonTipText  = $Message
    $notify.Visible = $true
    $notify.ShowBalloonTip(5000)
    Start-Sleep -Seconds 6
    $notify.Dispose()
}
