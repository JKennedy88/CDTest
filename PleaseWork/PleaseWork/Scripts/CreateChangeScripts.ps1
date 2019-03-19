$sqlCompareDIR = "C:\Program Files (x86)\Red Gate\SQL Compare 13\"
cd $sqlCompareDIR

$sourceServer ="(local)"
$destinationServer = "masterclone-cpt"


$changeScriptDirectory = "C:\ChangeScripts"
$changeScriptDirectoryTemp = "C:\ChangeScripts\temp"

$changeScriptDirectoryExists = Test-Path $changeScriptDirectoryTemp

 if(-Not ($changeScriptDirectoryExists))
 {
     try
    {
        Write-Host Creating Change Scripts directory...
        New-Item -ItemType directory -Path $changeScriptDirectoryTemp

        Write-Host Change Scripts directory created succesfully...
    }
    catch
    {
        Write-Error $Error[0].Exception.Message -ErrorAction Stop
    }

 }


 function Invoke-SQL {
     param(
        [string] $dataSource = ".\SQLEXPRESS",
        [string] $database = "MasterData",
        [string] $sqlCommand = $(throw "Please specify a query.")

      )

    $connectionString = "Data Source=$dataSource; " +
            "Integrated Security=SSPI; " +
            "Initial Catalog=$database"

    $connection = new-object system.data.SqlClient.SQLConnection($connectionString)
    $command = new-object system.data.sqlclient.sqlcommand($sqlCommand,$connection)
    $connection.Open()

    $adapter = New-Object System.Data.sqlclient.sqlDataAdapter $command
    $dataset = New-Object System.Data.DataSet
    
    $adapter.Fill($dataSet) | Out-Null

    $connection.Close()
    $dataSet.Tables
}

    $command =  "dbo.spGetBuildOrder"

    $buildOrder = Invoke-SQL -dataSource $sourceServer -database "DatabaseCI" -sqlCommand $command

    foreach($database in $buildOrder)
    {
        $databaseName = $database.Item("vchDatabaseName")

        $getChangeScriptIDSQL = "select dbo.fnGetMaxChangeScriptID('"+$databaseName+"') as MaxChangeScriptID"
        $getChangeScriptID = Invoke-Sqlcmd -Query $getChangeScriptIDSQL -ServerInstance $sourceServer -Database "DatabaseCI"

        [int]$getChangeScriptIDInt = $getChangeScriptID.MaxChangeScriptID + 1
        [int]$getNextChangeScriptIDInt = $getChangeScriptIDInt + 1

        $changeScriptName = $databaseName+"_ChangeScript_#" + $getChangeScriptIDInt + "_to_#" + $getNextChangeScriptIDInt + ".sql"

        try{

            $checkDBExistsSQL = "select database_id from sys.databases where [name] = '$databaseName'"            
            $checkDBExistsOnDestination =  @(Invoke-Sqlcmd -Query $checkDBExistsSQL -ServerInstance $destinationServer -Database "master")

            if($checkDBExistsOnDestination.Count -eq 0)
            {
                Write-Warning -Message "Database $databaseName does not exist on $destinationServer"

            }
            else
            {
                $isIdentical = ./sqlcompare /server1 $sourceServer /database1 $databaseName /server2 $destinationServer /database2 $databaseName /AssertIdentical 
                if($LASTEXITCODE -eq 0)
                {
                    Write-host $databaseName is identical on $sourceServer and $destinationServer -ForegroundColor Green
                }
                else 
                {
                


                     $changeScriptFullPath = "$changeScriptDirectoryTemp\$changeScriptName"
                     Write-Host "Creating change script $changeScriptName..."
                     $createChangeScript = ./sqlcompare /server1 $sourceServer /database1 $databaseName /server2 $destinationServer /database2 $databaseName /Options:"Default,AddDatabaseUseStatement,DoNotOutputCommentHeader" /scriptFile:$changeScriptFullPath /LogLevel:Verbose
                     if(Test-Path $changeScriptFullPath)
                     {

                        $doesExist = 0
                        $existingChangeScripts = Get-ChildItem -Path $changeScriptDirectory *.sql  | select FullName
                        foreach($changeScript in $existingChangeScripts)
                        {
                            $changeScriptFullName =  $changeScript.FullName
                            $scriptAlreadyExists =  @(Compare-Object -ReferenceObject $(Get-Content $changeScriptFullPath) -DifferenceObject $(Get-Content $changeScriptFullName))
                            if($scriptAlreadyExists.Count -eq 0)
                            {
                                Write-Host "$changeScriptName is the same as an existing change script , $changeScriptFullName . $changeScriptName will not be created"
                                Remove-Item $changeScriptFullPath
                                $doesExist = 1
                                break
                            }
                                                                
                        }
                 
                        if($doesExist -eq 0)
                        {
                               
                            $insertChangeScriptSQL = "exec spInsertChangeScriptHistory " + "'"+$databaseName+"'" + "," + $getChangeScriptIDInt + "," + "'" + $changeScriptName + "'"
                            $insertChangeScript = Invoke-Sqlcmd -Query $insertChangeScriptSQL -ServerInstance $sourceServer -Database "DatabaseCI"
                            Move-Item -Path $changeScriptFullPath -Destination "$changeScriptDirectory\$changeScriptName"
                            Write-Host Change Script $changeScriptName successfully created...
                        }
                    
                     }
                     else
                     {
                        Write-Error -Message "There are changes for database $databaseName, however an error occurred in creating the change script. Please consult logs at %localappdata%/Red Gate/Logs/SQL Compare/"
                     }
                }
            }
        }
        catch
        {
            Write-Error $Error[0].Exception.Message
        }

    }
