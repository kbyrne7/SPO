# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # ########################
# AZCopy file to audit files from SPO
# To run this script use Powershell v.7.0+ (as a minimum) with PnP powershell module installed
# When the pwsh (powershell command line opens) ensure that you CD to your local powershell folder, if not already done
# IMPORTANT: Then run this file using .\LCC_Invoke_AZCopy_LargeFile_Migration.ps1
# Finally, ensure that you add all parameters in the function, for client ID, tenant prefix, tenant, site and list
# And ensure that your AZ PIM admin account (if PIM is used) has access on the BLOB Storage container and SPO
## # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # ################
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # ################
#Standard file types to process: 
#Jpg|jpeg|png|gif|bmp|bak|bkp|exe|tif|tiff|heic|heif|ai|pst|zip|las|asc|odp|dbf|msi|sql|psd|mdb|php|dwg|hta|tmp|ini|bat|html|htm|js|ps1
########################################################################################################################################
#Unblock the script to run
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # ########################

function Invoke-SPOAzCopyOneLevel {
    [CmdletBinding()]
    Param(
        [string]$clientid,
        [string]$tenant,     
        [string]$sitecoll,
        [string]$sitetypeflag
    )

    begin {
        #Modules used in this script...
        Import-Module PnP.PowerShell -ErrorAction Stop

        #Define global vars
        $drive           = (get-location).Drive.Name

        $StartLocation   = "\Users\kbyrne\Documents\Project\SPO Audit"
        $ScriptLocation  = "\Users\kbyrne\Documents\Project\Scripts"
        
        if (!(Test-Path -Path $StartLocation)) {

            write-host "Creating a Project folder @ $($StartLocation)" -f y

            New-Item -ItemType Directory -Path $StartLocation

            write-host "Created a Project folder" -f Green

            if (!(Test-Path -Path $ScriptLocation)) {

                write-host "Creating a Project Scripts folder, ensure that all site audit scripts are stored in $($ScriptLocation)" -f y

                New-Item -ItemType Directory -Path $ScriptLocation  
                
                write-host "Created a Project Scripts folder at $($ScriptLocation). NOTE that all site audit scripts should be stored here" -f Green
            }                  
        }
        
    Write-Host "Provide the following details to audit all files, be sure to enter details in the format specified " -f y

    #$sitecoll            = Read-Host "Enter the relative path to the site to migrate from (i.e. use format /sites/tch/)"

    Write-Host "Auditing all sites, libraries and files " -f y
    $fileexts           = "Jpg|jpeg|png|gif|bmp|docx|doc|pptx|ppt|pdf|xlsx|xls"
    #$ListNameToProcess = Read-Host "Enter a list name or title to archive content from (i.e. Administration (001)) and send to storage?"

    #Set the local location for processing
    Set-Location "$($StartLocation)\" -ErrorAction SilentlyContinue
    }

    process { 

    Start-Transcript -Append "$StartLocation\Site_Audit_Log.txt" -ErrorAction SilentlyContinue
    
    # Initial Tenant Connection
    $Connection = Connect-PnPOnline -Url $tenant -ClientId $clientid -Interactive -ReturnConnection -ErrorAction Stop

    # Get Sites and Export to Sites.csv
    $outputPath = "$($StartLocation)\Sites.csv"
    $subWebs = Get-PnPTenantSite -Detailed -Connection $Connection -ErrorAction SilentlyContinue 
    
    $exportData = foreach($site in $subWebs) {
            $sitesizeRaw     = if ($site["StorageUsage"]) { [int64]$site["StorageUsage"] } else { 0 }
        [PSCustomObject]@{
            SiteName         = $site.Title            
            SiteURL          = $site.Url
            SiteOwner        = $site.Owner
            LastModifiedDate = $site.LastContentModifiedDate
            WebCount         = $site.WebsCount
            TemplateType     = $site.Template
            StorageinMB      = [math]::Round(($sitesizeRaw / 1MB), 2)
            IsSubSite        = $sitetypeflag
        }
    }
    $exportData | Export-Csv -Path $outputPath -NoTypeInformation

    # Process the CSV rows for File Audit
    $rows = Import-Csv $outputPath
    $exportFileData = @() 

    foreach($row in $rows) {
        if($row.IsSubSite -eq $sitetypeflag) {
            Write-Host "Connecting to Site: $($row.SiteURL)" -f Cyan
            
            # FIX 1: Must connect to the specific site URL to see its libraries
            $subConn = Connect-PnPOnline `
            -Url $row.SiteURL `
            -ClientId $clientid `
            -Interactive `
            -PersistLogin `
            -ReturnConnection `
            -ErrorAction Stop
            
            # FIX 2: Get libraries directly from the sub-connection
            $lists = Get-PnPList -Connection $subConn | Where-Object { $_.BaseTemplate -eq 101 -and $_.Hidden -eq $false }

            foreach ($list in $lists) {
                Write-Host "  Scanning Library: $($list.Title)" -f Yellow

                #Get All Columns from List
                #Get-PnPField -List $list.Title -Connection $subConn

                $items = Get-PnPListItem -List $list.Title -PageSize 500 -Connection $subConn -Fields "FileRef","FileLeafRef","SMTotalFileStreamSize","Modified","Editor","Created","Author", "TypeDisplayName"

                $extArray = $fileexts.Split('|')

foreach ($item in $items) {
    # FIX: Skip if it's NOT a file (skip folders)
    if ($item.FileSystemObjectType -ne "File") { continue }

    $fileName  = $item["FileLeafRef"]
    $isMatched = $false
    
    # Check against extensions
    foreach ($ext in $extArray) {
        if ($fileName -like "*.$ext") {
            $isMatched = $true
            break 
        }
    }

    if ($isMatched) {
        # Safe retrieval of metadata to prevent silent failures
        $authorEmail = if ($item["Author"]) { $item["Author"].Email } else { "N/A" }
        $editorEmail = if ($item["Editor"]) { $item["Editor"].Email } else { "N/A" }
        $sizeRaw     = if ($item["SMTotalFileStreamSize"]) { [int64]$item["SMTotalFileStreamSize"] } else { 0 }

        $exportFileData += [PSCustomObject]@{
            SiteURL             = $row.SiteURL
            Library             = $list.Title
            FileName            = $fileName
            FileRef             = $item["FileRef"]
            SizeMB              = [math]::Round(($sizeRaw / 1MB), 2)
            Modified            = $item["Modified"]
            ModifiedBy          = $editorEmail
            Created             = $item["Created_x0020_Date"]
            CreatedBy           = $authorEmail
            TypeofFile          = $item["File_x0020_Type"] 
        }
        Write-Host "    Added: $fileName" -ForegroundColor Green
        }
       }           
      }
     }
    }

    # FIX 4: Write the File Log CSV
    if ($exportFileData) {
        $finalLogPath = "$($StartLocation)\FileLog_Audit.csv"
        $exportFileData | Export-Csv -Path $finalLogPath -NoTypeInformation
        Write-Host "SUCCESS: Audit log created at $finalLogPath" -f Green
    }
  }
}

#Invoke fnc - leave subsite param empty if it does not exist
Invoke-SPOAzCopyOneLevel `
    -clientid "2d58f493-fcc4-473b-863b-e92800bfc0e0" `
    -tenant "https://printricityspo.sharepoint.com/" `
    -sitecoll "" `
    -sitetypeflag "False"

Stop-Transcript