$NetworkPath = "\\10.15.20.160\AD Logs"
$FolderPath = "DHCP01"
$DHCPSvrName = "PROD-DHCP01.hnbfinance.lk"
$Console = $true

$Date= Get-Date -Format "MM-dd-yyyy"
net use * $NetworkPath /user:PTP-PR-QNAP04\adlogbackupadmin "2r&smeL@P5Z_jDX%"
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

if (!(Test-Path "C:\Windows\Temp\DHCP\Backup")) {
    New-Item "C:\Windows\Temp\DHCP\Backup" -ItemType Directory
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
            Backup-DhcpServer -ComputerName $DHCPSvrName -Path "C:\Windows\Temp\DHCP\Backup"
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

        #Compress backed up files
        try{
            Compress-Archive -Path "C:\Windows\Temp\DHCP\Backup\*" -DestinationPath "C:\Windows\Temp\DHCP\dhcp-backup-$Date.zip" -Update
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

        #Hasinh the compresed source file 
        try{
            $SourceFileHash = (Get-FileHash "C:\Windows\Temp\DHCP\dhcp-backup-$Date.zip" -Algorithm "MD5").Hash
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
                Remove-Item -Path "C:\Windows\Temp\DHCP\Backup" -Recurse
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
                Remove-Item -Path "C:\Windows\Temp\DHCP\Backup" -Recurse
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


    
