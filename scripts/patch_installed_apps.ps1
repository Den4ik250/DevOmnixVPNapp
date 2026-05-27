$pubCache = "$env:LOCALAPPDATA\Pub\Cache\hosted\pub.dev"
$pluginDir = Get-ChildItem $pubCache -Directory | Where-Object { $_.Name -like "installed_apps-*" } | Select-Object -First 1

if ($pluginDir) {
    $filePath = Join-Path $pluginDir.FullName "android\src\main\java\io\sethings\installedapps\InstalledAppsPlugin.java"
    if (Test-Path $filePath) {
        $content = Get-Content $filePath -Raw
        $old = 'if ((appInfo.flags & ApplicationInfo.FLAG_SYSTEM) != 0)'
        $new = 'if ((appInfo.flags & ApplicationInfo.FLAG_SYSTEM) != 0 && (appInfo.flags & ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) == 0)'
        if ($content -match [regex]::Escape($old)) {
            $content = $content -replace [regex]::Escape($old), $new
            Set-Content $filePath $content -NoNewline
            Write-Host "Patch applied: $filePath" -ForegroundColor Green
        } else {
            Write-Host "Already patched or pattern not found" -ForegroundColor Yellow
        }
    } else {
        Write-Host "File not found: $filePath" -ForegroundColor Red
    }
} else {
    Write-Host "installed_apps package not found in pub cache" -ForegroundColor Red
}