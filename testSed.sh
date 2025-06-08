#!/usr/local/bin/bash

# Constants
server_name="rchat-lb.testing.org"
nginx_config_file="/etc/nginx/nginx.conf"

server_block="
    server {
        listen 80;
        server_name rchat-lb.testing.org;

        location / {
            # proxy_pass http://127.0.0.1:3000;
            proxy_pass http://159.89.126.222:3000;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection \"upgrade\";
            proxy_set_header Host \$host;
            proxy_cache_bypass \$http_upgrade;
        }
    }
"


# Function to write the server block to the nginx config file
write_server_block() {
    # if ! grep -q "server_name rchat-lb.testing.org" /etc/nginx/nginx.conf; then
    if ! grep -q "server_name $server_name" "$nginx_config_file"; then
        # sed -i "/http {/a \\
        # ${server_block}" /etc/nginx/nginx.conf

        # awk -v server_block="$server_block" '
        # /http {/ {
            # print $0
            # print server_block
        # }
        # {
            # print $0
        # }
        #' "$nginx_config_file" > "$nginx_config_file".tmp && mv "$nginx_config_file".tmp "$nginx_config_file"

        awk -v server_block="$server_block" -v server_name="$server_name" 'BEGIN { indent=0 }
        /http {/ { print; print server_block; indent=1; next }
        { if ( indent ) print "    " $0 
          else print } ' "$nginx_config_file" > "$nginx_config_file.tmp" && mv "$nginx_config_file.tmp" "$nginx_config_file"

        echo "Server block added to Nginx configuration file."
    else
        echo "Server block already present in Nginx configuration file."
    fi
}

write_server_block
