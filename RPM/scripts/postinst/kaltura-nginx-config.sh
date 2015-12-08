#!/bin/bash - 
#===============================================================================
#          FILE: kaltura-nginx-config.sh
#         USAGE: ./kaltura-nginx-config.sh 
#   DESCRIPTION: configure server as an Nginx  node.
#       OPTIONS: ---
# 	LICENSE: AGPLv3+
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: Jess Portnoy <jess.portnoy@kaltura.com>
#  ORGANIZATION: Kaltura, inc.
#       CREATED: 01/02/14 09:23:34 EST
#      REVISION:  ---
#===============================================================================

#set -o nounset                              # Treat unset variables as an error
verify_user_input()
{
        ANSFILE=$1
        . $ANSFILE
        RC=0
        for VAL in WWW_HOST VOD_PACKAGER_HOST VOD_PACKAGER_PORT ; do
                if [ -z "${!VAL}" ];then
                        VALS="$VALS\n$VAL"
                        RC=1
                fi
        done
        if [ $RC -eq 1 ];then
                OUT="ERROR: Missing the following params in $ANSFILE
                $VALS
                "
                echo -en "${BRIGHT_RED}$OUT${NORMAL}\n"
                send_install_becon kaltura-nginx $ZONE "install_fail"  "$OUT"
                exit $RC 
        fi
}


KALTURA_FUNCTIONS_RC=`dirname $0`/kaltura-functions.rc
if [ ! -r "$KALTURA_FUNCTIONS_RC" ];then
	OUT="ERROR: Could not find $KALTURA_FUNCTIONS_RC so, exiting.."
	echo -e $OUT
	exit 3
fi
. $KALTURA_FUNCTIONS_RC
if ! rpm -q kaltura-nginx;then
	echo -e "${BRIGHT_BLUE}Skipping as kaltura-nginx is not installed.${NORMAL}"
	exit 0 
fi

if [ -n "$1" -a -r "$1" ];then
        ANSFILE=$1
        verify_user_input $ANSFILE
        . $ANSFILE
        export ANSFILE
        if [ $IS_VOD_PACKAGER_SSL ]; then
        	echo "IS_VOD_PACKAGER_SSL was set: $IS_VOD_PACKAGER_SSL"
        	temp_var=`echo $IS_VOD_PACKAGER_SSL | tr '[:upper:]' '[:lower:]'`
        	IS_VOD_PACKAGER_SSL=$temp_var
        	if [ "$IS_VOD_PACKAGER_SSL" == 'n' ];
        	then
        		echo -e "${BRIGHT_BLUE}Nginx will be configured as http.${NORMAL}"
        	elif [ "$IS_VOD_PACKAGER_SSL" == 'y' ]; then
        		echo -e "${BRIGHT_BLUE}Nginx will be configured as https.${NORMAL}"
        	else 
        		echo -e "${BRIGHT_RED}Invalid value was provided in the answer file: [ ${NORMAL}$IS_VOD_PACKAGER_SSL ${BRIGHT_RED}].${NORMAL}"
        		exit 3
        	fi
        else
        	echo -e "${BRIGHT_BLUE}IS_VOD_PACKAGER_SSL was not set. Nginx will be configured as http{$NORMAL}"
        fi
else
	echo -e "${CYAN}Kaltura API host [${YELLOW}`hostname`${CYAN}]:${NORMAL} "
	read -e WWW_HOST
	if [ -z "$WWW_HOST" ];then
		WWW_HOST=`hostname`
	fi

	echo -e "${CYAN}Nginx server name [${YELLOW}`hostname`${CYAN}]:${NORMAL} "
	read -e VOD_PACKAGER_HOST
	if [ -z "$VOD_PACKAGER_HOST" ];then
		VOD_PACKAGER_HOST=`hostname`
	fi

	echo -en "${CYAN}Nginx port to listen on [${YELLOW}88${CYAN}]:${NORMAL} "
	read -e VOD_PACKAGER_PORT
	if [ -z "$VOD_PACKAGER_PORT" ];then
		VOD_PACKAGER_PORT=88
	fi
	echo -e "${CYAN}Should nginx be configured in https mode? [${YELLOW}[y/n]${CYAN}]:${NORMAL} "
	read -e IS_VOD_PACKAGER_SSL
	temp_var=`echo $IS_VOD_PACKAGER_SSL | tr '[:upper:]' '[:lower:]'`
	IS_VOD_PACKAGER_SSL=$temp_var
	if [ !"$IS_VOD_PACKAGER_SSL" == 'y' -o !"$IS_VOD_PACKAGER_SSL" == 'n' ]; then
		echo -e "${BRIGHT_RED}The option can only be 'y' or 'n'. Please re-run${NORMAL}"
		exit 4
	fi
	echo -e "${CYAN}Please input path to your SSL certificate[${YELLOW}/etc/ssl/certs/localhost.crt${CYAN}]:${NORMAL}"
	read -e CRT_FILE
	echo "crt file: $CRT_FILE"
	if [ -z "$CRT_FILE" ];then
		CRT_FILE="/etc/ssl/certs/localhost.crt"
	fi
	echo -e "${CYAN}Please input path to your SSL CA file or leave empty in case you have none${CYAN}:${NORMAL}"
	read -e CHAIN_FILE
	echo "chain file: $CHAIN_FILE"
fi


if [ -f /etc/nginx/nginx.conf ];then
	mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.old
fi

# Sed according to needed nginx mode
if [ "$IS_VOD_PACKAGER_SSL" == 'y' ]; then
	sed -e "s#@SSL_CERTIFICATE_FILE@#$CRT_FILE#g" -e "s#@SSL_CERTIFICATE_CHAIN_FILE@#$CHAIN_FILE#g" -e 's#@STATIC_FILES_PATH@#/etc/nginx/static#g' -e "s#@VOD_PACKAGER_HOST@#$VOD_PACKAGER_HOST#g" -e "s#@VOD_PACKAGER_PORT@#$VOD_PACKAGER_PORT#g" -e "s#@LOG_DIR@#/var/log/nginx#" -e "s#@WWW_HOST@#$WWW_HOST#g" /etc/nginx/conf.d/kaltura.ssl.conf.template > /etc/nginx/nginx.conf	
else
	sed -e 's#@STATIC_FILES_PATH@#/etc/nginx/static#g' -e "s#@VOD_PACKAGER_HOST@#$VOD_PACKAGER_HOST#g" -e "s#@VOD_PACKAGER_PORT@#$VOD_PACKAGER_PORT#g" -e "s#@LOG_DIR@#/var/log/nginx#" -e "s#@WWW_HOST@#$WWW_HOST#g" /etc/nginx/conf.d/kaltura.conf.template > /etc/nginx/nginx.conf
fi

chkconfig kaltura-nginx on
if service kaltura-nginx status >/dev/null 2>&1;then
	service kaltura-nginx reload
else
	service kaltura-nginx start
fi

