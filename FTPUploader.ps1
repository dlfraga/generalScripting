#Script que lê arquivo PSV [Pipe separared Values =P] e os processa. Esse arquivo está no formato:
#Caminho completo do arquivo | Status do arquivo (se ele existe, OK, se não, fail)
#c:\pasta\arquivo.xxx|OK
#Esse script requer o programa PSFTP.exe. pelo menos uma conexão deve ser feita manualmente antes de usar o script, para que a chave seja aceita no prompt. 

$arquivosEncontrados = "$PSScriptRoot\resultados.txt"
$cabecalhosCSV = 'CaminhoDoArquivo', 'statusDoArquivo'
$dadosLidosCSV = Import-CSV -Delimiter "|" -Path $arquivosEncontrados -Header $cabecalhosCSV
$lineCount = $dadosLidosCSV | Measure-Object | Select-Object -expand count
#Relatório do script, nos permite revisar depois se houve algum problema. 
$relatorioDeTransferencia = "$PSScriptRoot\relatorioFTP.txt"
$PSFTPath = 'C:\Users\Administrator\psftp.exe'
$FTPsHost = ''
$FTPsPort = 22  #Nao utilizado por enquanto
$FTPsLogin = ''
$FTPsPassword = ''

$currentFileCount = 0

foreach ($linha in $dadosLidosCSV) {
        $arquivoAtual = $linha.CaminhoDoArquivo
        $statusArquivoAtual = $linha.statusDoArquivo
		#Contador para mostrar o status do processo
        $currentFileCount = $currentFileCount + 1

        Write-Progress -Activity "Verificando arquivos" -Status "Verificando arquivo $arquivoAtual.CaminhoDoArquivo - Total: $lineCount" -PercentComplete (($currentFileCount / $lineCount)*100)

        if ($statusArquivoAtual -icontains "OK" ){
				#O PSFTP funciona com comandos que devem estar salvos em um arquivo. Então criamos um arquivo temporario para colocarmos os comandos dentro
                $tmp = [System.IO.Path]::GetTempFileName()				
                $PSFtpComandos = "put $arquivoAtual"
                $PSFtpComandos = $PSFtpComandos + "`n" + "quit"                				
                Add-Content -Value $PSFtpComandos -Path $tmp				
				#Neste ponto o arquivo temporario deve conter o comando de upload mais a linha de desconexão. 
				#Realiza o upload e salva o retorno do comando em uma variavel para checagem posterior.
                $FTPsUpload = Start-Process -Wait -windowstyle Hidden -PassThru -FilePath $PSFTPath -ArgumentList "-l $FTPsLogin -pw $FTPsPassword $FTPsHost -b $tmp -be"				
                Remove-Item $tmp
                if ($FTPsUpload.ExitCode -ne 0){
                    Write-Host -ForegroundColor Red "Erro ao realizar upload do arquivo $arquivoAtual"
                    Add-Content -Path $relatorioDeTransferencia -Value "$arquivoAtual|Erro"
                } else {
					Write-Host -ForegroundColor Green "Upload do $arquivoAtual realizado"
                    Add-Content -Path $relatorioDeTransferencia -Value "$arquivoAtual|Enviado"
                }                
        } else {
                Write-Host -ForegroundColor Yellow "Arquivo $arquivoAtual nÃ£o encontrado no sistema de arquivos. Ignorando"
                Add-Content -Path $relatorioDeTransferencia -Value "$arquivoAtual|NaoEncontrado"
         }

}