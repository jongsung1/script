#!/bin/bash
 
##conf file import
source /idea_backup/script/default/default_conf

#set -x
RV1=/opt/rv-Linux-x86-64-7.0.0/etc/license.gto
RV1DIR=/opt/rv-Linux-x86-64-7.0.0/etc/
RV2=/opt/rv-Linux-x86-64-7.2.0/etc/license.gto
RV2DIR=/opt/rv-Linux-x86-64-7.2.0/etc/

insert_history(){
	TABLE=RV_HISTORY
	DATE=`date +%s`
	INSERT_SQL=" INSERT INTO ${TABLE} (USERID, DATE) VALUES ('${HOSTNAME}','${DATE}') "
	SQL=${INSERT_SQL}
	mysql -h${MYSQLHOST} -uroot -p${PASSWORD} IDEA -e "${SQL}"
}

insert_history

####### 89 start ~ 107 end
RV_license(){
        local value=$1
	for ((i=89;i<=107;i++))
	do
	        ########### rv 라이센스 변경
		COUNT1=`cat ${value} | grep 10.0.99.$i | wc -l`
		if [ $COUNT1 = 1 ] ; then
			j=`expr $i + 1`
			sed -i "s/10.0.99.$i/10.0.99.$j/g" ${value}
			if [ ${value} = ${RV1} ] ; then			
				if [ $i = 107 ] ; then
					echo -e "${GREEN} NEW RV1 license 10.0.99.89 ${RESET}"
				else
					echo -e "${GREEN} NEW RV1 license 10.0.99.$j ${RESET}"
				fi
                        elif [ ${value} = ${RV2} ] ; then	
				if [ $i = 107 ] ; then
					echo -e "${GREEN} NEW RV2 license 10.0.99.89 ${RESET}"
				else
					echo -e "${GREEN} NEW RV2 license 10.0.99.$j ${RESET}"
				fi
			fi
			break;
		fi
	done
}

if [ -d "${RV1DIR}" ];then
	RV_license $RV1
	
	###### 89 ~ 107까지 --> 108번이 되면 처음 번호인 89번으로 변경
	#sed -i "s/10.0.99.89/10.0.99.90/g" $RV1
	
	##### 89 ~ 107까지 --> 108번이 되면 처음 번호인 89번으로 변경
	sed -i "s/10.0.99.108/10.0.99.89/g" $RV1
fi

if [ -d "${RV2DIR}" ];then
	RV_license $RV2
	
	###### 91 ~ 107까지 --> 108번이 되면 처음 번호인 91번으로 변경
	#sed -i "s/10.0.99.90/10.0.99.91/g" $RV2
	
	##### 89 ~ 107까지 --> 108번이 되면 처음 번호인 89번으로 변경
	sed -i "s/10.0.99.108/10.0.99.89/g" $RV2

fi

