#!/bin/bash
#Bash script for a quick, incremental backup

# Variables
timestamp=$(date +"%Y%m%d_%H%M%S")

# TODO: The directory of your Nextcloud installation (this is a directory under your web root)
web_directory="/var/www/html/nextcloud/"
# TODO: data directory
data_directory="/path/to/nextcloud/data"
# TODO: Your web server user
web_user="www-data"
# TODO: The directory where you store the Nextcloud backups
root_backup_dir="/path/to/backup/directory"

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
cd "${web_directory}"
sudo -u "${web_user}" php occ maintenance:mode --on
cd ~
echo "Done"
echo

# Backup Nextcloud web root directory
echo "Backup web root..."
sudo rsync -avx ${web_directory} ${root_backup_dir}/Current/www_data/ --log-file=${root_backup_dir}/Current/www-data.log
echo

# Backup Nextcloud web root directory
echo "Backup data..."
sudo rsync -avx ${data_directory} ${root_backup_dir}/Current/data/ --log-file=${root_backup_dir}/Current/data.log
echo

# Database backup
echo "Backup database..."
sudo mysqldump --single-transaction -h localhost -u "${dbUser}" -p"${dbPassword}" "${database}" > ${root_backup_dir}/Current/database.bak
echo

# Cool off
sleep 2s

# Take Nextcloud out of maintenance mode
echo "Turn off maintenance mode for Nextcloud..."
cd "${web_directory}"
sudo -u "${web_user}" php occ maintenance:mode --off
cd ~
echo "Done"
echo

#Copy Current
echo "Creating archive..."
sudo tar -cpzf "${root_backup_dir}/backup_${timestamp}.tar.gz" -c "${root_backup_dir}/Current/" 1 2>${root_backup_dir}/tar.log
echo "Archive created at ${root_backup_dir}/backup_${timestamp}.tar.gz"
echo 

#
# Delete old backups
#
echo "Reviewing backups for cleanup..."
echo "Backups to keep (zero is infinite): " ${maxNrOfBackups}
if (( ${maxNrOfBackups} != 0 ))
then	
	nrOfBackups=$(ls -l --ignore Current ${root_backup_dir} | grep -c backup_*)
	echo "Backups found: " ${nrOfBackups}
	if (( ${nrOfBackups} > ${maxNrOfBackups} ))
	then
		echo "Removing old backups..."
		ls -l -r --ignore Current ${root_backup_dir} | tail -$(( nrOfBackups - maxNrOfBackups )) | while read dirToRemove; do
		echo "${dirToRemove}"
		#rm -r ${root_backup_dir}/${dirToRemove}
		echo "Done"
		echo
    done
	fi
fi
echo 
echo "Done."
