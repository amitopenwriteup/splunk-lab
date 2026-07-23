# Copyright Splunk Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# The following comment block acts as usage for powershell scripts
# you can view it by passing the script as an argument to the cmdlet 'Get-Help'
# To view the parameter documentation invoke Get-Help with the option '-Detailed'
# ex. PS C:\> Get-Help "<path to script>\install.ps1" -Detailed

<#
.SYNOPSIS
    Installs or uninstalls the Splunk OpenTelemetry Collector.
.DESCRIPTION
    Installs or uninstalls the Splunk OpenTelemetry Collector. If access_token is not
    provided, it will be prompted for on the console. Use uninstall_collector to remove the collector. 
    If you want to view full documentation execute Get-Help with the parameter "-Full".
.PARAMETER access_token
    The token used to send metric data to Splunk.
    .EXAMPLE
    .\install.ps1 -access_token "ACCESSTOKEN"
.PARAMETER realm
    (OPTIONAL) The Splunk realm to use (default: "us0"). The ingest, API, and HEC endpoint URLs will automatically be inferred by this value.
    .EXAMPLE
    .\install.ps1 -access_token "ACCESSTOKEN" -realm "us1"
.PARAMETER memory
    (OPTIONAL) Total memory in MIB to allocate to the collector; automatically calculates the ballast size (default: "512").
    .EXAMPLE
    .\install.ps1 -access_token "ACCESSTOKEN" -memory 1024
.PARAMETER mode
    (OPTIONAL) Configure the collector service to run in "agent" or "gateway" mode (default: "agent").
    .EXAMPLE
    .\install.ps1 -access_token "ACCESSTOKEN" -mode "gateway"
.PARAMETER network_interface
    (OPTIONAL) The network interface the collector receivers listen on. (default: "127.0.0.1" for agent mode and "0.0.0.0" otherwise)
    .EXAMPLE
    .\install.ps1 -access_token "ACCESSTOKEN" -network_interface "127.0.0.1"
.PARAMETER ingest_url
    (OPTIONAL) Set the base ingest URL explicitly instead of the URL inferred from the specified realm (default: https://ingest.REALM.observability.splunkcloud.com).
    .EXAMPLE
    .\install.ps1 -access_token "ACCESSTOKEN" -ingest_url "https://ingest.us1.observability.splunkcloud.com"
.PARAMETER api_url
    (OPTIONAL) Set the base API URL explicitly instead of the URL inferred from the specified realm (default: https://api.REALM.observability.splunkcloud.com).
    .EXAMPLE
    .\install.ps1 -access_token "ACCESSTOKEN" -api_url "https://api.us1.observability.splunkcloud.com"
.PARAMETER hec_url
    (DEPRECATED) Set the HEC endpoint URL explicitly instead of the endpoint inferred from the specified realm (default: https://ingest.REALM.observability.splunkcloud.com/v1/log).
    .EXAMPLE
    .\install.ps1 -access_token "ACCESSTOKEN" -hec_url "https://ingest.us1.observability.splunkcloud.com/v1/log"
.PARAMETER hec_token
    (OPTIONAL) Set the HEC token if different than the specified Splunk access_token.
    .EXAMPLE
    .\install.ps1 -access_token "ACCESSTOKEN" -hec_token "HECTOKEN"
.PARAMETER godebug
    (OPTIONAL) Set values for the GODEBUG environment variable.
    .EXAMPLE
    .\install.ps1 -access_token "ACCESSTOKEN" -godebug "fips140=on"
.PARAMETER with_dotnet_instrumentation
    (OPTIONAL) Whether to install and configure the Splunk Distribution of OpenTelemetry .NET to forward .NET application telemetry to the local collector (default: $false).
    .EXAMPLE
    .\install.ps1 -access_token "ACCESSTOKEN" -with_dotnet_instrumentation $true
.PARAMETER deployment_env
    (OPTIONAL) A system-wide "deployment.environment" set via the environment variable 'OTEL_RESOURCE_ATTRIBUTES' for the whole machine. Ignored if -with_dotnet_instrumentation is false.
    .EXAMPLE
    .\install.ps1 -access_token "ACCESSTOKEN" -with_dotnet_instrumentation $true -deployment_env staging
.PARAMETER insecure
    (OPTIONAL) If true then certificates will not be checked when downloading resources. Defaults to '$false'.
    .EXAMPLE
    .\install.ps1 -access_token "ACCESSTOKEN" -insecure $true
.PARAMETER collector_version
    (OPTIONAL) Specify a specific version of the collector to install.  Defaults to the latest version available.
    .EXAMPLE
    .\install.ps1 -access_token "ACCESSTOKEN" -collector_version "1.2.3"
.PARAMETER stage
    (OPTIONAL) The package stage to install from ['test', 'beta', 'release']. Defaults to 'release'.
    .EXAMPLE
    .\install.ps1 -access_token "ACCESSTOKEN" -stage "test"
.PARAMETER collector_msi_url
    (OPTIONAL) Specify the URL to the Splunk OpenTelemetry Collector MSI package to install (default: "https://dl.observability.splunkcloud.com/splunk-otel-collector/msi/release/splunk-otel-collector-<version>-amd64.msi")
    If specified, the -collector_version and -stage parameters will be ignored.
    .EXAMPLE
    .\install.ps1 -access_token "ACCESSTOKEN" -collector_msi_url https://my.host/splunk-otel-collector-1.2.3-amd64.msi
.PARAMETER msi_path
    (OPTIONAL) Specify a local path to a Splunk OpenTelemetry Collector MSI package to install instead of downloading the package.
    If specified, the -collector_version and -stage parameters will be ignored.
    .EXAMPLE
    .\install.ps1 -access_token "ACCESSTOKEN" -msi_path "C:\SOME_FOLDER\splunk-otel-collector-1.2.3-amd64.msi"
.PARAMETER dotnet_psm1_path
    (OPTIONAL) Specify a local path to a Splunk OpenTelemetry .NET Auto Instrumentation Powershell Module file (.psm1) instead of downloading the package. This module will be used to install the .NET auto instrumentation files. The most current PSM1 file can be downloaded at https://github.com/signalfx/splunk-otel-dotnet/releases
    .EXAMPLE
    .\install.ps1 -access_token "ACCESSTOKEN" -dotnet_psm1_path "C:\SOME_FOLDER\Splunk.OTel.DotNet.psm1"
.PARAMETER dotnet_auto_zip_path
    (OPTIONAL) Specify a local path to a Splunk OpenTelemetry .NET Auto Instrumentation zip package that will be installed by the dotnet psm1 module instead of downloading the package.  The most current zip file can be downloaded at https://github.com/signalfx/splunk-otel-dotnet/releases
    .EXAMPLE
    .\install.ps1 -access_token "ACCESSTOKEN" -dotnet_auto_zip_path "C:\SOME_FOLDER\splunk-otel-dotnet-1.2.3-amd64.zip"
.PARAMETER force_skip_verify_access_token
    (OPTIONAL) Forces the skipping the verification check of the Splunk Observability Access Token regardless of what is in the env variable VERIFY_ACCESS_TOKEN.  This is helpful on new installs where access might be an issue or the token isn't created yet.
    .EXAMPLE
    .\install.ps1 -access_token "ACCESSTOKEN" -force_skip_verify_access_token $true
.PARAMETER msi_public_properties
    (OPTIONAL) Specify public MSI properties to be used when installing the Splunk OpenTelemetry Collector MSI package.
    For information about the public MSI properties see https://learn.microsoft.com/en-us/windows/win32/msi/property-reference#configuration-properties
    .EXAMPLE
    .\install.ps1 -access_token "ACCESSTOKEN" -msi_public_properties "ARPCOMMENTS=DO_NOT_UNINSTALL" 
.PARAMETER config_path
    (OPTIONAL) Specify a local path to an alternative configuration file for the Splunk OpenTelemetry Collector.
    If specified, the -mode parameter will be ignored.
    .EXAMPLE
    .\install.ps1 -config_path "C:\SOME_FOLDER\my_config.yaml"
.PARAMETER preserve_prev_default_config
   (OPTIONAL) Preserve the default configuration files, located at `$Env:ProgramData\Splunk\OpenTelemetry Collector`, of previous version when upgrading the collector. By default it is $false since version changes can include breaking configuration changes.
   .EXAMPLE
    .\install.ps1 -preserve_prev_default_config $true
.PARAMETER uninstall_collector
    (OPTIONAL) Uninstalls the Splunk OpenTelemetry Collector if it is already installed and then exits the script.
    .EXAMPLE
    .\install.ps1 -uninstall_collector
#>

[CmdletBinding(DefaultParameterSetName = "Install")]
param(
    [Parameter(ParameterSetName = "Uninstall", Mandatory = $false)]
    [switch]$uninstall_collector,

    [Parameter(ParameterSetName = "Install", Mandatory = $true)]
    [string]$access_token = "",

    [string]$realm = "us0",
    [string]$memory = "512",
    [ValidateSet('agent', 'gateway')][string]$mode = "agent",
    [string]$network_interface = "",
    [string]$ingest_url = "",
    [string]$api_url = "",
    [string]$hec_url = "",
    [string]$hec_token = "",
    [string]$godebug = "",
    [bool]$insecure = $false,
    [string]$collector_version = "",
    [bool]$with_dotnet_instrumentation = $false,
    [ValidateSet('test', 'beta', 'release')][string]$stage = "release",
    [string]$msi_path = "",
    [string]$msi_public_properties = "",
    [string]$config_path = "",
    [bool]$preserve_prev_default_config = $false,
    [string]$collector_msi_url = "",
    [string]$dotnet_psm1_path = "",
    [string]$dotnet_auto_zip_path = "",
    [bool]$force_skip_verify_access_token = $false,
    [string]$deployment_env = "",
    [bool]$UNIT_TEST = $false
)

New-Variable -Name UninstallWildcardRegPath  -Option Constant -Value "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
New-Variable -Name CollectorServiceDisplayName -Option Constant -Value "Splunk OpenTelemetry Collector"
$archFromEnv = $env:PROCESSOR_ARCHITECTURE
$arch = ""
if ($archFromEnv -eq "ARM64") {
    $arch = "arm64"
}
elseif ($archFromEnv -eq "AMD64") {
    $arch = "amd64"
}
else {
    throw "Unsupported architecture '$archFromEnv' only ARM64 and AMD64 are supported, run this script from the native architecture PowerShell."
}
$format = "msi"
$service_name = "splunk-otel-collector"
$signalfx_dl = "https://dl.observability.splunkcloud.com"
try {
    Resolve-Path $env:PROGRAMFILES 2>&1>$null
    $installation_path = "${env:PROGRAMFILES}\Splunk\OpenTelemetry Collector"
}
catch {
    $installation_path = "\Program Files\Splunk\OpenTelemetry Collector"
}
try {
    Resolve-Path $env:PROGRAMDATA 2>&1>$null
    $program_data_path = "${env:PROGRAMDATA}\Splunk\OpenTelemetry Collector"
}
catch {
    $program_data_path = "\ProgramData\Splunk\OpenTelemetry Collector"
}
$old_config_path = "$program_data_path\config.yaml"
$agent_config_path = "$program_data_path\agent_config.yaml"
$gateway_config_path = "$program_data_path\gateway_config.yaml"

try {
    Resolve-Path $env:TEMP 2>&1>$null
    $tempdir = "${env:TEMP}\Splunk\OpenTelemetry Collector"
}
catch {
    $tempdir = "\tmp\Splunk\OpenTelemetry Collector"
}

# check that we're not running with a restricted execution policy
function check_policy() {
    $executionPolicy = (Get-ExecutionPolicy)
    $executionRestricted = ($executionPolicy -eq "Restricted")
    if ($executionRestricted) {
        throw @"
You can't import or run scripts with execution policy $executionPolicy.
Change your execution policy to RemoteSigned or similar:
        PS> Set-ExecutionPolicy RemoteSigned
For more information, run the following command:
        PS> Get-Help about_execution_policies
"@
    }
}

# check if running as administrator
function check_if_admin() {
    $identity = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    if (-NOT $identity.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        return $false
    }
    return $true
}

# get latest package tag given a stage and format
function get_latest([string]$stage = $stage, [string]$format = $format) {
    $latest_url = "$signalfx_dl/splunk-otel-collector/$format/$stage/latest.txt"
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $latest = (New-Object System.Net.WebClient).DownloadString($latest_url).Trim()
    }
    catch {
        $err = $_.Exception.Message
        $message = "
        An error occurred while fetching the latest package version $latest_url
        $err
        "
        throw "$message"
    }
    return $latest
}

# builds the filename for the package
function get_filename([string]$tag = "", [string]$format = $format, [string]$arch = $arch) {
    $filename = "splunk-otel-collector-$tag-$arch.$format"
    return $filename
}

# builds the url for the package
function get_url([string]$stage = "", [string]$format = $format, [string]$filename = "") {
    return "$signalfx_dl/splunk-otel-collector/$format/$stage/$filename"
}

# download a file to a given destination
function download_file([string]$url, [string]$outputDir, [string]$fileName) {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        (New-Object System.Net.WebClient).DownloadFile($url, "$outputDir\$fileName")
    }
    catch {
        $err = $_.Exception.Message
        $message = "
        An error occurred while downloading $url
        $err
        "
        throw "$message"
    }
}

# ensure a file exists and raise an exception if it doesn't
function ensure_file_exists([string]$path = "C:\") {
    if (!(Test-Path -Path "$path")) {
        throw "Cannot find the path '$path'"
    }
}

# verify a Splunk access token
function verify_access_token([string]$access_token = "", [string]$ingest_url = $INGEST_URL, [bool]$insecure = $INSECURE) {
    if ($insecure) {
        # turn off certificate validation
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true } ;
    }
    $url = "$ingest_url/v2/event"
    echo $url
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $resp = Invoke-WebRequest -Uri $url -Method POST -ContentType "application/json" -Headers @{"X-Sf-Token" = "$access_token" } -Body "[]" -UseBasicParsing
    }
    catch {
        $err = $_.Exception.Message
        $message = "
        Your access token could not be verified. This may be due to a network connectivity issue or an invalid access token.
        $err
        "
        throw "$message"
    }
    if (!($resp.StatusCode -Eq 200)) {
        return $false
    }
    else {
        return $true
    }
}

# create the temp directory if it doesn't exist
function create_temp_dir($tempdir = $tempdir) {
    if ((Test-Path -Path "$tempdir")) {
        Remove-Item -Recurse -Force "$tempdir"
    }
    mkdir "$tempdir" -ErrorAction Ignore
}

function get_service_log_path([string]$name) {
    return "the Windows Event Viewer"
}

# start the service if it's not already running
function start_service([string]$name, [string]$config_path = $null, [int]$timeout = 60) {
    $svc = Get-Service -Name $name
    if ($svc.Status -eq "Running") {
        return
    }

    if (!([string]::IsNullOrEmpty($config_path)) -And !(Test-Path -Path $config_path)) {
        throw "$config_path does not exist and is required to start the $name service"
    }

    try {
        if ($svc.Status -ne "ContinuePending" -And $svc.Status -ne "StartPending") {
            $svc.Start()
        }
        $svc.WaitForStatus("Running", [TimeSpan]::FromSeconds($timeout))
    }
    catch {
        $err = $_.Exception.Message
        $log_path = get_service_log_path -name "$name"
        Write-Warning "An error occurred while trying to start the $name service:"
        Write-Warning "$err"
        Write-Warning "Please check $log_path for more details."
        throw "$err"
    }
}

# stop the service
function stop_service([string]$name, [int]$max_attempts = 3, [int]$timeout = 60) {
    $svc = Get-Service -Name "$name"
    if ($svc.Status -eq "Stopped") {
        return
    }

    try {
        $svc.Stop()
        $svc.WaitForStatus("Stopped", [TimeSpan]::FromSeconds($timeout))
    }
    catch {
        $err = $_.Exception.Message
        $log_path = get_service_log_path -name "$name"
        Write-Warning "An error occurred while trying to stop the $name service:"
        Write-Warning "$err"
        Write-Warning "Please check $log_path for more details."
        throw "$err"
    }
}

# download collector package from repo
function download_collector_package([string]$collector_version = $collector_version, [string]$tempdir = $tempdir, [string]$stage = $stage, [string]$arch = $arch, [string]$format = $format) {
    # get the filename to download
    $filename = get_filename -tag $collector_version -format $format -arch $arch

    # get url for file to download
    $fileurl = get_url -stage $stage -format $format -filename $filename
    echo "Downloading $fileName ..."
    download_file -url $fileurl -outputDir $tempdir -filename $filename
    ensure_file_exists "$tempdir\$filename"
    echo "- $fileurl -> '$tempdir'"
}

# check registry for the agent msi package
function is_msi_installed([string]$product_name) {
    return $null -ne (Get-ItemProperty $UninstallWildcardRegPath | Where { $_.DisplayName -eq $product_name })
}

function get_msi_installation_sids([string]$product_name) {
    $sids = [string[]]@()

    $uninstallEntry = Get-ItemProperty $UninstallWildcardRegPath -ErrorAction SilentlyContinue | 
    Where-Object { $_.DisplayName -eq $product_name }
    if ($uninstallEntry) {
        $userInstalls = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\*\Products\*\InstallProperties' -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -eq $product_name }
        foreach ($user in $userInstalls) {
            # Not all entries are valid user SIDS, e.g.: some are SIDs with suffixes like "_Classes"
            # We only want the SIDs.
            if ($user.PSPath -match 'UserData\\(?<SID>S-1-[0-9\-]+)') {
                $sid = $Matches['SID']
                $sids += , @($sid)
            }
        }
    }

    return $sids
}

function update_registry([string]$path, [string]$name, [string]$value) {
    echo "Updating $path for $name..."
    Set-ItemProperty -path "$path" -name "$name" -value "$value"
}

function set_service_environment([string]$service_name, [hashtable]$env_vars) {
    # Transform the $env_vars to an array of strings so the Set-ItemProperty correctly create the
    # 'Environment' REG_MULTI_SZ value.
    [string []] $multi_sz_value = ($env_vars.Keys | ForEach-Object { "$_=$($env_vars[$_])" } | Sort-Object)

    $target_service_reg_key = Join-Path "HKLM:\SYSTEM\CurrentControlSet\Services" $service_name
    if (Test-Path $target_service_reg_key) {
        Set-ItemProperty $target_service_reg_key -Name "Environment" -Value $multi_sz_value
    }
    else {
        throw "Invalid service '$service_name'. Registry key '$target_service_reg_key' doesn't exist."
    }
}

function install_msi([string]$path) {
    Write-Host "Installing $path ..."
    $startTime = Get-Date
    $proc = (Start-Process msiexec.exe -Wait -PassThru -ArgumentList "/i `"$path`" /qn /norestart $msi_public_properties")
    if ($proc.ExitCode -ne 0 -and $proc.ExitCode -ne 3010) {
        Write-Warning "The installer failed with error code $($proc.ExitCode)."
        try {
            $events = (Get-WinEvent -ProviderName "MsiInstaller" | Where-Object { $_.TimeCreated -ge $startTime })
            ForEach ($event in $events) {
                ($event | Select -ExpandProperty Message | Out-String).TrimEnd() | Write-Host
            }
        }
        catch {
            Write-Warning "Please check the Windows Event Viewer for more details."
            continue
        }
        Exit $proc.ExitCode
    }
    Write-Host "- Done"
}

function uninstall_msi([string]$product_name) {
    Write-Host "Uninstalling $product_name ..."
    $uninstall_entry = Get-ItemProperty $UninstallWildcardRegPath -ErrorAction SilentlyContinue | 
    Where-Object { $_.DisplayName -eq $product_name } | Select-Object -First 1
    if (-not $uninstall_entry) {
        throw "Failed to find the uninstall registry entry for $product_name"
    }
    $proc = (Start-Process msiexec.exe -Wait -PassThru -ArgumentList "/X `"$($uninstall_entry.PSChildName)`" /qn /norestart")
    if ($proc.ExitCode -ne 0) {
        Write-Warning "The uninstall attempt failed with error code $($proc.ExitCode)."
        Exit $proc.ExitCode
    }
    Write-Host "- Done"
}

# Remove splunk.zc.method value from OTEL_RESOURCE_ATTRIBUTES environment variable
function remove_splunk_zc_method_from_env() {
    try {
        $envVarPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment"
        $otelResourceAttrs = Get-ItemProperty -Path $envVarPath -Name "OTEL_RESOURCE_ATTRIBUTES" -ErrorAction SilentlyContinue
        
        if ($otelResourceAttrs) {
            $currentValue = $otelResourceAttrs.OTEL_RESOURCE_ATTRIBUTES
            # Remove the splunk.zc.method=splunk-otel-dotnet-* pattern from the comma-delimited list
            # This regex matches the pattern and any surrounding commas, handling edge cases
            $newValue = $currentValue -replace 'splunk\.zc\.method=splunk-otel-dotnet-[^,]*,?', '' -replace ',+$', '' -replace '^,+', '' -replace ',+', ','
            
            if ([string]::IsNullOrEmpty($newValue)) {
                # If the result is empty, remove the environment variable entirely
                Write-Host "Removing OTEL_RESOURCE_ATTRIBUTES environment variable"
                Remove-ItemProperty -Path $envVarPath -Name "OTEL_RESOURCE_ATTRIBUTES" -ErrorAction SilentlyContinue
            }
            else {
                # Update the environment variable with the new value
                Write-Host "Updating OTEL_RESOURCE_ATTRIBUTES environment variable"
                Set-ItemProperty -Path $envVarPath -Name "OTEL_RESOURCE_ATTRIBUTES" -Value $newValue
            }
        }
    }
    catch {
        Write-Warning "An error occurred while removing splunk.zc.method from OTEL_RESOURCE_ATTRIBUTES: $($_.Exception.Message)"
    }
}

$ErrorActionPreference = 'Stop'; # stop on all errors

# check administrator status
echo 'Checking if running as Administrator...'
if (!(check_if_admin)) {
    throw 'This script requires Administrator rights. Operation failed.'
}
else {
    echo '- Running as Administrator'
}

# check execution policy
echo 'Checking execution policy'
check_policy

if (-not (Get-Service -Name $service_name -ErrorAction SilentlyContinue)) {
    if ($uninstall_collector) {
        remove_splunk_zc_method_from_env
        Write-Host "The $service_name service is not installed, nothing to uninstall."
        exit 0
    }
}
else {
    if (-not $uninstall_collector) {
        Write-Host "The $service_name service is already installed. Checking installation for automatic update."
    }

    $uninstall_collector_using_msi = $true
    $collector_sids = get_msi_installation_sids -product_name $CollectorServiceDisplayName
    if ($collector_sids.Count -eq 0) {
        $uninstall_collector_using_msi = $false
        Write-Warning "The $service_name service exists but it is not on the Windows installation database."
    }
    else {
        if ($collector_sids.Count -gt 1) {
            $sids_list = $collector_sids -join ", "
            throw "The $CollectorServiceDisplayName is already installed for multiple users (SIDs: $sids_list). Uninstall the collector and remove remaining users installations from the registry."
        }

        $installationSid = $collector_sids[0]
        # "S-1-5-18" is the SID for the Local System account, which is used for machine-wide installations.
        if ("S-1-5-18" -ne $installationSid) {
            # not a machine wide installation, check if it is the same user
            $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
            $currentUserSID = $currentUser.User.Value
            if ($currentUserSID -ne $installationSid) {
                $sid = New-Object System.Security.Principal.SecurityIdentifier($installationSid)
                $user = $sid.Translate([System.Security.Principal.NTAccount])
                throw "The $CollectorServiceDisplayName was last installed by '${user.Value}' it must be updated or uninstalled by the same user." 
            }
        }
    }

    Write-Host "Stopping $service_name service..."
    stop_service -name "$service_name"
    if ($uninstall_collector_using_msi) {
        uninstall_msi -product_name $CollectorServiceDisplayName
        remove_splunk_zc_method_from_env
    }
    if (-not $preserve_prev_default_config) {
        $default_config_files = @("agent_config.yaml", "gateway_config.yaml")
        foreach ($file in $default_config_files) {
            $target = Join-Path "${Env:ProgramData}\Splunk\OpenTelemetry Collector" "$file"
            Write-Host "Deleting previous version default configuration file '$target'"
            Remove-Item -Path $target
        }
    }
}

if ($uninstall_collector) {
    Write-Host "Uninstall is done."
    exit 0
}

# create a temporary directory
$tempdir = create_temp_dir -tempdir $tempdir

if ($with_dotnet_instrumentation) {
    if ((is_msi_installed -name "SignalFx .NET Tracing 64-bit") -Or (is_msi_installed -name "SignalFx .NET Tracing 32-bit")) {
        throw "SignalFx .NET Instrumentation is already installed. Stop all instrumented applications and uninstall SignalFx Instrumentation for .NET before running this script again."
    }
    echo "Downloading Splunk Distribution of OpenTelemetry .NET ..."
    if ($dotnet_psm1_path -eq "") {
        $module_name = "Splunk.OTel.DotNet.psm1"
        $download = "https://github.com/signalfx/splunk-otel-dotnet/releases/latest/download/$module_name"
        $dotnet_autoinstr_path = Join-Path $tempdir $module_name
        echo "Downloading .NET Instrumentation installer ..."
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $download -OutFile $dotnet_autoinstr_path -UseBasicParsing
        }
        catch {
            $err = $_.Exception.Message
            $message = "
            An error occurred when trying to download .NET Instrumentation installer from $download. This may be due to a network connectivity issue.
            $err
            "
            throw "$message"
        }
        Import-Module $dotnet_autoinstr_path
    }
    else {
        $dotnet_autoinstr_path = $dotnet_psm1_path
        echo "Using Local PSM1 file and ArgumentList values: $dotnet_psm1_path -ArgumentList $dotnet_auto_zip_path"
        Import-Module $dotnet_autoinstr_path -ArgumentList $dotnet_auto_zip_path
    }
}

if ($ingest_url -eq "") {
    $ingest_url = "https://ingest.$realm.observability.splunkcloud.com"
}

if ($api_url -eq "") {
    $api_url = "https://api.$realm.observability.splunkcloud.com"
}

if ($hec_url -eq "") {
    $hec_url = "$ingest_url/v1/log"
}
else {
    Write-Warning "[DEPRECATED] The parameter '-hec_url' is deprecated and will be removed in September 2026."
}

if ($hec_token -eq "") {
    $hec_token = "$access_token"
}

if ($force_skip_verify_access_token) {
    echo 'Skipping Access Token verification'
}
else {   
    if ("$env:VERIFY_ACCESS_TOKEN" -ne "false") {
        # verify access token
        echo 'Verifying Access Token...'
        if (!(verify_access_token -access_token $access_token -ingest_url $ingest_url -insecure $insecure)) {
            throw "Access token authentication failed. Verify that your access token is correct. If your access token is valid, you can skip validation by rerunning with -force_skip_verify_access_token `$true or setting the VERIFY_ACCESS_TOKEN=false environment variable."
        }
        else {
            echo '- Verified Access Token'
        }
    }
}

if ($collector_msi_url) {
    $collector_msi_name = "splunk-otel-collector.msi"
    echo "Downloading $collector_msi_url..."
    download_file -url "$collector_msi_url" -outputDir "$tempdir" -fileName "$collector_msi_name"
    $msi_path = (Join-Path "$tempdir" "$collector_msi_name")
}
elseif ($msi_path -Eq "") {
    # determine package version to fetch
    if ($collector_version -Eq "") {
        echo 'Determining latest release...'
        $collector_version = get_latest -stage $stage -format $format
        echo "- Latest release is $collector_version"
    }

    # download the collector package with the specified collector_version or latest
    download_collector_package -collector_version $collector_version -tempdir $tempdir -stage $stage -arch $arch -format $format

    $msi_path = get_filename -tag $collector_version -format $format -arch $arch
    $msi_path = (Join-Path "$tempdir" "$msi_path")
}
else {
    $msi_path = Resolve-Path "$msi_path"
    if (!(Test-Path -Path "$msi_path")) {
        throw "$msi_path not found!"
    }
}

install_msi -path "$msi_path"

# copy the default configs to $program_data_path
mkdir "$program_data_path" -ErrorAction Ignore
if (!(Test-Path -Path "$agent_config_path") -And (Test-Path -Path "$installation_path\agent_config.yaml")) {
    echo "$agent_config_path not found"
    echo "Copying default agent_config.yaml to $agent_config_path"
    Copy-Item "$installation_path\agent_config.yaml" "$agent_config_path"
}
if (!(Test-Path -Path "$gateway_config_path") -And (Test-Path -Path "$installation_path\gateway_config.yaml")) {
    echo "$gateway_config_path not found"
    echo "Copying default gateway_config.yaml to $gateway_config_path"
    Copy-Item "$installation_path\gateway_config.yaml" "$gateway_config_path"
}
if (!(Test-Path -Path "$old_config_path") -And (Test-Path -Path "$installation_path\config.yaml")) {
    echo "$old_config_path not found"
    echo "Copying default config.yaml to $old_config_path"
    Copy-Item "$installation_path\config.yaml" "$old_config_path"
}

if ($config_path -Eq "") {
    if (($mode -Eq "agent") -And (Test-Path -Path "$agent_config_path")) {
        $config_path = $agent_config_path
    }
    elseif (($mode -Eq "gateway") -And (Test-Path -Path "$gateway_config_path")) {
        $config_path = $gateway_config_path
    }
    elseif (Test-Path -Path "$old_config_path") {
        $config_path = $old_config_path
    }
}

if (!(Test-Path -Path "$config_path")) {
    throw "Valid Collector configuration file not found at $config_path."
}

$collector_env_vars = @{
    "SPLUNK_ACCESS_TOKEN"     = "$access_token";
    "SPLUNK_API_URL"          = "$api_url";
    "SPLUNK_CONFIG"           = "$config_path";
    "SPLUNK_HEC_TOKEN"        = "$hec_token";
    "SPLUNK_HEC_URL"          = "$hec_url";
    "SPLUNK_INGEST_URL"       = "$ingest_url";
    "SPLUNK_MEMORY_TOTAL_MIB" = "$memory";
    "SPLUNK_REALM"            = "$realm";
}

if ($network_interface -Ne "") {
    $collector_env_vars.Add("SPLUNK_LISTEN_INTERFACE", "$network_interface")
}

if ($godebug -Ne "") {
    $collector_env_vars.Add("GODEBUG", "$godebug")
}

# set the environment variables for the collector service
set_service_environment $service_name $collector_env_vars

$message = "
The $CollectorServiceDisplayName for Windows has been successfully installed.
Make sure that your system's time is relatively accurate or else datapoints may not be accepted.
The collector's main configuration file is located at $config_path,
and the environment variables are stored in the $regkey registry key.

If the $config_path configuration file or any of the
SPLUNK_* environment variables in the $regkey registry key are modified,
the collector service must be restarted to apply the changes by restarting the system or running the
following PowerShell commands:
  PS> Stop-Service $service_name
  PS> Start-Service $service_name
"
echo "$message"

$otel_resource_attributes = ""
if ($deployment_env -ne "") {
    echo "Setting deployment environment to $deployment_env"
    $otel_resource_attributes = "deployment.environment=$deployment_env"
}
else {
    echo "Deployment environment was not specified. Unless otherwise defined, will appear as 'unknown' in the UI."
}

if ($with_dotnet_instrumentation) {
    echo "Installing Splunk Distribution of OpenTelemetry .NET..."
    $currentInstallVersion = Get-SplunkOpenTelemetryForDotNetVersion
    if ($currentInstallVersion) {
        throw "The Splunk Distribution of OpenTelemetry .NET is already installed. Stop all instrumented applications and uninstall it and then rerun this script."
    }

    # If the variable dotnet_auto_zip_path is an empty string, then the Installer will download the .NET Instrumentation from the default repository.
    Install-OpenTelemetryCore -LocalPath $dotnet_auto_zip_path

    $installed_version = Get-SplunkOpenTelemetryForDotNetVersion
    if ($otel_resource_attributes -ne "") {
        $otel_resource_attributes += ","
    }
    $otel_resource_attributes += "splunk.zc.method=splunk-otel-dotnet-$installed_version"
}

if ($otel_resource_attributes -ne "") {
    # The OTEL_RESOURCE_ATTRIBUTES environment variable must be set before restarting IIS.
    $regkey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment"
    try {
        update_registry -path "$regkey" -name "OTEL_RESOURCE_ATTRIBUTES" -value "$otel_resource_attributes"
    }
    catch {
        Write-Warning "Failed to set OTEL_RESOURCE_ATTRIBUTES environment variable."
        continue
    }
}

if ($with_dotnet_instrumentation) {
    if (Get-Service -Name "W3SVC" -ErrorAction SilentlyContinue) {
        echo "Registering OpenTelemetry for IIS..."
        Register-OpenTelemetryForIIS
    }

    $message = "
Splunk Distribution of OpenTelemetry for .NET has been installed and configured to forward traces to the $CollectorServiceDisplayName.
By default, the .NET instrumentation will automatically generate telemetry only for .NET applications running on IIS.
"
    echo "$message"
}

# remove the temporary directory
Remove-Item -Recurse -Force "$tempdir"

# Try starting the service(s) only after all components were successfully installed.
echo "Starting $service_name service..."
start_service -name "$service_name" -config_path "$config_path"
echo "- Started"

if (($network_interface -Eq "") -And ($mode -Eq "agent")) {
    echo "[NOTICE] Starting with version 0.86.0, the collector installer changed its default network listening interface from 0.0.0.0 to 127.0.0.1 for agent mode. Please consult the release notes for more information and configuration options."
}

# SIG # Begin signature block
# MII2DwYJKoZIhvcNAQcCoII2ADCCNfwCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDFZxb3JD4c9OVg
# RhA0Ep/ga878+vfwp+TLl316fY2fRKCCLwgwggWQMIIDeKADAgECAhAFmxtXno4h
# MuI5B72nd3VcMA0GCSqGSIb3DQEBDAUAMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQK
# EwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNV
# BAMTGERpZ2lDZXJ0IFRydXN0ZWQgUm9vdCBHNDAeFw0xMzA4MDExMjAwMDBaFw0z
# ODAxMTUxMjAwMDBaMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJ
# bmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0
# IFRydXN0ZWQgUm9vdCBHNDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIB
# AL/mkHNo3rvkXUo8MCIwaTPswqclLskhPfKK2FnC4SmnPVirdprNrnsbhA3EMB/z
# G6Q4FutWxpdtHauyefLKEdLkX9YFPFIPUh/GnhWlfr6fqVcWWVVyr2iTcMKyunWZ
# anMylNEQRBAu34LzB4TmdDttceItDBvuINXJIB1jKS3O7F5OyJP4IWGbNOsFxl7s
# Wxq868nPzaw0QF+xembud8hIqGZXV59UWI4MK7dPpzDZVu7Ke13jrclPXuU15zHL
# 2pNe3I6PgNq2kZhAkHnDeMe2scS1ahg4AxCN2NQ3pC4FfYj1gj4QkXCrVYJBMtfb
# BHMqbpEBfCFM1LyuGwN1XXhm2ToxRJozQL8I11pJpMLmqaBn3aQnvKFPObURWBf3
# JFxGj2T3wWmIdph2PVldQnaHiZdpekjw4KISG2aadMreSx7nDmOu5tTvkpI6nj3c
# AORFJYm2mkQZK37AlLTSYW3rM9nF30sEAMx9HJXDj/chsrIRt7t/8tWMcCxBYKqx
# YxhElRp2Yn72gLD76GSmM9GJB+G9t+ZDpBi4pncB4Q+UDCEdslQpJYls5Q5SUUd0
# viastkF13nqsX40/ybzTQRESW+UQUOsxxcpyFiIJ33xMdT9j7CFfxCBRa2+xq4aL
# T8LWRV+dIPyhHsXAj6KxfgommfXkaS+YHS312amyHeUbAgMBAAGjQjBAMA8GA1Ud
# EwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgGGMB0GA1UdDgQWBBTs1+OC0nFdZEzf
# Lmc/57qYrhwPTzANBgkqhkiG9w0BAQwFAAOCAgEAu2HZfalsvhfEkRvDoaIAjeNk
# aA9Wz3eucPn9mkqZucl4XAwMX+TmFClWCzZJXURj4K2clhhmGyMNPXnpbWvWVPjS
# PMFDQK4dUPVS/JA7u5iZaWvHwaeoaKQn3J35J64whbn2Z006Po9ZOSJTROvIXQPK
# 7VB6fWIhCoDIc2bRoAVgX+iltKevqPdtNZx8WorWojiZ83iL9E3SIAveBO6Mm0eB
# cg3AFDLvMFkuruBx8lbkapdvklBtlo1oepqyNhR6BvIkuQkRUNcIsbiJeoQjYUIp
# 5aPNoiBB19GcZNnqJqGLFNdMGbJQQXE9P01wI4YMStyB0swylIQNCAmXHE/A7msg
# dDDS4Dk0EIUhFQEI6FUy3nFJ2SgXUE3mvk3RdazQyvtBuEOlqtPDBURPLDab4vri
# RbgjU2wGb2dVf0a1TD9uKFp5JtKkqGKX0h7i7UqLvBv9R0oN32dmfrJbQdA75PQ7
# 9ARj6e/CVABRoIoqyc54zNXqhwQYs86vSYiv85KZtrPmYQ/ShQDnUBrkG5WdGaG5
# nLGbsQAe79APT0JsyQq87kP6OnGlyE0mpTX9iV28hWIdMtKgK1TtmlfB2/oQzxm3
# i0objwG2J5VT6LaJbVu8aNQj6ItRolb58KaAoNYes7wPD1N1KarqE3fk3oyBIa0H
# EEcRrYc9B9F1vM/zZn4wggawMIIEmKADAgECAhAIrUCyYNKcTJ9ezam9k67ZMA0G
# CSqGSIb3DQEBDAUAMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJ
# bmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0
# IFRydXN0ZWQgUm9vdCBHNDAeFw0yMTA0MjkwMDAwMDBaFw0zNjA0MjgyMzU5NTla
# MGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjFBMD8GA1UE
# AxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBDb2RlIFNpZ25pbmcgUlNBNDA5NiBTSEEz
# ODQgMjAyMSBDQTEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDVtC9C
# 0CiteLdd1TlZG7GIQvUzjOs9gZdwxbvEhSYwn6SOaNhc9es0JAfhS0/TeEP0F9ce
# 2vnS1WcaUk8OoVf8iJnBkcyBAz5NcCRks43iCH00fUyAVxJrQ5qZ8sU7H/Lvy0da
# E6ZMswEgJfMQ04uy+wjwiuCdCcBlp/qYgEk1hz1RGeiQIXhFLqGfLOEYwhrMxe6T
# SXBCMo/7xuoc82VokaJNTIIRSFJo3hC9FFdd6BgTZcV/sk+FLEikVoQ11vkunKoA
# FdE3/hoGlMJ8yOobMubKwvSnowMOdKWvObarYBLj6Na59zHh3K3kGKDYwSNHR7Oh
# D26jq22YBoMbt2pnLdK9RBqSEIGPsDsJ18ebMlrC/2pgVItJwZPt4bRc4G/rJvmM
# 1bL5OBDm6s6R9b7T+2+TYTRcvJNFKIM2KmYoX7BzzosmJQayg9Rc9hUZTO1i4F4z
# 8ujo7AqnsAMrkbI2eb73rQgedaZlzLvjSFDzd5Ea/ttQokbIYViY9XwCFjyDKK05
# huzUtw1T0PhH5nUwjewwk3YUpltLXXRhTT8SkXbev1jLchApQfDVxW0mdmgRQRNY
# mtwmKwH0iU1Z23jPgUo+QEdfyYFQc4UQIyFZYIpkVMHMIRroOBl8ZhzNeDhFMJlP
# /2NPTLuqDQhTQXxYPUez+rbsjDIJAsxsPAxWEQIDAQABo4IBWTCCAVUwEgYDVR0T
# AQH/BAgwBgEB/wIBADAdBgNVHQ4EFgQUaDfg67Y7+F8Rhvv+YXsIiGX0TkIwHwYD
# VR0jBBgwFoAU7NfjgtJxXWRM3y5nP+e6mK4cD08wDgYDVR0PAQH/BAQDAgGGMBMG
# A1UdJQQMMAoGCCsGAQUFBwMDMHcGCCsGAQUFBwEBBGswaTAkBggrBgEFBQcwAYYY
# aHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEEGCCsGAQUFBzAChjVodHRwOi8vY2Fj
# ZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0LmNydDBDBgNV
# HR8EPDA6MDigNqA0hjJodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRU
# cnVzdGVkUm9vdEc0LmNybDAcBgNVHSAEFTATMAcGBWeBDAEDMAgGBmeBDAEEATAN
# BgkqhkiG9w0BAQwFAAOCAgEAOiNEPY0Idu6PvDqZ01bgAhql+Eg08yy25nRm95Ry
# sQDKr2wwJxMSnpBEn0v9nqN8JtU3vDpdSG2V1T9J9Ce7FoFFUP2cvbaF4HZ+N3HL
# IvdaqpDP9ZNq4+sg0dVQeYiaiorBtr2hSBh+3NiAGhEZGM1hmYFW9snjdufE5Btf
# Q/g+lP92OT2e1JnPSt0o618moZVYSNUa/tcnP/2Q0XaG3RywYFzzDaju4ImhvTnh
# OE7abrs2nfvlIVNaw8rpavGiPttDuDPITzgUkpn13c5UbdldAhQfQDN8A+KVssIh
# dXNSy0bYxDQcoqVLjc1vdjcshT8azibpGL6QB7BDf5WIIIJw8MzK7/0pNVwfiThV
# 9zeKiwmhywvpMRr/LhlcOXHhvpynCgbWJme3kuZOX956rEnPLqR0kq3bPKSchh/j
# wVYbKyP/j7XqiHtwa+aguv06P0WmxOgWkVKLQcBIhEuWTatEQOON8BUozu3xGFYH
# Ki8QxAwIZDwzj64ojDzLj4gLDb879M4ee47vtevLt/B3E+bnKD+sEq6lLyJsQfmC
# XBVmzGwOysWGw/YmMwwHS6DTBwJqakAwSEs0qFEgu60bhQjiWQ1tygVQK+pKHJ6l
# /aCnHwZ05/LWUpD9r4VIIflXO7ScA+2GRfS0YW6/aOImYIbqyK+p/pQd52MbOoZW
# eE4wgge/MIIFp6ADAgECAhACoE4ZV9H+o0tCZiBl9wbZMA0GCSqGSIb3DQEBCwUA
# MGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjFBMD8GA1UE
# AxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBDb2RlIFNpZ25pbmcgUlNBNDA5NiBTSEEz
# ODQgMjAyMSBDQTEwHhcNMjQwMzE5MDAwMDAwWhcNMjYwNzMxMjM1OTU5WjCBxzET
# MBEGCysGAQQBgjc8AgEDEwJVUzEZMBcGCysGAQQBgjc8AgECEwhEZWxhd2FyZTEd
# MBsGA1UEDwwUUHJpdmF0ZSBPcmdhbml6YXRpb24xEDAOBgNVBAUTBzQxMDk2MTQx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpDYWxpZm9ybmlhMRYwFAYDVQQHEw1TYW4g
# RnJhbmNpc2NvMRQwEgYDVQQKEwtTcGx1bmsgSW5jLjEUMBIGA1UEAxMLU3BsdW5r
# IEluYy4wggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCXyFhoihTsTFBI
# wiuAJeWzv2THosrFySQsvCogImRm/gj0FlfZsx+GbvsAnzIScrQTdn3v/3marI0S
# 1NcNSAOoRGyQ0XPCa8oC2XQfcxD+lnwcQ1o+dhfGDRHJp3BcL26QnMv7PjrRJnsm
# RZvOqt8HLDJoV4Ifa5BxZFj5A2NtdaK/rx+yr0EyP8etW0sqO5dKg16oMUGLjlh0
# i6Sk5QZAe158UFBlYRBvxDXAe3zU/SgspWZ/LDe117mwZW6XSnsGep2aIyzsgBYS
# SA9V+w8JTeAGZp1AAZjJVns117y+TX8nPeOA8fMYbGsqXVsFyd0Jv0gDICoQS6lQ
# EAujY9o/YQh/PFygoZeN3Ph8hx/pbQ56gLO2lggyIzUgNXwuq8uVpxeokidicAhI
# zqTZM6x7st2MMIq+J8H7iPKlPQY7IECUWq0rTSCxu2AWt9LODA+crGYL5zhJxRz7
# LCPHD9UXaO/KeOzE+UbVQNQQbvuTC1baeiBJpYQ0+/bmgio8wGmeMgCswjJzljsR
# 16pGf84drUXAYInOtu5lFFIMek5Jmk9tv9bA4Oi8LoRTiY0fRNi7icHdMiPC7Ppd
# 3j0POKymirBHwmb6vrdi014nMS6TmCTUt0KY/9t/nMtPuVqDN9t/oAAkVdQpu0Rz
# 2bIZsgeJFQy5g8QwGu6PXO7f/N+ItwIDAQABo4ICAjCCAf4wHwYDVR0jBBgwFoAU
# aDfg67Y7+F8Rhvv+YXsIiGX0TkIwHQYDVR0OBBYEFFTUX2gexJNSemr3tiZWQTdE
# uLePMD0GA1UdIAQ2MDQwMgYFZ4EMAQMwKTAnBggrBgEFBQcCARYbaHR0cDovL3d3
# dy5kaWdpY2VydC5jb20vQ1BTMA4GA1UdDwEB/wQEAwIHgDATBgNVHSUEDDAKBggr
# BgEFBQcDAzCBtQYDVR0fBIGtMIGqMFOgUaBPhk1odHRwOi8vY3JsMy5kaWdpY2Vy
# dC5jb20vRGlnaUNlcnRUcnVzdGVkRzRDb2RlU2lnbmluZ1JTQTQwOTZTSEEzODQy
# MDIxQ0ExLmNybDBToFGgT4ZNaHR0cDovL2NybDQuZGlnaWNlcnQuY29tL0RpZ2lD
# ZXJ0VHJ1c3RlZEc0Q29kZVNpZ25pbmdSU0E0MDk2U0hBMzg0MjAyMUNBMS5jcmww
# gZQGCCsGAQUFBwEBBIGHMIGEMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdp
# Y2VydC5jb20wXAYIKwYBBQUHMAKGUGh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNv
# bS9EaWdpQ2VydFRydXN0ZWRHNENvZGVTaWduaW5nUlNBNDA5NlNIQTM4NDIwMjFD
# QTEuY3J0MAkGA1UdEwQCMAAwDQYJKoZIhvcNAQELBQADggIBAJy1McS6sMkEc66Z
# 1/97w7RBVqufXofpjOrgoY6I9g90Skz1lunFQgfvm7NyrLB5JIfbTUt0IBQvJCkc
# wYvNBWCKoQdFGVnIysHpqnz1nBaY3zj3HnSXL7swZFXPW4PjQ4yIfa5ILmUcuB2S
# 655htqFhhcvjBj90BtXaSNeOjW3ehbibRWuIvMfwwsn9MCGS65Hg7EvbtLx8uS9H
# f1ReexCac0+GwGBOC5f+P8txlwfecAgh+EwZQxUox4dWrqOgWehvnH26sryOhGpn
# pOPDCT8iwr82WUSG2t7i4zbA81/PUvsQfqArjRyl7YVXzHqqHRovdXgNCZJyyikw
# ot5YLl8VjQtStdHC5I01E4dWwNF7AN0HS3s5tpqLl9P5X58z8Se0heqznFHuh0WP
# UWJ+qiF1I2c8ZUOU2FqoBxeam/AmfmZe6oo1qllTqH9GOARCuhSFAPuwLHzDOiTr
# RcWnzHKmnCYGoG33EVsU1ReFNRzI5Peb5cjrKIX6NcdkX+VWUbskgr69dY8raWzp
# dd9FpKVhpsLmY9QI/jb/B1/VwX+JtJvx8+h+vAqgHt1QzN4rhGQn/yah+wN6X35t
# 6UjNrPrOngF+0NIChhb1TwkpJE2Ls7jMbRBcNtfYo2uFLDPMKYkOqFM8UgUFJfC+
# uLUKIkjVyjMq+blGNjnkNOP8rlQ1MIIHvzCCBaegAwIBAgIQAqBOGVfR/qNLQmYg
# ZfcG2TANBgkqhkiG9w0BAQsFADBpMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGln
# aUNlcnQsIEluYy4xQTA/BgNVBAMTOERpZ2lDZXJ0IFRydXN0ZWQgRzQgQ29kZSBT
# aWduaW5nIFJTQTQwOTYgU0hBMzg0IDIwMjEgQ0ExMB4XDTI0MDMxOTAwMDAwMFoX
# DTI2MDczMTIzNTk1OVowgccxEzARBgsrBgEEAYI3PAIBAxMCVVMxGTAXBgsrBgEE
# AYI3PAIBAhMIRGVsYXdhcmUxHTAbBgNVBA8MFFByaXZhdGUgT3JnYW5pemF0aW9u
# MRAwDgYDVQQFEwc0MTA5NjE0MQswCQYDVQQGEwJVUzETMBEGA1UECBMKQ2FsaWZv
# cm5pYTEWMBQGA1UEBxMNU2FuIEZyYW5jaXNjbzEUMBIGA1UEChMLU3BsdW5rIElu
# Yy4xFDASBgNVBAMTC1NwbHVuayBJbmMuMIICIjANBgkqhkiG9w0BAQEFAAOCAg8A
# MIICCgKCAgEAl8hYaIoU7ExQSMIrgCXls79kx6LKxckkLLwqICJkZv4I9BZX2bMf
# hm77AJ8yEnK0E3Z97/95mqyNEtTXDUgDqERskNFzwmvKAtl0H3MQ/pZ8HENaPnYX
# xg0RyadwXC9ukJzL+z460SZ7JkWbzqrfBywyaFeCH2uQcWRY+QNjbXWiv68fsq9B
# Mj/HrVtLKjuXSoNeqDFBi45YdIukpOUGQHtefFBQZWEQb8Q1wHt81P0oLKVmfyw3
# tde5sGVul0p7BnqdmiMs7IAWEkgPVfsPCU3gBmadQAGYyVZ7Nde8vk1/Jz3jgPHz
# GGxrKl1bBcndCb9IAyAqEEupUBALo2PaP2EIfzxcoKGXjdz4fIcf6W0OeoCztpYI
# MiM1IDV8LqvLlacXqJInYnAISM6k2TOse7LdjDCKvifB+4jypT0GOyBAlFqtK00g
# sbtgFrfSzgwPnKxmC+c4ScUc+ywjxw/VF2jvynjsxPlG1UDUEG77kwtW2nogSaWE
# NPv25oIqPMBpnjIArMIyc5Y7EdeqRn/OHa1FwGCJzrbuZRRSDHpOSZpPbb/WwODo
# vC6EU4mNH0TYu4nB3TIjwuz6Xd49DzispoqwR8Jm+r63YtNeJzEuk5gk1LdCmP/b
# f5zLT7lagzfbf6AAJFXUKbtEc9myGbIHiRUMuYPEMBruj1zu3/zfiLcCAwEAAaOC
# AgIwggH+MB8GA1UdIwQYMBaAFGg34Ou2O/hfEYb7/mF7CIhl9E5CMB0GA1UdDgQW
# BBRU1F9oHsSTUnpq97YmVkE3RLi3jzA9BgNVHSAENjA0MDIGBWeBDAEDMCkwJwYI
# KwYBBQUHAgEWG2h0dHA6Ly93d3cuZGlnaWNlcnQuY29tL0NQUzAOBgNVHQ8BAf8E
# BAMCB4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwgbUGA1UdHwSBrTCBqjBToFGgT4ZN
# aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0Q29kZVNp
# Z25pbmdSU0E0MDk2U0hBMzg0MjAyMUNBMS5jcmwwU6BRoE+GTWh0dHA6Ly9jcmw0
# LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRHNENvZGVTaWduaW5nUlNBNDA5
# NlNIQTM4NDIwMjFDQTEuY3JsMIGUBggrBgEFBQcBAQSBhzCBhDAkBggrBgEFBQcw
# AYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMFwGCCsGAQUFBzAChlBodHRwOi8v
# Y2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkRzRDb2RlU2lnbmlu
# Z1JTQTQwOTZTSEEzODQyMDIxQ0ExLmNydDAJBgNVHRMEAjAAMA0GCSqGSIb3DQEB
# CwUAA4ICAQCctTHEurDJBHOumdf/e8O0QVarn16H6Yzq4KGOiPYPdEpM9ZbpxUIH
# 75uzcqyweSSH201LdCAULyQpHMGLzQVgiqEHRRlZyMrB6ap89ZwWmN849x50ly+7
# MGRVz1uD40OMiH2uSC5lHLgdkuueYbahYYXL4wY/dAbV2kjXjo1t3oW4m0VriLzH
# 8MLJ/TAhkuuR4OxL27S8fLkvR39UXnsQmnNPhsBgTguX/j/LcZcH3nAIIfhMGUMV
# KMeHVq6joFnob5x9urK8joRqZ6Tjwwk/IsK/NllEhtre4uM2wPNfz1L7EH6gK40c
# pe2FV8x6qh0aL3V4DQmScsopMKLeWC5fFY0LUrXRwuSNNROHVsDRewDdB0t7Obaa
# i5fT+V+fM/EntIXqs5xR7odFj1FifqohdSNnPGVDlNhaqAcXmpvwJn5mXuqKNapZ
# U6h/RjgEQroUhQD7sCx8wzok60XFp8xyppwmBqBt9xFbFNUXhTUcyOT3m+XI6yiF
# +jXHZF/lVlG7JIK+vXWPK2ls6XXfRaSlYabC5mPUCP42/wdf1cF/ibSb8fPofrwK
# oB7dUMzeK4RkJ/8mofsDel9+belIzaz6zp4BftDSAoYW9U8JKSRNi7O4zG0QXDbX
# 2KNrhSwzzCmJDqhTPFIFBSXwvri1CiJI1cozKvm5RjY55DTj/K5UNTCCBY0wggR1
# oAMCAQICEA6bGI750C3n79tQ4ghAGFowDQYJKoZIhvcNAQEMBQAwZTELMAkGA1UE
# BhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2lj
# ZXJ0LmNvbTEkMCIGA1UEAxMbRGlnaUNlcnQgQXNzdXJlZCBJRCBSb290IENBMB4X
# DTIyMDgwMTAwMDAwMFoXDTMxMTEwOTIzNTk1OVowYjELMAkGA1UEBhMCVVMxFTAT
# BgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEh
# MB8GA1UEAxMYRGlnaUNlcnQgVHJ1c3RlZCBSb290IEc0MIICIjANBgkqhkiG9w0B
# AQEFAAOCAg8AMIICCgKCAgEAv+aQc2jeu+RdSjwwIjBpM+zCpyUuySE98orYWcLh
# Kac9WKt2ms2uexuEDcQwH/MbpDgW61bGl20dq7J58soR0uRf1gU8Ug9SH8aeFaV+
# vp+pVxZZVXKvaJNwwrK6dZlqczKU0RBEEC7fgvMHhOZ0O21x4i0MG+4g1ckgHWMp
# Lc7sXk7Ik/ghYZs06wXGXuxbGrzryc/NrDRAX7F6Zu53yEioZldXn1RYjgwrt0+n
# MNlW7sp7XeOtyU9e5TXnMcvak17cjo+A2raRmECQecN4x7axxLVqGDgDEI3Y1Dek
# LgV9iPWCPhCRcKtVgkEy19sEcypukQF8IUzUvK4bA3VdeGbZOjFEmjNAvwjXWkmk
# wuapoGfdpCe8oU85tRFYF/ckXEaPZPfBaYh2mHY9WV1CdoeJl2l6SPDgohIbZpp0
# yt5LHucOY67m1O+SkjqePdwA5EUlibaaRBkrfsCUtNJhbesz2cXfSwQAzH0clcOP
# 9yGyshG3u3/y1YxwLEFgqrFjGESVGnZifvaAsPvoZKYz0YkH4b235kOkGLimdwHh
# D5QMIR2yVCkliWzlDlJRR3S+Jqy2QXXeeqxfjT/JvNNBERJb5RBQ6zHFynIWIgnf
# fEx1P2PsIV/EIFFrb7GrhotPwtZFX50g/KEexcCPorF+CiaZ9eRpL5gdLfXZqbId
# 5RsCAwEAAaOCATowggE2MA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFOzX44LS
# cV1kTN8uZz/nupiuHA9PMB8GA1UdIwQYMBaAFEXroq/0ksuCMS1Ri6enIZ3zbcgP
# MA4GA1UdDwEB/wQEAwIBhjB5BggrBgEFBQcBAQRtMGswJAYIKwYBBQUHMAGGGGh0
# dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBDBggrBgEFBQcwAoY3aHR0cDovL2NhY2Vy
# dHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNydDBFBgNV
# HR8EPjA8MDqgOKA2hjRodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRB
# c3N1cmVkSURSb290Q0EuY3JsMBEGA1UdIAQKMAgwBgYEVR0gADANBgkqhkiG9w0B
# AQwFAAOCAQEAcKC/Q1xV5zhfoKN0Gz22Ftf3v1cHvZqsoYcs7IVeqRq7IviHGmlU
# Iu2kiHdtvRoU9BNKei8ttzjv9P+Aufih9/Jy3iS8UgPITtAq3votVs/59PesMHqa
# i7Je1M/RQ0SbQyHrlnKhSLSZy51PpwYDE3cnRNTnf+hZqPC/Lwum6fI0POz3A8eH
# qNJMQBk1RmppVLC4oVaO7KTVPeix3P0c2PR3WlxUjG/voVA9/HYJaISfb8rbII01
# YBwCA8sgsKxYoA5AY8WYIsGyWfVVa88nq2x2zm8jLfR+cWojayL/ErhULSd+2DrZ
# 8LaHlv1b0VysGMNNn3O3AamfV6peKOK5lDCCBrQwggScoAMCAQICEA3HrFcF/yGZ
# LkBDIgw6SYYwDQYJKoZIhvcNAQELBQAwYjELMAkGA1UEBhMCVVMxFTATBgNVBAoT
# DERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEhMB8GA1UE
# AxMYRGlnaUNlcnQgVHJ1c3RlZCBSb290IEc0MB4XDTI1MDUwNzAwMDAwMFoXDTM4
# MDExNDIzNTk1OVowaTELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJ
# bmMuMUEwPwYDVQQDEzhEaWdpQ2VydCBUcnVzdGVkIEc0IFRpbWVTdGFtcGluZyBS
# U0E0MDk2IFNIQTI1NiAyMDI1IENBMTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCC
# AgoCggIBALR4MdMKmEFyvjxGwBysddujRmh0tFEXnU2tjQ2UtZmWgyxU7UNqEY81
# FzJsQqr5G7A6c+Gh/qm8Xi4aPCOo2N8S9SLrC6Kbltqn7SWCWgzbNfiR+2fkHUil
# jNOqnIVD/gG3SYDEAd4dg2dDGpeZGKe+42DFUF0mR/vtLa4+gKPsYfwEu7EEbkC9
# +0F2w4QJLVSTEG8yAR2CQWIM1iI5PHg62IVwxKSpO0XaF9DPfNBKS7Zazch8NF5v
# p7eaZ2CVNxpqumzTCNSOxm+SAWSuIr21Qomb+zzQWKhxKTVVgtmUPAW35xUUFREm
# DrMxSNlr/NsJyUXzdtFUUt4aS4CEeIY8y9IaaGBpPNXKFifinT7zL2gdFpBP9qh8
# SdLnEut/GcalNeJQ55IuwnKCgs+nrpuQNfVmUB5KlCX3ZA4x5HHKS+rqBvKWxdCy
# QEEGcbLe1b8Aw4wJkhU1JrPsFfxW1gaou30yZ46t4Y9F20HHfIY4/6vHespYMQmU
# iote8ladjS/nJ0+k6MvqzfpzPDOy5y6gqztiT96Fv/9bH7mQyogxG9QEPHrPV6/7
# umw052AkyiLA6tQbZl1KhBtTasySkuJDpsZGKdlsjg4u70EwgWbVRSX1Wd4+zoFp
# p4Ra+MlKM2baoD6x0VR4RjSpWM8o5a6D8bpfm4CLKczsG7ZrIGNTAgMBAAGjggFd
# MIIBWTASBgNVHRMBAf8ECDAGAQH/AgEAMB0GA1UdDgQWBBTvb1NK6eQGfHrK4pBW
# 9i/USezLTjAfBgNVHSMEGDAWgBTs1+OC0nFdZEzfLmc/57qYrhwPTzAOBgNVHQ8B
# Af8EBAMCAYYwEwYDVR0lBAwwCgYIKwYBBQUHAwgwdwYIKwYBBQUHAQEEazBpMCQG
# CCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wQQYIKwYBBQUHMAKG
# NWh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRSb290
# RzQuY3J0MEMGA1UdHwQ8MDowOKA2oDSGMmh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNv
# bS9EaWdpQ2VydFRydXN0ZWRSb290RzQuY3JsMCAGA1UdIAQZMBcwCAYGZ4EMAQQC
# MAsGCWCGSAGG/WwHATANBgkqhkiG9w0BAQsFAAOCAgEAF877FoAc/gc9EXZxML2+
# C8i1NKZ/zdCHxYgaMH9Pw5tcBnPw6O6FTGNpoV2V4wzSUGvI9NAzaoQk97frPBtI
# j+ZLzdp+yXdhOP4hCFATuNT+ReOPK0mCefSG+tXqGpYZ3essBS3q8nL2UwM+NMvE
# uBd/2vmdYxDCvwzJv2sRUoKEfJ+nN57mQfQXwcAEGCvRR2qKtntujB71WPYAgwPy
# WLKu6RnaID/B0ba2H3LUiwDRAXx1Neq9ydOal95CHfmTnM4I+ZI2rVQfjXQA1WSj
# jf4J2a7jLzWGNqNX+DF0SQzHU0pTi4dBwp9nEC8EAqoxW6q17r0z0noDjs6+BFo+
# z7bKSBwZXTRNivYuve3L2oiKNqetRHdqfMTCW/NmKLJ9M+MtucVGyOxiDf06VXxy
# KkOirv6o02OoXN4bFzK0vlNMsvhlqgF2puE6FndlENSmE+9JGYxOGLS/D284NHNb
# oDGcmWXfwXRy4kbu4QFhOm0xJuF2EZAOk5eCkhSxZON3rGlHqhpB/8MluDezooIs
# 8CVnrpHMiD2wL40mm53+/j7tFaxYKIqL0Q4ssd8xHZnIn/7GELH3IdvG2XlM9q7W
# P/UwgOkw/HQtyRN62JK4S1C8uw3PdBunvAZapsiI5YKdvlarEvf8EA+8hcpSM9LH
# JmyrxaFtoza2zNaQ9k+5t1wwggbtMIIE1aADAgECAhAKgO8YS43xBYLRxHanlXRo
# MA0GCSqGSIb3DQEBCwUAMGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2Vy
# dCwgSW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBUaW1lU3RhbXBp
# bmcgUlNBNDA5NiBTSEEyNTYgMjAyNSBDQTEwHhcNMjUwNjA0MDAwMDAwWhcNMzYw
# OTAzMjM1OTU5WjBjMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIElu
# Yy4xOzA5BgNVBAMTMkRpZ2lDZXJ0IFNIQTI1NiBSU0E0MDk2IFRpbWVzdGFtcCBS
# ZXNwb25kZXIgMjAyNSAxMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA
# 0EasLRLGntDqrmBWsytXum9R/4ZwCgHfyjfMGUIwYzKomd8U1nH7C8Dr0cVMF3Bs
# fAFI54um8+dnxk36+jx0Tb+k+87H9WPxNyFPJIDZHhAqlUPt281mHrBbZHqRK71E
# m3/hCGC5KyyneqiZ7syvFXJ9A72wzHpkBaMUNg7MOLxI6E9RaUueHTQKWXymOtRw
# JXcrcTTPPT2V1D/+cFllESviH8YjoPFvZSjKs3SKO1QNUdFd2adw44wDcKgH+JRJ
# E5Qg0NP3yiSyi5MxgU6cehGHr7zou1znOM8odbkqoK+lJ25LCHBSai25CFyD23DZ
# gPfDrJJJK77epTwMP6eKA0kWa3osAe8fcpK40uhktzUd/Yk0xUvhDU6lvJukx7jp
# hx40DQt82yepyekl4i0r8OEps/FNO4ahfvAk12hE5FVs9HVVWcO5J4dVmVzix4A7
# 7p3awLbr89A90/nWGjXMGn7FQhmSlIUDy9Z2hSgctaepZTd0ILIUbWuhKuAeNIeW
# rzHKYueMJtItnj2Q+aTyLLKLM0MheP/9w6CtjuuVHJOVoIJ/DtpJRE7Ce7vMRHoR
# on4CWIvuiNN1Lk9Y+xZ66lazs2kKFSTnnkrT3pXWETTJkhd76CIDBbTRofOsNyEh
# zZtCGmnQigpFHti58CSmvEyJcAlDVcKacJ+A9/z7eacCAwEAAaOCAZUwggGRMAwG
# A1UdEwEB/wQCMAAwHQYDVR0OBBYEFOQ7/PIx7f391/ORcWMZUEPPYYzoMB8GA1Ud
# IwQYMBaAFO9vU0rp5AZ8esrikFb2L9RJ7MtOMA4GA1UdDwEB/wQEAwIHgDAWBgNV
# HSUBAf8EDDAKBggrBgEFBQcDCDCBlQYIKwYBBQUHAQEEgYgwgYUwJAYIKwYBBQUH
# MAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBdBggrBgEFBQcwAoZRaHR0cDov
# L2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0VGltZVN0YW1w
# aW5nUlNBNDA5NlNIQTI1NjIwMjVDQTEuY3J0MF8GA1UdHwRYMFYwVKBSoFCGTmh0
# dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRHNFRpbWVTdGFt
# cGluZ1JTQTQwOTZTSEEyNTYyMDI1Q0ExLmNybDAgBgNVHSAEGTAXMAgGBmeBDAEE
# AjALBglghkgBhv1sBwEwDQYJKoZIhvcNAQELBQADggIBAGUqrfEcJwS5rmBB7NEI
# RJ5jQHIh+OT2Ik/bNYulCrVvhREafBYF0RkP2AGr181o2YWPoSHz9iZEN/FPsLST
# wVQWo2H62yGBvg7ouCODwrx6ULj6hYKqdT8wv2UV+Kbz/3ImZlJ7YXwBD9R0oU62
# PtgxOao872bOySCILdBghQ/ZLcdC8cbUUO75ZSpbh1oipOhcUT8lD8QAGB9lctZT
# TOJM3pHfKBAEcxQFoHlt2s9sXoxFizTeHihsQyfFg5fxUFEp7W42fNBVN4ueLace
# Rf9Cq9ec1v5iQMWTFQa0xNqItH3CPFTG7aEQJmmrJTV3Qhtfparz+BW60OiMEgV5
# GWoBy4RVPRwqxv7Mk0Sy4QHs7v9y69NBqycz0BZwhB9WOfOu/CIJnzkQTwtSSpGG
# hLdjnQ4eBpjtP+XB3pQCtv4E5UCSDag6+iX8MmB10nfldPF9SVD7weCC3yXZi/uu
# hqdwkgVxuiMFzGVFwYbQsiGnoa9F5AaAyBjFBtXVLcKtapnMG3VH3EmAp/jsJ3FV
# F3+d1SVDTmjFjLbNFZUWMXuZyvgLfgyPehwJVxwC+UpX2MSey2ueIu9THFVkT+um
# 1vshETaWyQo8gmBto/m3acaP9QsuLj3FNwFlTxq25+T4QwX9xa6ILs84ZPvmpovq
# 90K8eWyG2N01c4IhSOxqt81nMYIGXTCCBlkCAQEwfTBpMQswCQYDVQQGEwJVUzEX
# MBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/BgNVBAMTOERpZ2lDZXJ0IFRydXN0
# ZWQgRzQgQ29kZSBTaWduaW5nIFJTQTQwOTYgU0hBMzg0IDIwMjEgQ0ExAhACoE4Z
# V9H+o0tCZiBl9wbZMA0GCWCGSAFlAwQCAQUAoIGIMBkGCSqGSIb3DQEJAzEMBgor
# BgEEAYI3AgEEMBwGCSqGSIb3DQEJBTEPFw0yNjA2MTcwMTAwNTBaMBwGCisGAQQB
# gjcCAQsxDjAMBgorBgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCBiy3Kj3fvpjvL0
# Cyd+lAciYAzy8fx9ehR5fLxuIoseFTANBgkqhkiG9w0BAQEFAASCAgBo2jFjj6Sg
# hOADTkhESl1ce2o+grSDytsrdApmWahCO+Pm9F2j9PMhencEnfPj5f86p5CZsHu/
# 4GN4xPQyEtopxaVkQNTQBjQQPKRM/R7sxIH+iv1PkcR1ES6BtB3Gf3W0R+kH8jvv
# QmMY8pLn/NYCWp+jBqbawC5rAMBsqz5GhrnU/Gemepceb1FNUwkvxSkHgNkVfRlT
# 1kHDIctQ4q+ynxJiaOmS27/dceYTEHLNJmkOE3shBtLQy+h8ezCc1huaQ45Xt0RI
# SaDyuHQbIsN/pWpi+e05ujALuhdMMVJxDhdWKhXzeBQSAbO+7I1fRP2A9XxFoqoX
# nA0NkIZ4bdnXQTpR05zHKpXnZjCt7GXqIp3cFkl/X2zwJrvfSuVbXyER2kRQqkio
# VRh+3xGxrAZe5KmR6n8PDqt2ZyO6a7JoLEagcOwIRdMJjfEUkwHLn0GioUwiInLG
# MOqX/PRGVX01pmj3evBiMz4tRi9CbEUlesplggeH7oKUHoVqYEafGZ2shHYj8XNR
# EKf3IAEs6SFUA8PO6uUDVRyZZWhsb8Qef7Zp4eYGp+U9njJoaJOpVHWHmS3kiIZC
# /cn7S1z4bBx0ghMLaZWxt3BjV/kzjjYuVRDVK1QCT35DwgNKaPC9FynajdhcPRj7
# 4Tr659qlfzg0FUl/f+ZU/xLnApgLl151vaGCAyYwggMiBgkqhkiG9w0BCQYxggMT
# MIIDDwIBATB9MGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5j
# LjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBUaW1lU3RhbXBpbmcgUlNB
# NDA5NiBTSEEyNTYgMjAyNSBDQTECEAqA7xhLjfEFgtHEdqeVdGgwDQYJYIZIAWUD
# BAIBBQCgaTAYBgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEP
# Fw0yNjA2MTcwMTAwNTBaMC8GCSqGSIb3DQEJBDEiBCCyzl9R2gFq6URxqLirzvwd
# DtxOr1AUW0/R3Ea9UrqarzANBgkqhkiG9w0BAQEFAASCAgCK6DMbnoVsdh6Jvaee
# qUuh6uoguNj+E0EXxs+89+GjE0J5EhMatWAUSJOFhWt0LMimGxeqwjv6sboHszwu
# cpYFN2N+3Vc6xpBxPxkyEV7qElEljJ0nYUCOfSBfOyXry6yorN5IOyT5CmT7Layb
# boPfake2HFB8O/ySV65eY8wDhQI6ZR2mZpJDcJq0gsxbUg3fQ2EW7P+h1J8RPJ5s
# ANmccke/oz6re/G8PF08Tg28KQf1lS6iaCIFcraijIerNO7eEbdnkpOeI0zjyxSV
# +ddCmbzahrvXFHoRu1QYQK51wufl+EfX5F3YjAhPfe+1wnsjaaZ4CQCcyjwEBDGJ
# 7P/BjO19Sa3L5gqkDu+VbHjDbh/t63E7hNCnSCpCjyCU1coJ3eZBL51AAitiafZe
# 4xshTrtnlQY9W2P4eFYOI2N1rWurcstyL0+pjd61L0/g7N/nwY6N3oZlCPN/wPCe
# 6v0iViu5z1M9SSEADOCjiiBJHSQAk96Y64oB3TGm9PgMP9pFRL12pMKAA3unlrCj
# re+A9nZq0FwFv48t9boMQUGfm0hjJhrhXByUzyNgiN0vAVqmyKvL/9CXKe0LW3D2
# lrPoC/GkedKdCnHzYVxflSgfU+mZdKLsdwNQAMTCnGP8/MSCZ5rV47ddWBVjgI+2
# uZ24OuUXZLAgX4AmPB7xZ8mB8w==
# SIG # End signature block
