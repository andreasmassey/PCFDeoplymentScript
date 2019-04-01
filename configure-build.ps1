# pull dependencies

$has_vsSetup = Get-Module -ListAvailable | Select-String -Pattern "VSSetup" -Quiet
if(-Not($has_vsSetup)) {
	#install VSSetup
	Write-Host "No VSSetup Module Found: Installing now" -ForegroundColor Red
	Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
	Install-Module VSSetup -Scope CurrentUser
}

$has_psake = Get-Module -ListAvailable | Select-String -Pattern "Psake" -Quiet
if(-Not($has_psake)) {
	#install psake
	Write-Host "No Psake Module Found: Installing now" -ForegroundColor Red
	Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
	Install-Module Psake -Scope CurrentUser
}

$has_sqlServer = Get-Module -ListAvailable | Select-String -Pattern "SqlServer" -Quiet
if(-Not($has_sqlServer)) {
	#install SqlServer
	Write-Host "No SqlServer Module Found: Installing now" -ForegroundColor Red
	Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
	Install-Module SqlServer -Scope CurrentUser
}
$has_sqlServer = Get-Module -ListAvailable | Select-String -Pattern "SqlServer" -Quiet
if(-Not($has_sqlServer)) {
	#install SqlServer
	Write-Host "No SqlServer Module Found: Installing now" -ForegroundColor Red
	Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
	Install-Module SqlServer -Scope CurrentUser
}
$has_sqlServer = Get-Module -ListAvailable | Select-String -Pattern "SqlServer" -Quiet
if(-Not($has_sqlServer)) {
	#install SqlServer
	Write-Host "No SqlServer Module Found: Installing now" -ForegroundColor Red
	Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
	Install-Module SqlServer -Scope CurrentUser
}