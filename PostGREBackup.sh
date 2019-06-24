#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/root/bin:/bin

#Status message that will be used on the e-mails's subject
STATUSMESSAGE="Desconhecido"
# Destination folder configuration
DESTINATIONFOLDER="/root/backupspostgre"
DESTINATIONNAMEFORMAT="mercury_"$(date +%Y-%m-%d_%H%M)
# Temp folder configuration
TEMPFOLDERFORBACKUP="/root/psqlBackupTemp"
# Logs configuration
LOGFOLDERTARGET="$DESTINATIONFOLDER\/logs"
LOGFILETEMP=$($(which mktemp))
LOGFINALNAME="$LOGFOLDERTARGET\/log_"$(date +%Y-%m-%d_%H%M)".txt"
#PostgreSQL connection details
PSQLHOST='10.0.0.106'
PSQLUSER='postgres'
PSQLPASSWORD='2QfgRBtQzqWijRab'
PSQLPORT='5432'
# Email details
MAILLOGSRECIPIENT="daniel@smartsupport.com.br"
MAILSENDBCCRECIPIENT="logs@smartsupport.com.br"
MAILLOGSUBJECT="Log de backup - $(date +%Y-%m-%d_%H%M) Status:"
# Install mailx and configure the below parameter in /etc/mail.rc
#set smtp=smtp://smtp.server.tld:port_number
# tell mailx that it needs to authorise
#set smtp-auth=login
# set the user for SMTP
#set smtp-auth-user=user@domain.tld
# set the password for authorisation
#set smtp-auth-password=PASSWORD
#set the FROM address. it's needed for some servers
#set from="notificacoes@sro.org.br"

#Send a message function
function sendMessageByEmail () {
	mail -s "$MAILLOGSUBJECT $simpleSTATUSMESSAGE" -b "$MAILSENDBCCRECIPIENT" "$MAILLOGSRECIPIENT" < $LOGFILETEMP
}

#Validating destination folder. If it not exists, send an e-mail
if [ ! -d $DESTINATIONFOLDER ]; then	
	simpleSTATUSMESSAGE="Erro!"
	echo "Pasta de destino nao encontrada" >> $LOGFILETEMP
	sendMessageByEmail
	exit 1
fi

#Check if the destination folder is writable
if [ -w $DESTINATIONFOLDER/testFile ]; then	
	simpleSTATUSMESSAGE="Erro!"
	echo "Nao foi possivel escrever dados na pasta de destino" >> $LOGFILETEMP	
	sendMessageByEmail
	exit 1
fi

#Check if the temp folder is writable
if [ -w $TEMPFOLDERFORBACKUP/testTempFile ]; then
	simpleSTATUSMESSAGE="Erro!"
	echo "Nao foi possivel escrever dados na pasta temporaria" >> $LOGFILETEMP	
	sendMessageByEmail
	exit 1
fi

#Try to backup the data
echo "$PSQLHOST:$PSQLPORT:*:$PSQLUSER:$PSQLPASSWORD" > ~/.pgpass; chmod 0600 ~/.pgpass
psqlDatabases=$(psql -h $PSQLHOST -p $PSQLPORT -U $PSQLUSER -d postgres -q -t -c 'SELECT datname from pg_database')

for db in $psqlDatabases
do   
	 if [ "$db" == 'template0' ]; then
		continue
	 fi
	 echo "Realizando backup do banco $db...." >> $LOGFILETEMP
     pg_dump -U postgres $db > $TEMPFOLDERFORBACKUP/"$db".dump
	 if [[ $? == 0 ]]; then
		echo "Backup do banco $db realizado com sucesso. Continuando" >> $LOGFILETEMP
	 else
		echo "Backup do banco $db com erro. Abortando a copia" >> $LOGFILETEMP
		simpleSTATUSMESSAGE="Erro!"
		sendMessageByEmail
		exit 1
	 fi
done

#Compress all dumps

for db in $psqlDatabases
do
	if [ "$db" == 'template0' ]; then
		continue
	fi
	zip -m $DESTINATIONFOLDER/"$DESTINATIONNAMEFORMAT-$db.zip" $TEMPFOLDERFORBACKUP/"$db".dump
	if [[ $? == 0 ]]; then
		echo "Compactacao do banco $db realizado com sucesso. Continuando" >> $LOGFILETEMP
	 else
		echo "Compactacao do banco $db com erro. Abortando" >> $LOGFILETEMP
		simpleSTATUSMESSAGE="Erro!"
		sendMessageByEmail
		exit 1
	 fi
done


#Perform maintenance operations
psql -h $PSQLHOST -p $PSQLPORT -U $PSQLUSER -d postgres -q -t -c 'VACUUM ANALYSE'
if [[ $? == 0 ]]; then
	echo "Otimização dos bacos $db realizado com sucesso. Continuando" >> $LOGFILETEMP
else
	echo "Otimizacao com falha. Verificar" >> $LOGFILETEMP
	simpleSTATUSMESSAGE="Erro!"
	sendMessageByEmail
fi
echo "Todas as operacoes concluidas com sucesso! Copia finalizada" >> $LOGFILETEMP
simpleSTATUSMESSAGE="Sucesso!"
sendMessageByEmail

#Cleanup

rm -rfv $TEMPFOLDERFORBACKUP/*
rm -rfv $LOGFILETEMP
