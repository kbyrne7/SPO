<#
===============================================================
 LCCC SPO PROJECT – MASTER AUTOMATION SCRIPT (PowerShell 7+)
===============================================================
#>

# Allow local script execution for current user
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Unrestricted -Force

Write-Host "`n=== LCCC SPO PROJECT AUTOMATION ===`n" -ForegroundColor Cyan

#
#High-Level Overview of Site Promotion MASTER script
#Master Sharegate migration file for running all site promotion  and post-configuration steps
#Prior to running a site promotion ensure that all custom content types are 'Unpublished' in the tenant admin site
#@ https://limerickcouncil-admin.sharepoint.com/_layouts/15/online/AdminHome.aspx#/contentTypes
#This will prevent duplicate content types from appearing on sites (i.e. there are already local copies of these CTypes)
#NOTE: You need to run each script below manually in Powershell 7.0+ - replace 'kevin.byrne' with your local profile folder on C:\
#With the exception of STEP 2 - Sharegate Powershell - @ C:\Users\kevin.byrne\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\ShareGate
#Sharegate Powershell is used for site promotion using the Sharegate powershell console, this is installed with ShareGate...
#All other steps 1,3-4 should use Powershell version 7.0+ ONLY
##########################INSTRUCTIONS PRE-Configuration of laptop############################################################################
#To install PWSH or Powershell 7.0+ download the 'PowerShell-7.5.2-win-x64.7zip' this ZIP file and then extract it locally, 
#replace '[first name].[surname]' with your local profile folder on C:\, then create a new shortcut on your desktop to the PWSH (Powershell) file, 
#use it run Powershell 7.0+ scripts - "C:\Users\kevin.byrne\Documents\LCC SPO\Software\PowerShell-7.5.2-win-x64\pwsh.exe"
##############################################################################################################################################
#Path to Powershell file to install:
#https://limerickcouncil.sharepoint.com/:u:/s/Projects/LITe_C.S.3.2-RECMNG-219/EYcdEWBROKFNt1dazT_o1l0BQOuzZOd2ToUKndH0jGx-bg?e=yO6KCe
#PnP Powershell module is required to run the scripts to install and import use the following commands, commands
#for PnP Powershell MUST be run within the Powershell 7.0+ console - The Install-Module command ONLY needs to be RUN ONCE
#TO DO Later: Set PSScriptRoot
#$PSScriptRoot  = Set-Location "E:\Powershell\SPO-Common" 
#"$PSScriptRoot\SGCommon.ps1"
##############################################################################################################################################
#IMPORTANT: Also ENSURE that all hard-coded file paths are replaced with the local paths you want (i.e. C:\Users\[joe.bloggs]\)
#Final NOTE IMPORTANT: When running the scripts below an interactive session method is used, a browser will open in 
#MS Edge (default browser), you MUST then select you administrator account to login and run the scripts, ensure that you admin account is active in PIM on Azure
#Prior to running these scripts migrate large files from the source site to Azure BLoB storage
#################################################################################################################################################################
#Step: Migrate all large files (not in including movie files) to Azure storage in the LARC folder format
# When running the script each subweb is process from a site collection, an excel file is available with a list of all webs
# You can also process/migrate large files PER subsite if required, use the excel file generated to get the web URL @
# E:\LCCC SPO Project\Scripts\[Site Name]_Webs.csv
# The large file script will also create .URL links to replace the original image or movie file and then temporarily remove the file to the recycle bin
######################Script to run the large file migration#####################################################################################################
#Start-Process -FilePath "$($Location)\Scripts\pwsh.exe" -ArgumentList "-noexit","-command cd '$($Location)'" -Wait
#$SetLocation        = "$($Location)\Scripts\"
#Set-Location $SetLocation -PassThru
#.\LCC_Invoke_AZCopy_LargeFile_Migration.ps1
#cls
#
# ---------------------------------------------------------------
# MODULE CHECK + INSTALL PROMPT
# ---------------------------------------------------------------
$RequiredModules = @("PnP.PowerShell", "Az.Storage")

foreach ($module in $RequiredModules) {
    if (!(Get-Module -ListAvailable -Name $module)) {
        Write-Host "Module '$module' is NOT installed." -ForegroundColor Yellow
        $answer = Read-Host "Install '$module' now? (Y/N)"

        if ($answer -match '^[Yy]$') {
            Install-Module -Name $module -Scope CurrentUser -Force
            Write-Host "'$module' installed." -ForegroundColor Green
        } else {
            Write-Host "Cannot continue without required module. Exiting." -ForegroundColor Red
            exit
        }
    }
}

Import-Module PnP.PowerShell -ErrorAction Stop
Import-Module Az.Storage    -ErrorAction Stop

Write-Host "`nModules loaded successfully." -ForegroundColor Green

# ---------------------------------------------------------------
# DRIVE SELECTION
# ---------------------------------------------------------------
Write-Host "`nWhich drive should be used for the project paths?" -ForegroundColor Cyan
$Drive = Read-Host "Enter C or E"

switch ($Drive.ToUpper()) {
    "C" { $DriveRoot = "C:" }
    "E" { $DriveRoot = "E:" }
    Default { Write-Host "Invalid drive. Exiting." -ForegroundColor Red; exit }
}

# ---------------------------------------------------------------
# DIRECTORY PREP
# ---------------------------------------------------------------
$Location        = "$DriveRoot\LCCC SPO Project"
$AzCopyExePath   = Join-Path $Location "Software"
$ScriptLocation  = Join-Path $Location "Scripts"

Write-Host "`nValidating project folder structure..." -ForegroundColor Cyan

# Base folder
if (!(Test-Path $Location)) {
    New-Item -ItemType Directory -Path $Location | Out-Null
    Write-Host "Created: $Location" -ForegroundColor Green
}

# AzCopy folder
if (!(Test-Path $AzCopyExePath)) {
    New-Item -ItemType Directory -Path $AzCopyExePath | Out-Null
    Write-Host "Created AzCopy folder: $AzCopyExePath" -ForegroundColor Green
}

# Scripts folder
if (!(Test-Path $ScriptLocation)) {
    New-Item -ItemType Directory -Path $ScriptLocation | Out-Null
    Write-Host "Created Scripts folder: $ScriptLocation" -ForegroundColor Green
}

Set-Location $ScriptLocation

Write-Host "`nFolder structure validated." -ForegroundColor Green
Read-Host "Press Enter to continue…"

#--------------------------------------------------------------------------------------------------
#START TRANSCRIPT
Start-Transcript -Append "$Location\LCC_SitePromo_Log.txt" -ErrorAction SilentlyContinue
# -------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------
# STEP RUNNER FUNCTION
# ---------------------------------------------------------------function Run-Step {function Run-Step {function Run-Step {
function Run-Step {   
param(
        [string]$StepName,
        [string]$ScriptPath
    )
    Write-Host "`n--- $StepName ---" -ForegroundColor Cyan
    $run = Read-Host "Run this step now? (Y/N)"

    if ($run -match '^[Yy]$') {
        if (Test-Path $ScriptPath) {
            Write-Host "Executing script: $ScriptPath" -ForegroundColor Yellow
            
            # The DOT and SPACE are critical to forward -tenant, -clientId, and -list
            . $ScriptPath @args 
            
            Write-Host "Step completed." -ForegroundColor Green
        } else {
            Write-Host "SCRIPT NOT FOUND: $ScriptPath" -ForegroundColor Red
        }
    } else {
        Write-Host "Skipped." -ForegroundColor DarkYellow
    }
    Read-Host "Press Enter to continue…"
}

# 2. Collect initial variables
$sitecoll       = Read-Host "Enter the relative path to the source site collection (e.g., /sites/tch)"

Read-Host "Press Enter to continue…"

# ---------------------------------------------------------------
# STEP 1 (PowerShell 7 prompts - manual step)
# ---------------------------------------------------------------

Write-Host "Step 1: Archives team to send out comms to the business unit requiring site promotion and ensure that the SPO Sites list has set dates.`n
for site promotion, see: `n https://limerickcouncil.sharepoint.com/Lists/SPOSites/Sitemap.aspx?viewid=8445dcfe%2D56f2%2D4c3f%2Db705%2D766f429a1ec2" -f y
Read-Host "Press Enter to continue…"

# ---------------------------------------------------------------
# STEP 2: Large File Migration (optional) (PowerShell 7 - script)
# ---------------------------------------------------------------

Write-Host "Step 2: Complete a large file migration from the source (i.e. Classic) site on SharePoint Online to Azure BLoB storage " -f y
Read-Host "Press Enter to continue…"

if ($runSG -match '^[Yy]$') {

Read-Host "Press Enter to continue…"

Run-Step -StepName "Step 2: Complete large file migration on site $($sitecollSG)" `
         -ScriptPath "$ScriptLocation\LCC_Invoke_AZCopy_LargeFile_Migration.ps1" 
}

# ---------------------------------------------------------------
# STEPS 3-4 (PowerShell 7 - script) - Manual steps
# ---------------------------------------------------------------

Write-Host "Step 3: Create the new site collection and migrate the content from the old root site using SPO central admin 
`n and then use Sharegate to migrate `n
Then copy a site homepage from a new modern promoted business unit (top-level) site to the new top-level site, and make it the homepage `n
Review the 'Services' list on the new top-level site and ensure that all sites are populated in the list `n
then apply the following JSON to the Services list view by selecting the View > Format view: https://dev.azure.com/LCCSPO/_git/LCCSPO?path=%2FPowershell%2FJSON%2FLCC_JSON_TopLevel_Unit_Sites.json&version=GBmain `n
Add the 'Services' list to the top-level site homepage, and set the JSON view `n
Finally, in central admin Register the top-level site as a Hub site `n" -f y
Read-Host "Press Enter to continue…"

Write-Host "Step 4: Place HTML banner for site promotion on source site, use:`n
'This site is currently being migrated. DO NOT edit or upload content until the site migration is complete. Thank-you!' `n
The banner is in the Azure DevOps repo under Images" -f y
Read-Host "Press Enter to continue…"

# --------------------------------------------------------------------
# STEPS 5: Undeclare on-hold records at source (PowerShell 7 - script)
# --------------------------------------------------------------------

Write-Host "Step 5: Run the permissions report in Sharegate against the source site" -f y
Read-Host "Press Enter to continue…"

Run-Step -StepName "Step 5: Undeclare Records" `
         -ScriptPath "$ScriptLocation\LCC_Invoke_UndeclareRecords_Retention.ps1" `
         -tenant "https://limerickcouncil.sharepoint.com" `
         -site $sitecoll `
         -clientId "ee225ff9-9a1f-4ed5-a5d9-1a8764e74d13" `
         -list "" `
         -filetype "File"    

# ----------------------------------------------------------------------------------------------------
# STEPS 6: EXPORT + CHECK SITE PROMO SCHEDULE (PowerShell 7 - script) + Complete Pre-Flight Steps
# ----------------------------------------------------------------------------------------------------
#Run function - replace the parameters below as needed, -list param should be "SPOSites"
Write-Host "Step 6: Export + Check Site Promotion Schedule (PnP) + Complete Pre-Flight Steps: `n Go to https://limerickcouncil.sharepoint.com/Lists/SPOSites/Sitemap.aspx?viewid=8445dcfe%2D56f2%2D4c3f%2Db705%2D766f429a1ec2  `n and ensure that the sites are scheduled for promotion today, `n the following fields should be completed: `n Status = Pending, Promotion Date = [Today], Assigned = [name_admin] (Use the name of your VM admin account)" -f y
Read-Host "Press Enter to continue…"
$SPOConfigArgs = @{
    tenant       = "https://limerickcouncil.sharepoint.com"
    clientId     = "[Az client app Id]"
    list         = "SPOSites" 
    sitecoll     = $sitecoll  
    contentype   = "Limerick Document" 
}

# Execute the step
Run-Step -StepName "Step 6: Export + Check Site Promotion Schedule (PnP)" `
         -ScriptPath "$ScriptLocation\LCC_Invoke_SPO_SitePromo_Config.ps1" `
         -FunctionName "Invoke-ConfigSite" `
         @SPOConfigArgs   

# ---------------------------------------------------------------
# STEP 7 – OPEN SHAREGATE POWERSHELL CONSOLE (PowerShell 7 - script)
# ---------------------------------------------------------------
Write-Host "`n--- STEP 7: EXECUTE SHAREGATE MIGRATION ---" -ForegroundColor Cyan
$runSG = Read-Host "Run ShareGate Migration now? (Y/N)"

if ($runSG -match '^[Yy]$') {
    # 1. Collect the migration mode
    
    # 2. Setup paths
    $ShareGateExe = "C:\Program Files (x86)\Sharegate\Sharegate.Shell.exe"
    $SGScript = Join-Path $ScriptLocation "LCC_Provision_Site_Promotion.ps1"

    if (!(Test-Path $ShareGateExe)) {
        Write-Host "ShareGate Shell not found at $ShareGateExe" -ForegroundColor Red
    } else {
        Write-Host "Launching ShareGate and executing $copyflag..." -ForegroundColor Yellow
        
        # 3. Build the command string. 
        # -noprofile in ArgumentList prevents the PSReadLine error in the 32-bit shell.
        $SGCommand = ". '$SGScript' -copyflag '$copyflag' -tenantprefix 'limerickcouncil' -tenant 'https://limerickcouncil-admin.sharepoint.com'"

        Start-Process -FilePath $ShareGateExe `
            -ArgumentList "-noprofile", "-noexit", "-command", $SGCommand `
            -Wait
            
        Write-Host "ShareGate step completed." -ForegroundColor Green
    }
}
Read-Host "Press Enter to continue…"

# ---------------------------------------------------------------
# STEP 8 A & B – POST SITE PROMO CONFIG
# ---------------------------------------------------------------

Write-Host "Step 8a: Post-Site Promotion Config on SharePoint Central Admin Site: `n Following site promotion complete tasks on the SharePoint Central admin site at: `n https://limerickcouncil-admin.sharepoint.com go to: `n Active Sites, choose the newly promoted site and `n A.) Set site size (100GB - this is dependent on the current size of the site), `n B.) Under the settings, enable site scripting on site temporarily, `n C.) Set site storage limit notification to 95% of quota" -f y
Read-Host "Press Enter to continue…"

Write-Host "Step 8b: Post-Site Promotion Config on newly promoted SharePoint Site: `n Following site promotion complete tasks on the promoted SharePoint site to: `n A.) Use ShareGate to create or import a modern site homepage - TopicHome.aspx from another newly promoted site, once Imported to the Site Pages library select it and 'Make Homepage', `n then add content to the homepage (i.e. File Plan list), the file plan list should use the WP View and the first field on the view should be Location URL, `n B.) Set site branding using green for Business sites, upload LCCC logo for the header, and set the following for the footer: `n ©2025 Limerick City and County Council" -f y
Read-Host "Press Enter to continue…"

#run function to check the schedule for site promotion on the SPO schedule list...
Run-Step -StepName "Step 8c: Post-Site Promotion Config" `
         -ScriptPath "$ScriptLocation\LCC_Invoke_Site_Promo_PostSite_Config.ps1" `
         -tenant "https://limerickcouncil.sharepoint.com" `
         -clientId "[Az client app Id]" `
         -list "SPOSites"

# ---------------------------------------------------------------
# STEP 9 – SITE CHECKS
# ---------------------------------------------------------------

Write-Host "Step 9: Site Checks and post-migration reports (i.e. Refer to the ShareGate site log), `n 
use the following checklist: https://limerickcouncil.sharepoint.com/:x:/r/sites/Projects/LITe_C.S.3.2-RECMNG-219/_layouts/15/Doc.aspx?sourcedoc=%7B090633EF-6C15-40BC-881F-E6A25CEC5825%7D&file=SPO_Checklist.xlsx&action=default&mobileredirect=true `n
and review errors" -f y
Read-Host "Press Enter to continue…"	

Write-Host "On the newly promoted site check if an 'Email' search vertical is required `n
On the newly promoted sites (if an email search vertical is required) go to Site Settings > Search Insights and Configuration > Under 'Verticals' select 'Add' > Enter the following: `n
Name: Email `n
Content Source – SharePoint `n
Query - ContentType:Email AND (filetype:msg or filetype:eml) `n
Add Filters `n
Email To – RefinableString100 `n
Email From – RefinableString101 `n
Email Subject – RefinableString102 `n
Email Has Attachments – RefinableString103 `n
Email Date Received – RefinableDate10 `n
`n
On the last screen toggle to select the 'State' to  'Enable' or 'On'`n" -f y
Read-Host "Press Enter to continue…"	

# ---------------------------------------------------------------
# STEP 10 – SITE INCREMENTAL MIGRATION
# ---------------------------------------------------------------

Write-Host "Step 10: Site fixes and incremental migration using ShareGate using the site promo logs `n
For incremental migrations (i.e. where there are errors in the ShareGate migration log re-run the Sharegate - previous step) `n
using the paramater to run an INCREMENTAL migration" -f y

Read-Host "Press Enter to continue…"

$incremental_confirm = Read-Host "Do you need to run an incremental migration due to errors in the site promotion (i.e. in the ShareGate logs)? (Y/N)"

if ($incremental_confirm -match '^[Yy]$') {

    $runSG = Read-Host "Open ShareGate PowerShell Console now? (Y/N)"

    if ($runSG -match '^[Yy]$') {

        Remove-Module PSReadLine -ErrorAction SilentlyContinue
        $ShareGateExe = "C:\Program Files (x86)\Sharegate\Sharegate.Shell.exe"

        if (!(Test-Path $ShareGateExe)) {
             Write-Host "ShareGate PowerShell console not found. Please install with Sharegate" -ForegroundColor Red
        } else {
             Write-Host "Starting ShareGate console..." -ForegroundColor Yellow

            Start-Process -FilePath $ShareGateExe `
                -ArgumentList "-noexit", "-command cd '$ScriptLocation'" `
                -Wait -PassThru

            Write-Host "`nWhen ShareGate opens, run:" -ForegroundColor Cyan
            Write-Host "cd `"$ScriptLocation`""
            Write-Host ".\LCC_Provision_Site_Promotion.ps1"
          }
    }
  Read-Host "Press Enter to continue…"
}

else{
    Write-Host "No additional incremental migration required..." -ForegroundColor Green
}

# ---------------------------------------------------------------
# STEP 11 – UPLOAD PERMISSIONS REPORT TO PROJECT SITE
# ---------------------------------------------------------------

Write-Host "Step 11: Upload site promotion log to the Project site `n (SPO Consultant folder >  Reports - see below) 
and complete site checks using the following spreadsheet (it will open in Edge): `n " -f y
Start-Process edge.exe -FilePath "https://limerickcouncil.sharepoint.com/sites/Projects/LITe_C.S.3.2-RECMNG-219/09%20SharePoint%20Architecture%20Build/Forms/AllItems.aspx?id=%2Fsites%2FProjects%2FLITe%5FC%2ES%2E3%2E2%2DRECMNG%2D219%2F09%20SharePoint%20Architecture%20Build%2FDigital%20SharePoint%20Consultant%202025%2FProject%20Reports&viewid=12a6e961%2D09e3%2D4943%2D9196%2D904eaeb2555f&p=true&ct=1754477053690&or=Teams%2DHL&ga=1&LOF=1"
Read-Host "Press Enter to continue…"

# ---------------------------------------------------------------------------
# STEP 12 - Exclude the old classic site collection from search and CoPilot
# ---------------------------------------------------------------------------

Write-Host "Step 12: Set Restrict CoPilot setting to 'On' in SharePoint Central Admin under `n
'Ative Sites' > ellipsis > settings, and on the classic sites under [site]/_layouts/15/srchvis.aspx select 'No' `n
to Allow items to appear in search results" -f y

# ---------------------------------------------------------------
# STEP 13 – SET SOURCE SITE TO READ-ONLY - SCRIPT
# ---------------------------------------------------------------

Write-Host "Step 13: Set source site to READ-ONLY" -f y

$sitestate = Read-Host "Enter the lock state of the site collection, enter either Unlock, NoAccess, ReadOnly"

Read-Host "Press Enter to continue…"	

Run-Step -StepName "Step 13: Set source site to READ-ONLY:" `
         -ScriptPath "$ScriptLocation\LCC_Invoke_Site_ReadOnly.ps1" `
         -tenant  "https://limerickcouncil.sharepoint.com" `
         -clientId "[Az client app Id]" `
         -sitecoll $sitecoll `
         -lockstate $sitestate

# ---------------------------------------------------------------
# STEP 14 – RUN SITE REPORT TO CLEAN NEWLY PROMOTED SITE - MANUAL
# ---------------------------------------------------------------

Write-Host "Step 14: Run a Site report in ShareGate under > 'PLAN' against the newly promoted site `n
#also when the report is run then complete cleaning of orphaned users and limited access `n
#sharing links are generally automatically expired when a site is promoted (i.e. by default)" -f y

Read-Host "Press Enter to continue…"	
 
# ---------------------------------------------------------------
# STEP 15 – NAVIGATION CHECKS
# ---------------------------------------------------------------
Write-Host "Step 15: Check Site Navigation - Set site navigation manually to display a File Plan, or run the populate site nav script LCC_InvokeNavigation.ps1 to re-build the site nav `n
#IMPORTANT: Update link to point to new site in navigation on portal @: `n
#https://limerickcouncil.sharepoint.com/sites/LITe/SitePages/Business.aspx `n
#and check any link on the Staff Portal @: https://limerickcouncil.sharepoint.com/ `n
Also ensure that the navigation on the site such as the File plan contains all sites in the correct order" -f y

# ---------------------------------------------------------------
# STEP 16 – ARCHIVE OLD/CLASSIC SITE - MANUAL STEP
# ---------------------------------------------------------------

Write-Host "Step 16: Archive site using M365/Azure backup, and delete classic site" -f y
Read-Host "Press Enter to continue…"

# ---------------------------------------------------------------
# STEP 17 – PURVIEW FILE PLAN IMPORTS - MANUAL STEP
# ---------------------------------------------------------------

Write-Host "Step 17A: Import CSV of file plan for new site to MS Purview, create and apply records management `n policies (auto-apply) 
dynamically, then publish them to the new SPO site `n (Auto-apply can take up to 7 days to propagate to the SPO site)" -f y 

Read-Host "Press Enter to continue…"

Write-Host "Step 17B: Ensure that all file plans have been signed-off prior to publishing to the newly promoted site " -f w

$runSG = Read-Host "Have all file plans and records policies been signed off for the newly promoted site? (Y/N)"

if ($runSG -match '^[Yy]$') {

    Write-Host "The file plan has been signed off for site $($)" -f Green
    Read-Host "Press Enter to continue…"
}

else{
    Write-Host "" -f r
}

# ---------------------------------------------------------------
# STEP 18 – RECORDS MANAGEMENT VIEWS
# ---------------------------------------------------------------
Write-Host "Step 18: Verify that the records management views are on the site" -f y

Run-Step -StepName "Step 18: RM Views + Disposition Setup" `
         -ScriptPath "$ScriptLocation\LCC_Invoke_RMView.ps1" `
         -clientId "[Az client app Id]" `
         -tenant "https://limerickcouncil.sharepoint.com" `
         -sitecoll $sitecoll `
         -dispositionlist "Disposition"      
         
# -----------------------------------------------------------------------------------
# STEP 19 – Enable the Azure Storage Lifecycle Policy for files in Azure storage
# -----------------------------------------------------------------------------------
Write-Host "Step 19: Login to Azure with your PIM enabled 365 account `n
and then go to the storage container spormpoc then under 'Data Management' > 'Lifecycle Management' `n
'Enable' any 'Delete' policy required on Azure storage content `n
Only do this once a delete policy has been published and applied from Purview to the newly promoted site `n
In this way content in Azure will be cleaned up in line with any Purview policy" -f y

# ---------------------------------------------------------------
# STEP 20 – INCREMENTAL MIGRATION
# ---------------------------------------------------------------
		 
Write-Host "Step 20: Run any additional migration after the site owner has been contacted or staff start `n using the site. Only migrate specific items, and DO NOT overwrite structure or `n lists/libraries on new sites" -f Green
Read-Host "Press Enter to continue…."

# ---------------------------------------------------------------
# END
# ---------------------------------------------------------------

Write-Host "`n All steps complete or skipped as per user selection." -ForegroundColor Green
Write-Host "Script finished." -ForegroundColor Cyan

Stop-Transcript 