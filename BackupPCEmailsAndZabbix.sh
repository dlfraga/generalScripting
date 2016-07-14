#!/bin/bash
#USAGE: Change the ConfPostUserCmd on backuppc config to this script location, like the line below:
#$Conf{DumpPostUserCmd} = '/etc/BackupPC/email.sh $xferOK $host $type $client $hostIP $share $XferMethod $sshPath $cmdType';
#Script based on https://gopukrish.wordpress.com/2014/01/22/get-notification-after-every-successful-backup-from-backuppc/

PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/opt/dell/srvadmin/bin:/opt/dell/srvadmin/sbin:/root/bin"
EMAIL='user@host.com'
EMAILBCC='userbcc@host.com'
TEMPFILE=$(mktemp)
# Email text/message
STATUS="Status desconhecido, verificar rotina!"
# Grab the status variables
xferOK=$1
host=$2
type=$3
client=$4
hostIP=$5
share=$6
XferMethod=$7
sshPath=$8
cmdType=$9

# Check if backup succeeded or not.
if [[ $xferOK == 1 ]]; then
        STATUS="SUCESSO"
        /usr/bin/ssh root@127.0.0.1 "/usr/bin/zabbix_sender -c /etc/zabbix/zabbix_agentd.conf -k backup.status -o 1"
else
        STATUS="FALHA"
        /usr/bin/ssh root@127.0.0.1  "/usr/bin/zabbix_sender -c /etc/zabbix/zabbix_agentd.conf -k backup.status -o 0"
fi

# email subject
SUBJECT="[BackupPC] $STATUS para o host: $client"

# Email text/message

echo -e "Rotina do sistema de backup concluida com $STATUS \n
Dados adicionais: " > $TEMPFILE
echo "" >> "$TEMPFILE"
echo "Tipo: $type" >> "$TEMPFILE"
echo "Cliente: $client" >> "$TEMPFILE"
echo "Host: $host" >> "$TEMPFILE"
echo "Host IP: $hostIP" >> "$TEMPFILE"
echo "Compartilhamento: $share" >> "$TEMPFILE"
echo "Metodo de transferencia: $XferMethod" >> "$TEMPFILE"

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

mail -s "$SUBJECT" -b "$EMAILBCC" "$EMAIL"< $TEMPFILE
rm $TEMPFILE

