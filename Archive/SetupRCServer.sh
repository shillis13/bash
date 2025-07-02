#!/usr/local/bin/bash
# This script should be run as the new user.

thisFile="${BASH_SOURCE[0]}"

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then args=("${@:1}")
else args=("${@}"); fi

source bashLibrary_base.sh "${args[@]}"


# # ****************************************************
# {{{ @name: install_tools()
# *
# * 
# ****************************************************
install_tools() {
    sudo apt-get update
    sudo apt-get install -y vim curl git htop fail2ban ufw sysstat
}
# }}}
# ****************************************************


# # ****************************************************
# {{{ @name: setup_firewall()
# *
# * 
# ****************************************************
setup_firewall() {
    sudo ufw allow OpenSSH
    sudo ufw enable
}
# }}}
# ****************************************************


# # ****************************************************
# {{{ @name: install_docker()
# *
# * 
# ****************************************************
install_docker() {
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker "$(whoami)"
    rm get-docker.sh
}
# }}}
# ****************************************************


# # ****************************************************
# {{{ @name: install_docker_compose()
# *
# * 
# ****************************************************
install_docker_compose() {
    sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
}
# }}}
# ****************************************************

# # ****************************************************
# {{{ @name: setup_rocket_chat()
# *
# * 
# ****************************************************
setup_rocket_chat() {
    mkdir -p ~/rocket-chat
    cd ~/rocket-chat
    cat << EOF > docker-compose.yml
version: '3'
services:
  rocketchat:
    image: rocket.chat:latest
    restart: unless-stopped
    volumes:
      - ./uploads:/app/uploads
    environment:
      - PORT=3000
      - ROOT_URL=http://localhost:3000
      - MONGO_URL=mongodb://mongo:27017/rocketchat
      - MONGO_OPLOG_URL=mongodb://mongo:27017/local
    depends_on:
      - mongo
    ports:
      - 3000:3000

  mongo:
    image: mongo:4.0
    restart: unless-stopped
    volumes:
      - ./data/db:/data/db
      - ./data/dump:/dump
    command: mongod --oplogSize 128 --replSet rs0 --bind_ip_all
    ports:
      - 27017:27017

  mongo-init-replica:
    image: mongo:4.0
    command: 'bash -c "for i in `seq 1 30`; do mongo mongo/rocketchat --eval \"rs.initiate({ _id: '\''rs0'\'', members: [ { _id: 0, host: '\''localhost:27017'\'' } ]})\" && s=$$? && break || s=$$?; echo \"Tried $$i times. Waiting 5 secs...\"; sleep 5; done; (exit $$s)"'
    depends_on:
      - mongo
EOF

    docker-compose up -d
}
# }}}
# ****************************************************


# # ****************************************************
# {{{ @name: install_nginx()
# *
# * 
# ****************************************************
install_nginx() {
    sudo apt-get install -y nginx
}
# }}}
# ****************************************************


# # ****************************************************
# {{{ @name: configure_nginx()
# *
# * 
# ****************************************************
configure_nginx() {
    local domain_name="$1"

    sudo cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.bak
    sudo tee /etc/nginx/sites-available/default >/dev/null << EOF
server {
    listen 80;
    server_name $domain_name;
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host \$host;
    }
}
EOF

    sudo systemctl restart nginx
}
# }}}
# ****************************************************


# # ****************************************************
# {{{ @name: install_certbot()
# *
# * 
# ****************************************************
install_certbot() {
    sudo apt-get install -y certbot
}
# }}}
# ****************************************************


# # ****************************************************
# {{{ @name: install_certbot_nginx()
# *
# * 
# ****************************************************
install_certbot_nginx() {
    sudo apt-get install -y python3-certbot-nginx
}
# }}}
# ****************************************************


# # ****************************************************
# {{{ @name: request_ssl_certificate()
# *
# * 
# ****************************************************
request_ssl_certificate() {
    local domain_name="$1"
    local email="$2"

    sudo certbot --nginx -d "$domain_name" --non-interactive --agree-tos --email "$email"
}
# }}}
# ****************************************************

# # ****************************************************
# {{{ @name: update_nginx_ssl
# *
# * 
# ****************************************************
update_nginx_ssl() {
    local domain_name="$1"

    sudo tee /etc/nginx/sites-available/default >/dev/null << EOF
server {
    listen 80;
    server_name $domain_name;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $domain_name;

    ssl_certificate /etc/letsencrypt/live/$domain_name/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$domain_name/privkey.pem;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host \$host;
    }
}
EOF

    sudo systemctl restart nginx
}
# }}}
# ****************************************************

# # ****************************************************
# {{{ @name: define_operations
# *
# * 
# ****************************************************
define_operations() {
    add_operation "installTools" true "--installTools" "\t--installTools\tInstall common tools and utilities" "install_tools"
    add_operation "setupFirewall" true "--setupFirewall" "\t--setupFirewall\tSet up firewall and allow SSH" "setup_firewall"
    add_operation "installDocker" true "--installDocker" "\t--installDocker\tInstall Docker" "install_docker"
    add_operation "installDockerCompose" true "--installDockerCompose" "\t--installDockerCompose\tInstall Docker Compose" "install_docker_compose"
    add_operation "setupRocketChat" true "--setupRocketChat" "\t--setupRocketChat\tSet up Rocket.Chat and MongoDB using Docker Compose" "setup_rocket_chat"
    add_operation "installNginx" true "--installNginx" "\t--installNginx\tInstall Nginx" "install_nginx"
    add_operation "configureNginx" true "--configureNginx" "\t--configureNginx\tConfigure Nginx with your domain name" "configure_nginx"
    add_operation "installCertbot" true "--installCertbot" "\t--installCertbot\tInstall Certbot for SSL certificates" "install_certbot"
    add_operation "installCertbotNginx" true "--installCertbotNginx" "\t--installCertbotNginx\tInstall Certbot Nginx plugin" "install_certbot_nginx"
    add_operation "requestSSLCertificate" true "--requestSSLCertificate" "\t--requestSSLCertificate\tRequest SSL certificate for your domain name" "request_ssl_certificate"
    add_operation "updateNginxSSL" true "--updateNginxSSL" "\t--updateNginxSSL\tUpdate Nginx configuration for SSL" "update_nginx_ssl"
}
# }}}
# ****************************************************

# Main
parse_arguments "${args[@]}"
execute_operations

