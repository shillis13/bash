#!/usr/local/bin/bash
# set -x

# **********************************************************************************
#
# This script will check if it is being run as root, will install Docker and certbot, 
# start the Docker service, pull the latest Rocket.Chat and MongoDB images, and run 
# the MongoDB container. 
#
# It will also create the /etc/letsencrypt, /var/lib/letsencrypt, and /data/db 
# directories if they don't exist, and check if the mongodb and rocketchat 
# container already exist, if it does, it will not recreate them but just inform you 
# that they already exist. 
#
# It will also create a new user mongoUser for the MongoDB database, prompt the user 
# to provide a password for the user, and use that user/password pair in the MONGO_URL 
# with the domain name "rchat_lb_domainName.tessting.org" as the hostname and the default port 27017. 
#
# Also, it will obtain an SSL certificate using certbot, configure the MongoDB container 
# to use the user/password pair and link the rocket.chat container to the mongo container. 
# It will encrypt data in transit between Rocket.Chat and MongoDB using Mongo's --sslMod.
# It wlll encrypt the database using -enableEncryption --storageEngine=wiredTiger.  The
# SSL certificate and key files obtained earlier will be used.
#
# And it will also configure CloudFlare to use the SSL certificate and setup auto-renewal
# of the certificate via a cron job.
#
# **********************************************************************************
thisFile="InstallRCServer.sh"

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then args=("${@:1}")
else args=("${@}"); fi

source bashLibrary_base.sh "${args[@]}"
source ubuntu2204Setup_Library.sh "${args[@]}"

# *******************************************************************
# * {{{ define_pkgs_RCInstall
# *
# *******************************************************************
define_pkgs_RCInstall() {
    # add_package <name> <default_install> <install> <flag> <usage> <function_name>
    add_package "dockerInstalls" false "--dockers" "\t--dockers\tinstall docker.io certbot rocket.chat and mongo" "dockerInstalls"
    add_package "createDBUser" false "--createDBUser" "\t--createDBUser\tsetup user acct in DB" "createDBUser"
    add_package "createDirs" false "--createDirs" "\t--createDirs\tcreate dirs" "createDirs"
    add_package "installNginx" false "--installNginx" "\t--installNginx\tInstall Nginx" "installNginx"
    add_package "installSslCertsForMongo" true "--installSslCertsForMongo" "\t--installSslCertsForMongo\tget SSL Cert" "installSslCertsForMongo"
    add_package "runMongoCont" true "--runMongoCont" "\t--runMongoCont\trun MongoDB Docker Container" "runMongodbContainer"
    add_package "runRCCont" true "--runRCCont" "\t--runRCCont\run Rocket.Chat Docker Container" "runRchatContainer"
    add_package "setupCloudFlare" false "--cloudFlare" "\t--cloudFlare\tInstructions on setting up CloudFlare" "setupCloudFlare"
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ Variables
# *
# *******************************************************************
mongoUser="mongoDbUser"
mongoUserPw="${mongoUser}"
dbName="rocketchat"
rchat_lb_domainName="rchat-lb.tessting.org"
rchatPort=3000
mongoPort="20717"
mongo_isEnterprise=0
mongo_enableSsl=1
mongo_enableEncryptionDataAtRest=1      # requires Enterprise edition
mongo_enableFreeMonitor=1
mongoSslDir="/etc/ssl/mongo"
rchatVer="5.4.0"
mongoVer="4.4.15"
mongoImageName="mongo"                  # the official name
mongoContainerName="mongo-container"    # a name we pick
rchatImageName="rocketchat/rocket.chat" # the official name
rchatContainerName="rocketchat-container" # a name we pick
dockerHubUser="joeytess13"
dockerHubPw=""

ROOT_URL="https://${rchat_lb_domainName}"
MONGO_URL="mongodb://${mongoUser}:${mongoUserPw}@${rchat_lb_domainName}:${mongoPort}/${dbName}"
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ main
# *
# *******************************************************************
main() {
    local args=("$@")
    run_command define_pkgs_RCInstall

    run_command pkgs_main "${args[@]}"

    # High-level steps to setup CloudFlare as:
    #   - load balancer
    #   - reverse proxy
    #   - DDOS handler
    # setupCloudFlare
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ createDBUser
# *
# *******************************************************************
createDBUser() {
    run_command checkSudoOrRoot
    if [ -z $mongoUser ]; then
       if [ -z "$1" ]; then
           echo "${Color_Instr}Enter the desired MongoDB username:${Color_Info}" 
           read -p "> " mongoUser
       else
	   $mongoUser = $1
       fi
    fi
    if [ -z "$mongoUserPw" ]; then
        # echo "${Color_Instr}Enter the desired password:${Color_Info}" 
        # read -s -p "> " pw
        mongoUserPw=$mongoUser
    fi
    if [ -z "$dbName" ]; then
    	echo "${Color_Instr}Enter the desired database name:${Color_Info}" 
        read -p "> " dbName
    fi
    echo
    
    # Ensuring host user exists
    addUserAccount $mongoUser 

    # Create user with the given username and password
    run_command "echo \"Creating user $mongoUser for database $db\" "
    run_command "$on_err_cont" "docker-compose exec mongodb mongo $dbName --eval \"db.createUser({user: $mongoUser, pwd: $mongoUserPw, roles: [{role: readWrite, db: $dbName}]})\""

    # Set the global URL variables
    ROOT_URL="https://${rchat_lb_domainName}"
    MONGO_URL="mongodb://${mongoUser}:${mongoUserPw}@${rchat_lb_domainName}:${mongoPort}/${dbName}"
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ dockerInstalls
# *
# *******************************************************************
dockerInstalls() {
    run_command checkSudoOrRoot
    # Update the package index and install Docker
    run_command $on_err_cont apt-get update

    # import the MongoDB public GPG Key from https://www.mongodb.org/static/pgp/server-6.0.asc
    # gnupg is required for importing the MongoDB GPG key
    run_command apt-get install gnupg
    run_command "wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | sudo apt-key --keyring /etc/apt/trusted.gpg.d/mongodb.gpg add -"

    # Update sources list to add MongoDB
    mongo_sources_line="deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/6.0 multiverse"
    mongo_sources_file="/etc/apt/sources.list.d/mongodb-org-6.0.list"

    if ! grep "${mongo_sources_line}" "$mongo_sources_file" &> /dev/null; then
        run_command $on_err_cont "echo \"${mongo_sources_line}\" | tee ${mongo_sources_file}"
        # run_command $on_err_cont echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/6.0 multiverse" \
            # | tee /etc/apt/sources.list.d/mongodb-org-6.0.list
    fi

    # Now mongodb-mongosh should be found from MongoDB distribution source repo
    run_command apt-get install -y mongodb-mongosh

    # Install Docker 
    # Docker compose is for managing multiple containers
    run_command apt-get install -y docker.io docker.compose

    # Enable auto-start of the container on reboot
    run_command systemctl enable docker

    # Start the Docker service
    run_command systemctl start docker

    # First we need to login into docker Hub before we can pull mongodb
    # Ensure we have username for Docker Hub
    if [ -z "$dockerHubUser" ]; then
        echo "${Color_Instr}Docker Hub user :${Color_Info}" 
        read -p "> " dockerHubUser
        echo ""
    fi

    # Ensure we have pw for username on Docker Hub
    if [ -z "$dockerHubPw" ]; then
        echo "${Color_Instr}Docker Hub pw :${Color_Info}" 
        read -s -p "> " dockerHubPw
        echo ""
    fi

    run_command "echo $dockerHubPw | docker login -u $dockerHubUser  --password-stdin"

    # Check if Rocket.Chat and MongoDB images are already pulled
    if ! docker images | grep -q "rocket.chat" | grep -q "$rchatVer" > /dev/null ; then
        run_command "docker pull $rchatImageName:$rchatVer"
    fi
    if ! docker images | grep -q "mongo" | grep -q "$mongoVer" > /dev/null ; then
        run_command "docker pull $mongoImageName:$mongoVer"
    fi
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ createDirs
# *
# *******************************************************************
createDirs() {
    run_command checkSudoOrRoot
    # Create the /data/db directory with the correct permissions and ownership
    if [ ! -d "/data/db" ]; then
        run_command mkdir -p /data/db
    fi
    run_command chmod 755 /data/db
    run_command chown $mongoUser:$mongoUser /data/db

    # Create the /data/configdb directory with the correct permissions and ownership
    if [ ! -d "/data/configdb" ]; then
        run_command mkdir -p /data/configdb
    fi
    run_command chmod 755 /data/configdb
    run_command chown $mongoUser:$mongoUser /data/configdb

    # Create the directory to hold mongo's SSL cert and keys
    if [ ! -d "${mongoSslDir}" ]; then
        run_command mkdir ${mongoSslDir}
    fi
    run_command chmod 755 ${mongoSslDir}
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ installSslCertsForMongo
# *
# *******************************************************************
installSslCertsForMongo() {
    run_command checkSudoOrRoot

    # Make dir if necessary
    if [ ! -f  /etc/ssl/mongo ]; then run_command "mkdir -p /etc/ssl/mongo/"; fi

    # Copy SSL Cert and Keys to mongo's SSL dir
    if [ -f  /etc/letsencrypt/live/${rchat_lb_domainName}/fullchain.pem ]; then
        run_command "cp /etc/letsencrypt/live/${rchat_lb_domainName}/fullchain.pem /etc/ssl/mongo/mongo.pem"
    fi
    if [ -f /etc/letsencrypt/live/${rchat_lb_domainName}/privkey.pem ]; then
        run_command "cp /etc/letsencrypt/live/${rchat_lb_domainName}/privkey.pem /etc/ssl/mongo/mongo.key"
    fi
    run_command "chown -R $mongoUser:$mongoUser /etc/ssl/mongo"
    run_command "chmod 755 /etc/ssl/mongo"
    run_command "chmod 644 /etc/ssl/mongo/*"

}
# }}}
# *******************************************************************

# docker run -d --name mongodb --network host -v /data/db:/data/db -v /data/configdb:/data/configdb -v /etc/ssl/mongo:/etc/ssl/mongo -e MONGO_INITDB_ROOT_USERNAME=mongoDbUser -e MONGO_INITDB_ROOT_PASSWORD= -e MONGO_INITDB_DATABASE=rocket -e MONGO_URL=mongodb://mongoDbUser:mongoDbUser@rchat_lb_domainName.tessting.org:27017/rocketchat -e ROOT_URL=https://rchat_lb_domainName.tessting.org -e PORT= -e MONGO_OPLOG_URL=mongodb://mongoDbUser:@localhost:27017/local --ssl --tlsCertificateKeyFile /etc/ssl/mongo/mongo.pem --tlsCAFile /etc/ssl/mongo/ca.pem --storageEngine wiredTiger --enableFreeMonitoring runtime mongo:4.4.15


# *******************************************************************
# * {{{ runMongodbContainer
# *
# *******************************************************************
runMongodbContainer() {
    run_command checkSudoOrRoot
    EncryptDataOpts=""
    TlsOpts=""
    MongoOpts="--storageEngine wiredTiger"

    # Encrypting data at rest (seems to require enterprise)
    if [ ! -z "${mongo_isEnterprise}" ] && [ $mongo_isEnterprise -eq 1 ]; then
        if [ ! -z "${mongo_enableEncryptionDataAtRest}" ] && [ $mongo_enableEncryptionDataAtRest -eq 1 ]; then
            EncryptDataOpts="--enableEncryption --storageEngine=wiredTiger"
        fi
    fi

    if [ ! -z "${mongo_enableSsl}" ] && [ ${mongo_enableSsl} -eq 1 ]; then
        # TlsOpts="--tlsMode requireTLS --tlsCertificateKeyFile /etc/ssl/mongo/mongo.pem --tlsCAFile /etc/ssl/mongo/ca.pem"
        TlsOpts="--tlsMode requireTLS --tlsCertificateKeyFile /etc/ssl/mongo/mongo.pem --tlsCAFile /etc/ssl/mongo/ca.pem"
    fi

    if [ ! -z "${mongo_enableFreeMonitor}" ] && [ ${mongo_enableFreeMonitor} -eq 1 ]; then
        MongoOpts="$MongoOpts --enableFreeMonitoring runtime"
    fi

    if [ ! "$(docker ps -q -f name=${mongoContainerName})" ]; then
        if [ "$(docker ps -aq -f status=exited -f name=${mongoContainerName})" ]; then
            # cleanup
            run_command "echo \"Cleaning up existing container\""
            run_command docker rm ${mongoContainerName}
        fi
        run_command "on_err_cont" "docker run -d --name ${mongoContainerName} --network host -v /data/db:/data/db -v /data/configdb:/data/configdb \
            -v ${mongoSslDir}:${mongoSslDir} -e MONGO_INITDB_ROOT_USERNAME=${mongoUser} \
            -e MONGO_INITDB_ROOT_PASSWORD=${mongoUserPw} -e MONGO_INITDB_DATABASE=${dbName} \
            -e MONGO_URL=${MONGO_URL} -e ROOT_URL=${ROOT_URL} \
            -e PORT=$mongoPort -e MONGO_OPLOG_URL=mongodb://${mongoUser}:${password}@localhost:${mongoPort}/local \
            ${mongoImageName}:${mongoVer} ${EncryptDataOpts} ${TlsOpts} ${MongoOpts}"

    else
        run_command "echo \"mongodb container ${mongoContainerName} already running\" "
    fi
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ runRchatContainer
# *
# *******************************************************************
runRchatContainer() {
    run_command checkSudoOrRoot
    EnvOpts="-e MONGO_URL=${MONGU_URL} -e ROOT_URL=${ROOT_URL} -e PORT=${rchatPort}"
    rchatOpts=""
    TlsOpts=""
    OtherOpts="-v ${mongoSslDir}:${mongoSslDir}"

    if [ ! -z "${mongo_enableSsl}" ] && [ ${mongo_enableSsl} -eq 1 ]; then
        TlsOpts=""
    fi
    if [ ! "$(docker ps -q -f name=${rchatContainerName})" ]; then
        if [ "$(docker ps -aq -f status=exited -f name=${rchatContainerName})" ]; then
            # cleanup
            run_command "echo \"Cleaning up existing container\""
            run_command "docker rm ${rchatContainerName}"
        fi
        run_command "docker run -d --name ${rchatContainerName} --network host ${EnvOpts} ${OtherOpts} ${rchatImageName}:${rchatVer} ${TlsOpts} ${rchatOpts}"
    else
        run_command "echo \"rocketchat container ${rchatContainerName} already running\" "
    fi
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ installNginx
# *
# *******************************************************************
installNginx() {
    if [ -x InstallNginx.sh ]; then run_command "sudo ./InstallNginx.sh --installNginx --getSslCerts"; fi
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ setupCloudFlare
# *
# *******************************************************************
setupCloudFlare() {
    echo "1. Sign up for a CloudFlare account and add your website to it."
    echo "2. Change your domain's name servers to the ones provided by CloudFlare."
    echo "3. Configure your DNS settings on CloudFlare to point to your server's IP address."
    echo "4. Enable the 'Full' SSL mode on CloudFlare and make sure your server is configured to use SSL."
    echo "5. Enable the 'Always Use HTTPS' and 'Automatic HTTPS Rewrites' options on CloudFlare to ensure all connections are encrypted."
    echo "6. Enable CloudFlare's DDoS protection and rate limiting features to protect your server from attacks."
}
# }}}
# *******************************************************************

main ${args[@]}


# ***********************************
# *** Encrypting DB data at rest ****
# ***********************************
#   The keys used to encrypt data at rest in MongoDB are generated automatically by the storage 
#   engine (WiredTiger) and are not related to the SSL/TLS certificate and key files obtained 
#   for encrypting network traffic.  When you enable encryption at rest in MongoDB, the storage 
#   engine generates a data encryption key (DEK) and a key encryption key (KEK). The DEK is used 
#   to encrypt the data and the KEK is used to encrypt the DEK. The KEK is then stored in a 
#   keyfile which can be stored on a separate, secure storage.
#
#   When MongoDB starts, it uses the keyfile to decrypt the KEK, which is then used to decrypt 
#   the DEK, which is then used to decrypt the data stored on disk. To enable encryption at rest 
#   in MongoDB, you need to pass the --enableEncryption option with the --storageEngine option 
#   when starting MongoDB. The --enableEncryption option tells MongoDB to encrypt the data at 
#   rest, and the --storageEngine option tells MongoDB which storage engine to use for the 
#   encryption.
#
# ***********************************
# *** Encrypting Data in Transit
# ***********************************
#   The keys and certificates used for encrypting data at rest and encrypting network traffic 
#   are different. The keys and certificates used for encrypting data at rest are used to encrypt 
#   the data stored on disk by MongoDB using a storage engine like WiredTiger. The encryption is 
#   transparent to the application and it ensures that the data stored on disk is protected even 
#   if the disk is stolen.
#
#   The keys and certificates used for encrypting network traffic are used to encrypt the data 
#   sent over the network between MongoDB and the clients. It is done using the SSL/TLS protocol 
#   and it is used to protect the data from being intercepted and read by an unauthorized party.
#
#   In the script provided earlier, the keys obtained for Rocket.Chat are used to encrypt the 
#   network traffic. The keys are used to configure the MongoDB container to use SSL/TLS with the 
#   --sslPEMKeyFile and --sslCAFile options. The --sslPEMKeyFile option is used to specify the 
#   location of the PEM-encoded SSL certificate and key files and the --sslCAFile option is used 
#   to specify the location of the PEM-encoded CA certificate files.
