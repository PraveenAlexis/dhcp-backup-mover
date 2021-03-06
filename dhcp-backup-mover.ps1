$NetworkPath = "\\127.0.0.1\sharefolder"
$TempDirPath = "C:\Windows\Temp\DHCP\Backup"
$FolderPath = "" # folder which will contain DHCP backups
$DHCPSvrName = "" #dhcp server name, this should be ip or full domain name
$Console = $true #enable/disable console outputs

$Date= Get-Date -Format "MM-dd-yyyy"
net use * $NetworkPath /user:domain\user "password"
$DriveLetter = (Get-PSDrive | Where-Object { $_.DisplayRoot -eq $NetworkPath }).root

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]$Message,
 
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('INFO','WARN','ERROR')]
        [String]$Severity = 'INFO'
    )

    if(!(Test-Path "$DriveLetter$FolderPath\Logs")){
        New-Item "$DriveLetter$FolderPath\Logs" -ItemType Directory
    }
    $Time = (Get-Date -f g)
    Add-Content $DriveLetter$FolderPath\Logs\dhcp-backup-log-$Date.txt [$Severity]:$Time": "$Message

    if($Console){
        Write-Host $Message
    }
 }

if (!(Test-Path "$TempDirPath")) {
    New-Item "$TempDirPath" -ItemType Directory
}

if ([System.IO.Directory]::Exists($DriveLetter)) {

    if (!(Test-Path "$DriveLetter$FolderPath")) {
        New-Item "$DriveLetter$FolderPath" -ItemType Directory
    }

    Write-Log -Message "Drive Mapped: $DriveLetter" -Severity INFO

    if (Test-Path ($DriveLetter + $FolderPath)) {

        Write-Log -Message "Path Exists: $DriveLetter$FolderPath" -Severity INFO
        #Backup the DHCP server
        try{
            Backup-DhcpServer -ComputerName $DHCPSvrName -Path "$TempDirPath"
        }
        catch{
            Write-Log -Message "DHCP Backup Error: $_" -Severity ERROR
        }
        finally{
            Write-Log -Message "DHCP Backup Running" -Severity INFO
        }
        if($?){
            Write-Log -Message "DHCP Backup Sucessfull" -Severity INFO
        }

        #Archive backed up files
        try{
            Compress-Archive -Path "$TempDirPath\*" -DestinationPath "C:\Windows\Temp\DHCP\dhcp-backup-$Date.zip" -Update
        }
        catch{
            Write-Log -Message "Archiving Backup Error: $_" -Severity ERROR
        }
        finally{
            Write-Log -Message "Archiving Backup" -Severity INFO
        }
        if($?){
            Write-Log -Message "Archiving Backup Sucessfull" -Severity INFO
        }

        #Hashing the archived source file 
        try{
            $SourceFileHash = (Get-FileHash "C:\Windows\Temp\DHCP\dhcp-backup-$Date.zip" -Algorithm "MD5").Hash
        }
        catch{
            Write-Log -Message "Hashing Source File Error: $_" -Severity ERROR
        }
        finally{
            Write-Log -Message "Hashing Source File" -Severity INFO
        }
        if($?){
            Write-Log -Message "Hashing Source File Sucessfull" -Severity INFO
        }

        #Copying the backed up file to the destination
        try{
            Copy-Item -Path "C:\Windows\Temp\DHCP\dhcp-backup-$Date.zip" -destination ($DriveLetter + $FolderPath)
        }
        catch{
            Write-Log -Message "Copying Backup Error: $_" -Severity ERROR
        }
        finally{
            Write-Log -Message "Copying Backup" -Severity INFO
        }
        if($?){
            Write-Log -Message "Copying Backup Sucessfull" -Severity INFO
        }

        #Hashing the copied file
        try{
            $DestFileHash = (Get-FileHash  ($DriveLetter + $FolderPath+"\dhcp-backup-$Date.zip") -Algorithm "MD5").Hash
        }
        catch{
            Write-Log -Message "Hashing Destination File Error: $_" -Severity ERROR
        }
        finally{
            Write-Log -Message "Hashing Destination File" -Severity INFO
        }
        if($?){
            Write-Log -Message "Hashing Destination File Sucessfull" -Severity INFO
        }

        #check if hashes are matching
        #if matched delete the source backup
        if($SourceFileHash -eq $DestFileHash){
            Write-Log -Message "Hash Compare Running"
            try{
                Remove-Item -Path "$TempDirPath" -Recurse
            }
            catch{
                Write-Log -Message "Deleting Backup Error: $_" -Severity ERROR
            }
            finally{
                Write-Log -Message "Deleting Backup"
            }
            if($?){
                Write-Log -Message "Hash Compare Sucessfull"
                Write-Log -Message "Deleting Source Backup Sucessfull" -Severity INFO
            }
        }

        #if not delete the source backup and log the error
        else{
            try{
                Remove-Item -Path "$TempDirPath" -Recurse
            }
            catch{
                Write-Log -Message "Deleting Backup Error: $_" -Severity ERROR
                Write-Log -Message "ERROR Coping: dhcp-backup-$Date.zip" -Severity ERROR
            }
            finally{
                Write-Log -Message "Hash Compare Failed"
            }
            if($?){
                Write-Log -Message "Deleted Source Backup Sucessfull" -Severity INFO
            }
            
        }
        
        Write-Log -Message "Backup Finished" -Severity INFO
        net use * /delete /y
    }
    else{
        Write-Log -Message "Path Does Not Exist" -Severity ERROR
        net use * /delete /y
    }
}
else{
    Write-Log -Message "Drive Not Mapped" -Severity ERROR
    net use * /delete /y
}


    
