#!/usr/local/bin/bash

thisFile="InstallNginx.sh"
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then args=("${@:1}")
else args=("${@}"); fi

source bashLibrary_base.sh "${args[@]}" 

# *******************************************************************
# * {{{ define_pkgs
# *
# *******************************************************************
define_pkgs_Nginx() {
    # add_package <name> <default_install> <install> <flag> <usage> <function_name>
    add_package "installNginx" true "--installNginx" "\t--installNginx\tinstall Nginx webserver and its dependencies" "installNginx"
    add_package "uninstallNginx" false "--uninstallNginx" "\t--uninstallNginx\tUninstall Nginx web server" "uninstallNginx"
    add_package "installCertbot" true "--installCertbot" "\t--installCertbot\tInstall Cerrbot" "installCertbot"
    add_package "getSslCerts" true "--getSslCerts" "\t--getSslCerts\tGet SSL certificates from Let's Encrypt" "getSslCerts"
    add_package "removeCerts" false "--removeCerts" "\t--removeCerts\tRemove SSL certs" "removeCerts"

    # print_pkgs
}
# }}}
# -------------------------------------------------------------------


# *******************************************************************
# {{{ Constants
# * 
# *******************************************************************
server_name="rchat-lb.tessting.org"
nginx_config_file="/etc/nginx/nginx.conf"
rchat_lb_domainName="rchat-lb.tessting.org"
email=admin@tessting.org
nginxPkgs="nginx-full"
certbotPkgs="certbot python3-certbot-nginx"
# nginxPkgs="nginx nginx-core nginx-extras"

server_block="
    server {
        listen 80;
        server_name rchat-lb.tessting.org;
        return 301 https://\$server_name\$request_uri;
    }

    server {
        listen 443 ssl;
        server_name rchat-lb.tessting.org;
        ssl_certificate /etc/letsencrypt/live/rchat_lb_domainName/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/rchat_lb_domainName/privkey.pem;

        location / {
            proxy_pass http://127.0.0.1:3000;
            proxy_pass http://159.89.126.222:3000;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection \"upgrade\";
            proxy_set_header Host \$host;
            proxy_cache_bypass \$http_upgrade;
        }
    }
"
# }}} 
# -------------------------------------------------------------------


# *******************************************************************
# {{{ check_server_block_exists
# * Function to check if the server block already exists in the nginx config file
# * 
# ******************************************************
check_nginx_server_block_exists() {
  if grep -q "$server_name" "$nginx_config_file"; then
    return 0 # True
  else
    return 1 # False
  fi
}
# }}} 
# -------------------------------------------------------------------


# *******************************************************************
# {{{ write_nginx_server_block
# * Function to write the server block to the nginx config file
# * 
# *******************************************************************
write_nginx_server_block() {
    # echo "Echo: grep -q server_name $server_name $nginx_config_file"
    
    if ! grep -q "server_name $server_name" "$nginx_config_file"; then

        awk -v server_block="$server_block" -v server_name="$server_name" 'BEGIN { indent=0 }
        /http {/ { print; print server_block; indent=1; next }
        { if ( indent ) print "    " $0 
        else print } ' "$nginx_config_file" > "$nginx_config_file.tmp" && mv "$nginx_config_file.tmp" "$nginx_config_file"

        echo "Server block added to Nginx configuration file."
    else
        echo "Server block already present in Nginx configuration file."
    fi
}
# }}} 
# -------------------------------------------------------------------


# *******************************************************************
# {{{ installNginx`
# * 
# *******************************************************************
installNginx() {
    returnStatus=0 # 0 = good, 1 = bad

    local -i isNginxInstalled=$(checkIfNginxInstalled)
    # echo "Echo: isNginxInstalled = $isNginxInstalled"

    if [ $isNginxInstalled -ne 1 ]; then 
        run_command checkSudoOrRoot
        if [ -z "$aptUpdated" ]; then
            run_command $on_err_cont apt update
            declare -g aptUpdated=true
        fi
        run_command apt install -y $nginxPkgs

        run_command systemctl start nginx
        run_command systemctl enable nginx
        run_command systemctl status nginx
    else
        echo "Echo: Nginx is already installed"
        Db_Error "Nginx is already installed"
    fi

    if [ ! -f "$nginx_config_file" ]; then
        Db_Error "$nginx_config_file not found"
        returnStatus=1
    elif [ ! -w "$nginx_config_file" ]; then
        Db_Error "Cannot write to $nginx_config_file. Check file permissions."
        returnStatus=1
    else
        check_nginx_server_block_exists
        if [ $? -eq 0 ]; then
            Db_Info "Server block for $server_name already exists in $nginx_config_file"
        else
            write_nginx_server_block
        fi
    fi

    # reload Ngix Server
    nginx -s reload

    return $returnStatus
}
# }}} 
# -------------------------------------------------------------------


# *******************************************************************
# {{{ uninstallNginx`
# * 
# *******************************************************************
uninstallNginx() {
    run_command checkSudoOrRoot
    run_command systemctl stop nginx
    nowDateTime=$(date +"%Y-%m-%d-%H:%m:%S")
    if [ -d /etc/nginx ]; then 
        run_command mv /etc/nginx /tmp/etc-nginx-${nowDateTime}
    fi
    run_command apt purge -y $nginxPkgs
    if [ -x /usr/sbin/nginx ]; then 
        run_command rm -f /usr/sbin/nginx
    fi
}
# }}} 
# -------------------------------------------------------------------


# *******************************************************************
# {{{ checkIfNginxInstalled
# * 
# * 1 = installed, 0 = not installed
# *******************************************************************
checkIfNginxInstalled() {
    $(hash -r)  # Refresh command's hash table
    nginxIsInstalled=0
    nginxIsInstalled=$(command -v nginx &> /dev/null)
    if [ ${?} -eq 0 ]; then 
        nginxIsInstalled=1
    else
        nginxIsInstalled=0
    fi 

    echo "$nginxIsInstalled"
    # Db_Warn "Nginx is not installed"
}
# }}} 
# -------------------------------------------------------------------


# *******************************************************************
# {{{ checkIfCertbotInstalled
# * 
# * 1 = installed, 0 = not installed
# *******************************************************************
checkIfCertbotInstalled() {
    isCertbotInstalled=0
    isCertbotInstalled=$(command -v certbot &> /dev/null)
    if [ ${?} -eq 0 ]; then isCertbotInstalled=1; fi 
    echo $isCertbotInstalled
    return $isCertbotInstalled
}
# }}} 
# -------------------------------------------------------------------

# *******************************************************************
# * {{{ InstallCertbot
# *
# *******************************************************************
installCertbot() {
    run_command checkSudoOrRoot

    # Install packages
    if ! (checkIfCertbotInstalled); then
        if [ -z "$aptUpdated" ]; then
            run_command $on_err_cont apt update
            declare -g aptUpdated=true
        fi

        add-apt-repository ppa:certbot/certbot -y
        apt update
        apt install -y $certbotPkgs
    fi
    # run_command apt-get install -y certbot  python3-certbot-nginx
    # run_command snap install --classic certbot

}
# }}}
# ------------------------------------------------------------------

# ******************************************************************
# * {{{ getSslCerts
# *
# *******************************************************************
getSslCerts() {
    run_command checkSudoOrRoot

    if [ ! -f "/etc/letsencrypt/live/${rchat_lb_domainName}/fullchain.pem" ]; then
        # run_command "certbot certonly --webroot -d $rchat_lb_domainName"
        # run_command "certbot certonly --nginx -d $rchat_lb_domainName"
        # run_command "certbot --nginx "
        # certbot --nginx --agree-tos --no-eff-email --redirect --email your_email@example.com -d ${DOMAIN_NAME}
        run_command certbot --nginx --agree-tos --no-eff-email --redirect -d ${rchat_lb_domainName}

    else
        run_command "echo \"SSL certificate already exist\""
    fi

    return 0
}
# }}}
# ------------------------------------------------------------------

# ******************************************************************
# * {{{ removeetSslCerts
# *
# *******************************************************************
removeCerts() {
    run_command checkSudoOrRoot
    nowDateTime=$(date +"%Y-%m-%d-%H:%m:%S")
    tmpSslDir="/tmp/etc-ssl-$nowDateTime"
    tmpLetsEncDir="/tmp/etc-letsencrypt-$nowDateTime"
    if [ -d /etc/ssl ]; then
        run_command mkdir $tmpSslDir
        run_command cp -r /etc/ssl/* $tmpSslDir

        run_command mkdir $tmpLetsEncDir
        run_command cp -r /etc/letsencrypt/* $tmpLetsEncDir
    fi
    run_command certbot delete -n --cert-name $rchat_lb_domainName --all
}
# }}}
# ------------------------------------------------------------------


# *******************************************************************
# * {{{ setupSslRenewal
# *
# *******************************************************************
setupSslRenewal() {
    run_command checkSudoOrRoot

    # Set up automatic renewal of the SSL certificate
    if [ ! -f "/etc/cron.d/certbot" ]; then
        run_command "echo \"Creating cronjob for certbot\""
        run_command "echo \"30 2 * * 1 /usr/bin/certbot renew >> /var/log/le-renew.log\" > /etc/cron.d/certbot"
    else
        run_command "echo \"cronjob for certbot already exist\""
    fi
}
# }}}
# ------------------------------------------------------------------


# *******************************************************************
# * {{{ createNginxDirs
# *
# *******************************************************************
createNginxDirs() {
    run_command checkSudoOrRoot
    # Create the /etc/letsencrypt and /var/lib/letsencrypt directories
    if [ ! -d "/etc/letsencrypt" ]; then
        run_command mkdir -p /etc/letsencrypt
    fi
    run_command chmod 700 /etc/letsencrypt
    if [ ! -d "/var/lib/letsencrypt" ]; then
        run_command mkdir -p /var/lib/letsencrypt
    fi
    run_command chmod 700 /var/lib/letsencrypt
}
# }}}
# ------------------------------------------------------------------


# *******************************************************************
# * {{{ main
# *
# *******************************************************************
# Main function
main() {
    local args=("$@")
    run_command define_pkgs_Nginx

    run_command pkgs_main "${args[@]}"
}
# }}} 
# ------------------------------------------------------------------

main ${args[@]}

