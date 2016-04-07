﻿$jsSdkDir = Read-Host "Please enter the JSSDK root dir";

if (-Not (Test-Path $jsSdkDir)) {
    Write-Warning "'$jssdkDir' directory doesn't exist.";
    exit;
}

$packageJsonPath =  Join-Path $jsSdkDir -ChildPath "package.json"
if (-Not (Test-Path $packageJsonPath)) {
    Write-Warning "'$packageJsonPath' file not found, please enter the top JSSDK directory.";
    exit;
}

$packagesJson = (Get-Content $packageJsonPath -Raw) | ConvertFrom-Json
$oldVersion = $packagesJson.version;

Write-Host "Current JSSDK version is '$oldVersion'"
$version = Read-Host "Please enter new version";

if (-Not ($version -match "\d+\.\d+\.\d+")) {
    Write-Warning "Invalid version number. Expecting three numbers: Major, Minor and Path (e.g. 1.2.3)"
    exit;
}

# update package.json 
$packagesJson.version = $version
$packagesJson | ConvertTo-Json | Out-File $packageJsonPath

# update bower.json
$bowerJsonPath = Join-Path $jsSdkDir -ChildPath "bower.json"
$bowerJson = (Get-Content $bowerJsonPath -Raw) | ConvertFrom-Json
$bowerJson.version = $version
$packagesJson | ConvertTo-Json | Out-File $bowerJsonPath

# update JavaScript\JavaScriptSDK\AppInsights.ts
$appInsightsTsPath = Join-Path $jsSdkDir -ChildPath "JavaScript\JavaScriptSDK\AppInsights.ts"
$appInsightsTs = Get-Content $appInsightsTsPath

if (-Not ($appInsightsTs -match "export var Version = `"\d+\.\d+\.\d+`"")) {
    Write-Warning "Cannot find 'Version' variable in the AppInsights.ts file. Please update the version manualy."
    # continue on error
} else {
    $appInsightsTs = $appInsightsTs -replace "export var Version = `"\d+\.\d+\.\d+`"", "export var Version = `"$version`""
    $appInsightsTs | Out-File $appInsightsTsPath
}

# update global.props    
$versionSplit = $version.Split('.');

$globalPropsPath = Join-Path $jsSdkDir -ChildPath "Global.props"
$globalPropsXml = [xml](Get-Content $globalPropsPath)

$ns = New-Object System.Xml.XmlNamespaceManager($globalPropsXml.NameTable)
$ns.AddNamespace("ns", $globalPropsXml.DocumentElement.NamespaceURI)

$globalPropsXml.SelectSingleNode("//ns:SemanticVersionMajor", $ns).InnerText = $versionSplit[0]
$globalPropsXml.SelectSingleNode("//ns:SemanticVersionMinor", $ns).InnerText = $versionSplit[1]
$globalPropsXml.SelectSingleNode("//ns:SemanticVersionPatch", $ns).InnerText = $versionSplit[2]

$globalPropsXml.Save($globalPropsPath);

git checkout -b "release_$version"
git add package.json
git add bower.json
git add Global.props
git add JavaScript/JavaScriptSDK/AppInsights.ts

git commit -m "version update $oldVersion -> $version"

Write-Host ""
Write-Host "Git commit ready. Please review, push and create a pull request on GitHub"