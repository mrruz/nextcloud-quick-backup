#!/bin/bash
#Bash script for a quick, incremental backup

# Variables
timestamp=$(date +"%Y%m%d_%H%M%S")

# TODO: The directory of your Nextcloud installation (this is a directory under your web root)
webDirectory="/var/www/html/nextcloud/"
# TODO: data directory
data_directory="/path/to/nextcloud/data"
# TODO: Your web server user
webUser="www-data"
# TODO: The directory where you store the Nextcloud backups
rootBackupDir="/path/to/backup/directory"

# Database information
# TODO: Your Nextcloud database name
database="nextcloud_db"
# TODO: Your Nextcloud database user
dbUser="nextcloud_db_user"
# TODO: The password of the Nextcloud database user
dbPassword="password"

# Max number of backups
maxNrOfBackups=3



# Function for error messages
errorecho() { cat <<< "$@" 1>&2; }

#
# Check for root
#
if [ "$(id -u)" != "0" ]
then
	errorecho "ERROR: This script has to be run as root!"
	exit 1
fi

# Put Nextcloud in maintenance mode
echo "Turn on maintenance mode for Nextcloud..."
cd "${webDirectory}"
sudo -u "${webUser}" php occ maintenance:mode --on
cd ~
echo "Done"
echo

# Backup Nextcloud web root directory
echo "Backup web root..."
sudo rsync -avx ${webDirectory} ${rootBackupDir}/Current/www_data/ --log-file=${rootBackupDir}/Current/www-data.log
echo

# Backup Nextcloud web root directory
echo "Backup data..."
sudo rsync -avx ${data_directory} ${rootBackupDir}/Current/data/ --log-file=${rootBackupDir}/Current/data.log
echo

# Database backup
echo "Backup database..."
sudo mysqldump --single-transaction -h localhost -u "${dbUser}" -p"${dbPassword}" "${database}" > ${rootBackupDir}/Current/database.bak
echo

# Cool off
sleep 2s

# Take Nextcloud out of maintenance mode
echo "Turn off maintenance mode for Nextcloud..."
cd "${webDirectory}"
sudo -u "${webUser}" php occ maintenance:mode --off
cd ~
echo "Done"
echo

#Copy Current
echo "Creating archive..."
cd "${rootBackupDir}"
sudo tar -cpzf "./backup_${timestamp}.tar.gz" -c "Current/" 1 2>${rootBackupDir}/tar.log
echo "Archive created at ${rootBackupDir}/backup_${timestamp}.tar.gz"
echo 

#
# Delete old backups
#
echo "Reviewing backups for cleanup..."
echo "Backups to keep (zero is infinite): " ${maxNrOfBackups}
if (( ${maxNrOfBackups} != 0 ))
then	
	nrOfBackups=$(ls -l --ignore Current ${rootBackupDir} | grep -c "backup_*")
	echo "Backups found: " ${nrOfBackups}
	if (( ${nrOfBackups} > ${maxNrOfBackups} ))
	then
		echo "Removing old backups..."
		ls -l -r --ignore Current ${rootBackupDir} | tail -$(( nrOfBackups - maxNrOfBackups )) | while read dirToRemove; do
		echo "${dirToRemove}"
		rm -r ${rootBackupDir}/${dirToRemove}
		echo "Done"
		echo
    done
	fi
fi
echo 
echo "Done."
