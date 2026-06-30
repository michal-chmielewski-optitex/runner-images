Describe "UiTests WebDrivers" {
    It "chrome.exe exists at D:\WebDriver\chrome-win64" {
        'D:\WebDriver\chrome-win64\chrome.exe' | Should -Exist
    }

    It "chromedriver.exe exists at D:\WebDriver\chromedriver-win64" {
        'D:\WebDriver\chromedriver-win64\chromedriver.exe' | Should -Exist
    }

    It "chromedriver is on PATH" {
        "chromedriver.exe --version" | Should -ReturnZeroExitCode
    }

    It "ChromeWebDriver environment variable points to chromedriver folder" {
        $env:ChromeWebDriver | Should -BeExactly 'D:\WebDriver\chromedriver-win64'
        $env:ChromeWebDriver | Should -Exist
    }

    It "Chrome initial_preferences suppresses first-run UI" {
        $preferencesPath = 'D:\WebDriver\chrome-win64\initial_preferences'
        $preferencesPath | Should -Exist
        $preferences = Get-Content $preferencesPath -Raw | ConvertFrom-Json
        $preferences.distribution.skip_first_run_ui | Should -BeTrue
    }

    It "Chrome enterprise policy disables first-run default browser prompt" {
        $path = 'HKLM:\SOFTWARE\Policies\Google\Chrome'
        (Get-ItemProperty -Path $path).FirstRunDefaultBrowserPromptEnabled | Should -Be 0
    }
}
