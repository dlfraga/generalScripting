$diasBkpDiario = 8
$diasBackupMensal = 365

function deleteOldFiles  {
$path = $args[0] 
$daysToDelete = '-' + $args[1]

Get-ChildItem -Recurse -Path $path -File | 
Where-Object { 
 $_.CreationTime -lt (Get-Date).AddDays($daysToDelete) 
} | 
    Remove-Item -Force -Verbose
}


deleteOldFiles Q:\BKP-RotinaDiaria $diasBkpDiario
deleteOldFiles Q:\BKP-RotinaMensal $diasBackupMensal

