$script:project_config = "Release"

properties {

  $solution_name = "FormApi"
  $domain = "apps.nonprod.stargate.cunamutual.com"
  $environment = "sandbox"

  $base_dir = resolve-path .
  $project_dir = "$base_dir\$project_name"
  $project_file = "$project_dir\$project_name.csproj"
  $solution_file = "$base_dir\$solution_name.sln"
  $packages_dir = "$base_dir\packages"
  $publish_dir = "$base_dir\publish"
  $database_project_dir = "$base_dir\form.Database"

  $version = get_version
  $date = Get-Date
  $dotnet_exe = get-dotnet

  $sqlserver = "(localdb)\ProjectsV13" 
  $dacpac = "$($database_project_dir)\bin\database\form.database.dacpac" 
  $dbname = "Form.Database" 

  $ReleaseNumber =  $version
  
  Write-Host "**********************************************************************"
  Write-Host "Release Number: $ReleaseNumber"
  Write-Host "**********************************************************************"
  

  $packageId = if ($env:package_id) { $env:package_id } else { "$solution_name" }
}
   
#These are aliases for other build tasks. They typically are named after the camelcase letters (rd = Rebuild Databases)
task default -depends InitialPrivateBuild
task dev -depends DeveloperBuild
task ci -depends IntegrationBuild
task ? -depends help
task test -depends RunTests
task pp -depends Publish-Push
task publish_notest_push -depends SetReleaseBuild, Clean, Publish, push


task help {
   Write-Help-Header
   Write-Help-Section-Header "Comprehensive Building"
   Write-Help-For-Alias "(default)" "Intended for first build or when you want a fresh, clean local copy"
   Write-Help-For-Alias "dev" "Optimized for local dev"
   Write-Help-For-Alias "ci" "Continuous Integration build (long and thorough) with packaging"
   Write-Help-For-Alias "test" "Run local tests"
   Write-Help-For-Alias "pnp" "Intended for pushing to PCF"
   Write-Help-For-Alias "pp" "Intended for pushing to PCF. Will run webpack without tests"
   Write-Help-Footer
   exit 0
}

#These are the actual build tasks. They should be Pascal case by convention
task InitialPrivateBuild -depends Clean, test
task RunTests -depends Clean, UnitTest, DatabaseBuild, IntegrationTest
task DeveloperBuild -depends SetDebugBuild, Clean, test
task IntegrationBuild -depends SetReleaseBuild, PackageRestore, Clean, UnitTest, Publish
task Publish-Push -depends SetReleaseBuild, Clean, test, Publish, push
task DatabaseBuild -depends DeleteDatabase, BuildDatabase, CreateDatabase, PopulateDatabase

task SetDebugBuild {
    $script:project_config = "Debug"
}

task SetReleaseBuild {
    $script:project_config = "Release"
}

task SetVersion {
	set-content $base_dir\CommonAssemblyInfo.cs "// Generated file - do not modify",
	        "using System.Reflection;",
	        "[assembly: AssemblyVersion(`"$version`")]",
	        "[assembly: AssemblyFileVersion(`"$version`")]",
	        "[assembly: AssemblyInformationalVersion(`"$version`")]"
	
	Write-Host "Using version#: $version"
}

task UnitTest {
   Write-Host "******************* Now running Unit Tests *********************"
   exec { & $dotnet_exe test -c $project_config "$base_dir\$project_name.tests\$project_name.tests.csproj" }
}

task IntegrationTest {
   Write-Host "******************* Now running Integration Tests *********************"
   exec { & $dotnet_exe test -c $project_config "$base_dir\$project_name.IntegrationTests\$project_name.IntegrationTests.csproj" }
}

task Clean {
	if (Test-Path $publish_dir) {
		delete_directory $publish_dir
	}

	Write-Host "******************* Now Cleaning the Solution *********************"
    exec { & $dotnet_exe clean -c $project_config $solution_file }
}

task PackageRestore {
	Write-Host "******************* Now restoring the Solution packages *********************"
	exec { & $dotnet_exe restore $solution_file }
}

task Publish {
	Write-Host "Publishing to $publish_dir *****"
	if (!(Test-Path $publish_dir)) {
		New-Item -ItemType Directory -Force -Path $publish_dir
	}
	exec { & $dotnet_exe publish -c $project_config $project_file -o $publish_dir -r win10-x64}
}

task Push {
	Push-Location $publish_dir

	Write-Host "Pushing application to PCF"
	exec { & "cf" push -d $domain --var environment=$environment -n "form-api-sandbox"}

	Pop-Location
}


task BuildDatabase{
    Push-Location $database_project_dir 

	Write-Host "Building " .\Form.Database.sqlproj
    exec { & "c:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\Common7\IDE\devenv.exe" Form.Database.sqlproj /build database }
    
    Pop-Location
}

task CreateDatabase{
    
    Push-Location $database_project_dir 

    exec { & "c:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\Common7\IDE\devenv" Form.Database.sqlproj /build database }
    
    
    $sqlserver = "(localdb)\ProjectsV13" 
    $dacpac = "$($database_project_dir)\bin\database\form.database.dacpac" 
    $dbname = "Form.Database" 
        
    # load in DAC DLL, This requires config file to support .NET 4.0.
    # change file location for a 32-bit OS 
    #make sure you
    $dllPath = "C:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\140\Microsoft.SqlServer.Dac.dll"
    add-type -path $dllPath
    
    # Create a DacServices object, which needs a connection string 
    $dacsvcs = new-object Microsoft.SqlServer.Dac.DacServices "server=$sqlserver"

    $dacSvcsOptions = new-object Microsoft.SqlServer.Dac.DacDeployOptions
    $dacSvcsOptions.BlockOnPossibleDataLoss = $false
    
    # register event. For info on this cmdlet, see http://technet.microsoft.com/en-us/library/hh849929.aspx 
    register-objectevent -in $dacsvcs -eventname Message -source "msg" -action { out-host -in $Event.SourceArgs[1].Message.Message } | Out-Null
    
    # Load dacpac from file & deploy database
    $dp = [Microsoft.SqlServer.Dac.DacPackage]::Load($dacpac) 
    $dacsvcs.Deploy($dp, $dbname, $true, $dacSvcsOptions) 
    
    # clean up event 
    unregister-event -source "msg" 

    pop-location
}

task PopulateDatabase{
    Push-Location "$($base_Dir)\databaseSetup"

    Write-Host "Inserting Dependencies"
    Invoke-sqlcmd -ServerInstance $sqlserver -Database $dbname -InputFile  "Dependencies.sql"  
    
    Write-Host "Inserting Seed Data"
    Invoke-sqlcmd -ServerInstance $sqlserver -Database $dbname -InputFile  "SQL_2018-12-04.sql"  -ConnectionTimeout 300 -QueryTimeout 300 

    Pop-Location
}

task DeleteDatabase{
	Write-Host "Deleting local database"

	Try {
		Invoke-sqlcmd -ServerInstance $sqlserver -Query "alter database [Form.Database] set single_user with rollback immediate" 
		Invoke-sqlcmd -ServerInstance $sqlserver -Query "Drop Database [Form.Database]" 
	}
	Catch {
		$ErrorMessage = $_.Exception.Message
		Write-Host $ErrorMessage
	}
}

# -------------------------------------------------------------------------------------------------------------
# generalized functions for Help Section
# --------------------------------------------------------------------------------------------------------------

function Write-Help-Header($description) {
   Write-Host ""
   Write-Host "********************************" -foregroundcolor DarkGreen -nonewline;
   Write-Host " HELP " -foregroundcolor Green  -nonewline; 
   Write-Host "********************************"  -foregroundcolor DarkGreen
   Write-Host ""
   Write-Host "This build script has the following common build " -nonewline;
   Write-Host "task " -foregroundcolor Green -nonewline;
   Write-Host "aliases set up:"
}

function Write-Help-Footer($description) {
   Write-Host ""
   Write-Host " For a complete list of build tasks, view default.ps1."
   Write-Host ""
   Write-Host "**********************************************************************" -foregroundcolor DarkGreen
}

function Write-Help-Section-Header($description) {
   Write-Host ""
   Write-Host " $description" -foregroundcolor DarkGreen
}

function Write-Help-For-Alias($alias,$description) {
   Write-Host "  > " -nonewline;
   Write-Host "$alias" -foregroundcolor Green -nonewline; 
   Write-Host " = " -nonewline; 
   Write-Host "$description"
}

# -------------------------------------------------------------------------------------------------------------
# generalized functions 
# --------------------------------------------------------------------------------------------------------------
function global:delete_file($file) {
    if($file) { remove-item $file -force -ErrorAction SilentlyContinue | out-null } 
}

function global:delete_directory($directory_name)
{
  rd $directory_name -recurse -force  -ErrorAction SilentlyContinue | out-null
}

function global:get_dacDll(){
    return "C:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\140\Microsoft.SqlServer.Dac.dll";
}

function global:delete_files($directory_name) {
    Get-ChildItem -Path $directory_name -Include * -File -Recurse | foreach { $_.Delete()}
}

function global:get_vstest_executable($lookin_path) {
    $vstest_exe = Get-ChildItem $lookin_path -Filter Microsoft.TestPlatform* | Select-Object -First 1 | Get-ChildItem -Recurse -Filter vstest.console.exe | % { $_.FullName }
    return $vstest_exe
}

function global:get_version(){
	Write-Host "******************* Getting the Version Number ********************"
	$version = get-content "$base_Dir\..\version\number" -ErrorAction SilentlyContinue
	if ($version -eq $null) {
	    Write-Host "--------- No version found defaulting to 1.0.0 --------------------" -foregroundcolor Red
		$version = '1.0.0'
	}
	return $version
}

function global:get-dotnet(){
	return (Get-Command dotnet.exe).Path
}
