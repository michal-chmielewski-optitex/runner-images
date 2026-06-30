################################################################################
##  File:  Configure-UiTests-ChromePolicy.ps1
##  Desc:  Suppress Chrome first-run / sign-in prompts for portable UI test Chrome
################################################################################

function Set-UiTestsChromeRegistryPolicy {
    param([string]$PolicyRoot)

    $chromePolicyPath = Join-Path $PolicyRoot 'Google\Chrome'
    if (-not (Test-Path $chromePolicyPath)) {
        New-Item -Path $chromePolicyPath -Force | Out-Null
    }

    $policies = @{
        FirstRunDefaultBrowserPromptEnabled = 0
        BrowserSignin                       = 0
        SyncDisabled                        = 1
        DefaultBrowserSettingEnabled        = 0
        PromotionalTabsEnabled              = 0
        BackgroundModeEnabled               = 0
        ChromeCleanupEnabled                = 0
        MetricsReportingEnabled             = 0
        SearchSuggestEnabled                = 0
        AutofillCreditCardEnabled           = 0
    }

    foreach ($entry in $policies.GetEnumerator()) {
        New-ItemProperty -Path $chromePolicyPath -Name $entry.Key -PropertyType DWORD -Value $entry.Value -Force | Out-Null
    }
}

Set-UiTestsChromeRegistryPolicy -PolicyRoot 'HKLM:\SOFTWARE\Policies'
Set-UiTestsChromeRegistryPolicy -PolicyRoot 'HKLM:\SOFTWARE\WOW6432Node\Policies'

$chromeDir = if ($env:UITESTS_CHROME_PATH) {
    Split-Path $env:UITESTS_CHROME_PATH -Parent
} else {
    'D:\WebDriver\chrome-win64'
}

if (-not (Test-Path $chromeDir)) {
    Write-Host "Chrome directory not found at $chromeDir; skipping initial_preferences."
    return
}

$initialPreferences = @{
    distribution = @{
        skip_first_run_ui     = $true
        show_welcome_page     = $false
        import_search_engine  = $false
        import_history        = $false
        make_chrome_default   = $false
        suppress_first_run_default_browser_prompt = $true
    }
    browser = @{
        check_default_browser = $false
    }
    first_run_tabs = @()
}

$preferencesPath = Join-Path $chromeDir 'initial_preferences'
$initialPreferences | ConvertTo-Json -Depth 5 | Set-Content -Path $preferencesPath -Encoding UTF8 -Force
Write-Host "Wrote Chrome initial_preferences to $preferencesPath"
