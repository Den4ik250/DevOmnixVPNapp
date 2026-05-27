# Патч для installed_apps: фикс определения системных приложений
# YouTube и другие предустановленные приложения (FLAG_UPDATED_SYSTEM_APP)
# должны показываться в списке прокси даже при включённом "Скрыть системные приложения"

$pubCacheGit = "$env:LOCALAPPDATA\Pub\Cache\git"
$pluginFile = Get-ChildItem -Recurse -Path $pubCacheGit -Filter "InstalledAppsPlugin.kt" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -like "*installed_apps*" } |
    Select-Object -First 1

if (-not $pluginFile) {
    Write-Error "InstalledAppsPlugin.kt не найден. Запусти сначала: flutter pub get"
    exit 1
}

$path = $pluginFile.FullName
$content = Get-Content $path -Raw

$old = '(appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0'
$new = @'
val isSystem = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0
            // YouTube и другие пред-установленные приложения имеют FLAG_SYSTEM,
            // но также FLAG_UPDATED_SYSTEM_APP — их надо показывать как пользовательские.
            val isUpdatedByUser = (appInfo.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0
            isSystem && !isUpdatedByUser
'@

if ($content -notlike "*FLAG_UPDATED_SYSTEM_APP*") {
    $content = $content -replace [regex]::Escape($old), $new
    Set-Content -Path $path -Value $content -NoNewline
    Write-Host "✅ Патч применён: $path" -ForegroundColor Green
    Write-Host "   Теперь YouTube и подобные приложения будут видны в списке прокси." -ForegroundColor Cyan
} else {
    Write-Host "ℹ️  Патч уже применён: $path" -ForegroundColor Yellow
}
