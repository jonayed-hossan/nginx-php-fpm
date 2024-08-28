#!/bin/bash

# Enable Static Only
if [ ! -z "$STATIC_SERVER" ]; then
 cp -vf /var/www/app-conf/nginx-static-server.conf /etc/nginx/http.d/default.conf
fi

# Set custom webroot
if [ ! -z "$WEBROOT" ]; then
 sed -i "s#root /var/www/app/public;#root ${WEBROOT};#g" /etc/nginx/http.d/default.conf
else
 webroot=/var/www/app/public
fi

#file="extra.sh"

# Start supervisord and services
exec /usr/bin/supervisord -n -c /etc/supervisord.conf
