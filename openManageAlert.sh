#!/bin/bash
ALERT_TYPE=$1
SEND_NOTIFICATION_TO=""
MAIL_BIN=$(which mail)
ZABBIX_SENDER_BIN=$(which zabbix_sender)
ZABBIX_CONFIG_FILE=""
HOSTNAME_BIN=$(which hostname)
HOSTNAME="$($HOSTNAME_BIN)"
EMAIL_SUBJECT="Erro no openmanage do servidor "$HOSTNAME" tipo: "$ALERT_TYPE""
EMAIL_BODY="Erro no servidor detectado."
ZABBIX_KEY="openmanage.status"
RM_BIN=($which rm)
TEMPFILE=$(mktemp)
OMCONFIG_BIN=($which omconfig)
EVENT_LIST=""
PS_BIN=$(which ps)
GREP_BIN=$(which grep)
AWK_BIN=$(which awk)
SED_BIN=$(which sed)
CUT_BIN=$(which cut)
ZABBIX_MESSAGE="Alerta no openmanage: $1"
ZABBIX_RESET_MESSAGE="Servidor reiniciado: Trigger resetada"


function configureOpenManage(){
	if [ -z "$OMCONFIG_BIN" ] ; then
	        echo "OMCONFIG NOT FOUND!"
	else
	        EVENT_LIST=$($OMCONFIG_BIN system alertaction | $CUT_BIN -d'<' -f2| $SED_BIN s'/|/\n/'g| $SED_BIN s'/>//'g| $SED_BIN '/^$/d')
		for EVENT in $EVENT_LIST
		do
		$OMCONFIG_BIN system alertaction event=$EVENT execappath="/sbin/openManageAlert.sh $EVENT"
		done
	fi

}

function sendEmail(){
	echo $EMAIL_BODY > $TEMPFILE
	$MAIL_BIN -s "$EMAIL_SUBJECT" $SEND_NOTIFICATION_TO < $TEMPFILE
	$RM_BIN $TEMPFILE
}

function findZabbixConfigFile(){
   if [ -z "$ZABBIX_CONFIG_FILE" ]; then
                ZABBIX_CONFIG_FILE=$($PS_BIN aux| \
                $GREP_BIN zabbix_agent| \
                $GREP_BIN '\-c'| \
                $AWK_BIN -F "-c" {'print $2'}| \
                $SED_BIN -n 1p| \
                $SED_BIN s'/^\ //'g
)
        fi

        if [ -z "$ZABBIX_CONFIG_FILE" ]; then
                echo "Could not find zabbix configuration file. Please set it on the script"
                exit 1
        fi

}

function sendZabbixNotification(){
	findZabbixConfigFile
	if [ ! -z "$1" ]; then
	$ZABBIX_SENDER_BIN -c "$ZABBIX_CONFIG_FILE" -k $ZABBIX_KEY -o "$ZABBIX_RESET_MESSAGE"
	return
	fi

	$ZABBIX_SENDER_BIN -c "$ZABBIX_CONFIG_FILE" -k $ZABBIX_KEY -o "$ZABBIX_MESSAGE"
	if [ "$?" -ne 0 ]; then
		echo "Erro sending the zabbix notification"
	fi
}

if [ -z "$1" ]; then
        echo "Script executed without parameters"
        echo "We will try to configure the alerts on OpenManage"
        echo "To test the e-mail or zabbix alert functions execute the script with the parameter \"test\""
	configureOpenManage
elif [ "$1" == "resetzabbix" ]; then
	sendZabbixNotification "$1"
else
        sendEmail
        sendZabbixNotification
fi


