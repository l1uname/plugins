#!/bin/bash 

#Variables
TID=$1
NC="\033[0m"
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
DATE=$(date +%m-%d-%Y)
NUM="^[0-9]+([.][0-9]+)?$"
ACTIVE_PLUGINS=$(wp plugin list --status=active --field=name --skip-themes --skip-plugins)
ACCEPTED_VALUES='^(\s*[0-9]+\s*)+$'

#Checking database connection
function db_check() {
local DB_CHECK=$(wp db check)
if [[ $? != 0 ]]
then
	echo -e "${RED}Database connection failed! Please check the database configuration.${NC}"
	exit 1
else 
	echo -e "${GREEN}Database check successful!${NC}"
fi
}

#Exporting database backup
function db_export() {
local DB_EXPORT=$(wp db export ../db-backup-${DATE}-${RANDOM}.sql)

echo -e "${GREEN}Generating database backup:${NC} "
echo $DB_EXPORT
}

#Splitting files in half
function sgsplit() {
local FILE=$1
local CHECK_LINES=$(cat ${FILE} | grep -v "^$" | wc -l)

if [[ $CHECK_LINES -gt 2 ]]
then
	split -n l/2 -d ${FILE} ${FILE}_
elif [[ $CHECK_LINES == 2 ]]
then
	split -l 1 -d ${FILE} ${FILE}_
else	
	exit 0
fi
}

#Activating plugins from batch
function activate() {
local FILE=$1
local CHECK_LINES=$(cat ${FILE} | grep -v "^$" | wc -l)

if [[ $CHECK_LINES -ge 1 ]]
then
	for i in $(cat ${FILE})
	do
		wp plugin activate $i --skip-plugins --skip-themes
	done
else
	echo -e "${GREEN}The last batch has no remaining plugins${NC}"
	exit 0
fi
}

#Deactivating plugins from batch
function deactivate() {
local FILE=$1
local CHECK_LINES=$(cat ${FILE} | grep -v "^$" | wc -l)

if [[ $CHECK_LINES -ge 1 ]]
then
for i in $(cat ${FILE})
do
	wp plugin deactivate $i --skip-plugins --skip-themes
done
else
	echo -e "${GREEN}The last batch has no remaining plugins${NC}"
	exit 0
fi
}

#Flushing WP cache
function flush_wp_cache() {
local SGO=$(wp plugin status sg-cachepress | grep Status | awk '{print $NF}')

if [[ $SGO == "Active" ]]
then
	wp cache flush; wp rewrite flush; wp transient delete --all; wp sg purge
else
	wp cache flush; wp rewrite flush; wp transient delete --all
fi
}

function split_case_yes() {
echo -e "${GREEN}Then the issue is likely caused by the following batch: ${NC}"
echo
cat active_plugins_${TID}_final.txt_00

if [[ $(cat active_plugins_${TID}_final.txt_00 | grep -v "^$" | wc -l) == 1 ]]
then
	rm -f active_plugins_${TID}_*
	exit 0
fi

echo
rm active_plugins_${TID}_final.txt_01
mv active_plugins_${TID}_final.txt_00 active_plugins_${TID}_final.txt
activate active_plugins_${TID}_final.txt
}

function split_case_no() {
echo -e "${GREEN}Then the issue is likely caused by the following batch: ${NC}"
echo
cat active_plugins_${TID}_final.txt_01

if [[ $(cat active_plugins_${TID}_final.txt_00 | grep -v "^$" | wc -l) == 1 ]]
then
	rm -f active_plugins_${TID}_*
	exit 0
fi

echo
rm active_plugins_${TID}_final.txt_00
mv active_plugins_${TID}_final.txt_01 active_plugins_${TID}_final.txt
}

function list_plugins() {
local CHECK_LINES=$(cat active_plugins_${TID}_complete_list.txt | grep -v "^$" | wc -l)

if [ "$CHECK_LINES" -gt "3" ]
then
NLINE=1
while read LINE
do
	echo "${NLINE}: $LINE"
	((NLINE++))
done < active_plugins_${TID}_complete_list.txt
elif  [ "$CHECK_LINES" == "0" ]
then
	echo -e "${RED}There are no active plugins${NC}"
	echo
	echo -e "${GREEN}Removing active_plugins_${TID}_complete_list.txt ..${NC}"
	rm -f active_plugins_${TID}_complete_list.txt
	exit 0
else
	echo -e "${GREEN}There are only a few plugins (3 or less): ${NC}"
	echo
	cat active_plugins_${TID}_complete_list.txt
	echo
	echo -e "${GREEN}You may disable them manually.${NC}"
	echo -e "${GREEN}Removing active_plugins_${TID}_complete_list.txt ..${NC}"
	rm -f active_plugins_${TID}_complete_list.txt
	exit 0
fi
}

while ! [[ $TID =~ $NUM ]]
do
	read -p "Please provide a valid Ticket ID: " TID
done

#Function
db_check

#Function
db_export

#Check if db export is successful
if [[ $? != 0  ]]
then 
	echo -e "${RED}Database backup failed!${NC}"
fi

echo
echo -e "${GREEN}Saving the list of active plugins to: active_plugins_${TID}_complete_list.txt ...${NC}"
echo
if [[ -f active_plugins_${TID}_complete_list.txt ]]
then
	rm -f active_plugins_${TID}_complete_list.txt
fi

printf '%s\n' $ACTIVE_PLUGINS > active_plugins_${TID}_complete_list.txt

if [[ $? != 0 ]]
then
	sleep 0.5
	echo -e "${RED}Unable to save file. Please check permissions, or check whether the file already exists${NC}"
else 
	sleep 0.5
	echo -e "${GREEN}New file successfully generated.${NC}"
fi
echo
echo "List of all active plugins: "
echo

#Function
list_plugins

echo
echo "Would you like to skip any of the plugins?"

while true
do
read -p "1. Yes
2. No
" OPTION
case ${OPTION} in

	[yY]|[yY][eE][sS]|[1])
		sleep 0.5
		while true
		do
		read -p "Provide the corresponding number of the plugin that you would like to skip.
For multiple selection $(echo -e ${YELLOW}- maximum 7 -${NC}) provide the numbers separated by space (e.g. 1 2 3), or type 0 to skip
" PLUGIN1 PLUGIN2 PLUGIN3 PLUGIN4 PLUGIN5 PLUGIN6 PLUGIN7
		if [[ "$PLUGIN1" == "0" ]]
		then
			cp active_plugins_${TID}_complete_list.txt active_plugins_${TID}_final.txt
			echo
			echo -e "${GREEN}OK! Continuing with the full batch of active plugins.${NC} "
			echo
		break
		elif [[ "$PLUGIN1 $PLUGIN2 $PLUGIN3 $PLUGIN4 $PLUGIN5 $PLUGIN6 $PLUGIN7" =~ $ACCEPTED_VALUES ]]
		then
			awk -v var="$PLUGIN1" -v var1="$PLUGIN2" -v var2="$PLUGIN3" -v var3="$PLUGIN4" -v var4="$PLUGIN5" -v var5="$PLUGIN6" -v var6="$PLUGIN7" 'FNR==var || FNR==var1 || FNR==var2 || FNR==var3 || FNR==var4 || FNR==var5 || FNR==var6' active_plugins_${TID}_complete_list.txt > skipped_plugins_${TID}.txt
			sleep 0.5
			echo
			echo -e "${GREEN}The plugins that are skipped are:${NC} "
			echo
			cat skipped_plugins_${TID}.txt
			#Removing the skipped plugins from the list
			grep -vxFf skipped_plugins_${TID}.txt active_plugins_${TID}_complete_list.txt > active_plugins_${TID}_final.txt
			sleep 0.5
			echo
			echo -e "${GREEN}The remaining active plugins after skip are:${NC} "
			echo
			cat active_plugins_${TID}_final.txt
			break
		else
			echo
			echo -e "${RED}Invalid Option! Try again!${NC}"
			echo -e "${RED}Or type 0 to skip${NC}"
			echo
			continue
		fi
		done
		break
	;;

	[nN]|[nN][oO]|[2])
		sleep 0.5
		cp active_plugins_${TID}_complete_list.txt active_plugins_${TID}_final.txt
		echo
		echo -e "${GREEN}OK! Continuing with the full batch of active plugins.${NC} "
		echo
		break
	;;

	*)
		echo -e "${RED}Invalid option. Please try again!${NC}"
		continue
	;;
esac
done

while true
do
#Splitting batch
sgsplit active_plugins_${TID}_final.txt
echo
echo -e "${GREEN}Splitting to batch:${NC} "
echo
sleep 0.5
cat active_plugins_${TID}_final.txt_00
echo
echo -e "${GREEN}Deactivating first batch: ${NC}"

#Deactivating plugins from batch
deactivate active_plugins_${TID}_final.txt_00
echo
echo -e "${GREEN}Flushing cache:${NC} "

#Flushing cache
flush_wp_cache
echo
while true
do
echo -e "${GREEN}Please test whether the issue on the site is resolved.${NC}"
echo
read -p "1. Yes
2. No
" OPTION
case $OPTION in

	[yY]|[yY][eE][sS]|1)
		split_case_yes active_plugins_${TID}_final.txt_00
		break
	;;

	[nN]|[nN][oO]|2)
		split_case_no active_plugins_${TID}_final.txt_01
	break
	;;

	*) 
		echo
		echo -e "${RED}Invalid Option. Please try again!"
		echo
		continue
	;;
esac
done
done
