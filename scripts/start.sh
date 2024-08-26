#!/bin/bash

# Disable Strict Host checking for non interactive git clones

mkdir -p -m 0700 /root/.ssh
# Prevent config files from being filled to infinity by force of stop and restart the container 
echo "" > /root/.ssh/config
echo -e "Host *\n\tStrictHostKeyChecking no\n" >> /root/.ssh/config

if [[ "$GIT_USE_SSH" == "1" ]] ; then
  echo -e "Host *\n\tUser ${GIT_USERNAME}\n\n" >> /root/.ssh/config
fi

if [ ! -z "$SSH_KEY" ]; then
 echo $SSH_KEY > /root/.ssh/id_rsa.base64
 base64 -d /root/.ssh/id_rsa.base64 > /root/.ssh/id_rsa
 chmod 600 /root/.ssh/id_rsa
fi

# Set custom webroot
if [ ! -z "$WEBROOT" ]; then
 sed -i "s#root /var/www/app/public;#root ${WEBROOT};#g" /etc/nginx/http.d/default.conf
else
 webroot=/var/www/app/public
fi

# Enables 404 pages through php index
if [ ! -z "$PHP_CATCHALL" ]; then
 sed -i 's#try_files $uri $uri/ =404;#try_files $uri $uri/ /index.php?$args;#g' /etc/nginx/http.d/default.conf
fi

# Disable opcache
if [ ! -z "$OPcache" ]; then
 sed -i 's#zend_extension=opcache#;zend_extension=opcache#g' /usr/local/etc/php/php.ini
fi

# Setup git variables
if [ ! -z "$GIT_EMAIL" ]; then
 git config --global user.email "$GIT_EMAIL"
fi
if [ ! -z "$GIT_NAME" ]; then
 git config --global user.name "$GIT_NAME"
 git config --global push.default simple
fi

# Dont pull code down if the .git folder exists
if [ ! -d "/var/www/app/.git" ]; then
 # Pull down code from git for our site!
 if [ ! -z "$GIT_REPO" ]; then
   # Remove the test index file if you are pulling in a git repo
   if [ ! -z ${REMOVE_FILES} ] && [ ${REMOVE_FILES} == 0 ]; then
     echo "skiping removal of files"
   else
     rm -Rf /var/www/app/*
   fi
   GIT_COMMAND='git clone '
   if [ ! -z "$GIT_BRANCH" ]; then
     GIT_COMMAND=${GIT_COMMAND}" -b ${GIT_BRANCH}"
   fi

   if [ -z "$GIT_USERNAME" ] && [ -z "$GIT_PERSONAL_TOKEN" ]; then
     GIT_COMMAND=${GIT_COMMAND}" ${GIT_REPO}"
   else
    if [[ "$GIT_USE_SSH" == "1" ]]; then
      GIT_COMMAND=${GIT_COMMAND}" ${GIT_REPO}"
    else
      GIT_COMMAND=${GIT_COMMAND}" https://${GIT_USERNAME}:${GIT_PERSONAL_TOKEN}@${GIT_REPO}"
    fi
   fi
   ${GIT_COMMAND} /var/www/app || exit 1
   if [ ! -z "$GIT_TAG" ]; then
     git checkout ${GIT_TAG} || exit 1
   fi
   if [ ! -z "$GIT_COMMIT" ]; then
     git checkout ${GIT_COMMIT} || exit 1
   fi
   if [ -z "$SKIP_CHOWN" ]; then
     chown -Rf nginx.nginx /var/www/app
   fi
 fi
fi

# Enable custom nginx config files if they exist
if [ -f /var/www/app/conf/nginx/nginx.conf ]; then
  cp /var/www/app/conf/nginx/nginx.conf /etc/nginx/nginx.conf
fi

if [ -f /var/www/app/conf/nginx/nginx-server.conf ]; then
  cp /var/www/app/conf/nginx/nginx-server.conf /etc/nginx/http.d/default.conf
fi

if [ -f /var/www/app/conf/nginx/nginx-site-ssl.conf ]; then
  cp /var/www/app/conf/nginx/nginx-site-ssl.conf /etc/nginx/sites-available/default-ssl.conf
fi


# Prevent config files from being filled to infinity by force of stop and restart the container
lastlinephpconf="$(grep "." /usr/local/etc/php-fpm.conf | tail -1)"
if [[ $lastlinephpconf == *"php_flag[display_errors]"* ]]; then
 sed -i '$ d' /usr/local/etc/php-fpm.conf
fi

# Display PHP error's or not
if [[ "$ERRORS" != "1" ]] ; then
 echo php_flag[display_errors] = off >> /usr/local/etc/php-fpm.d/www.conf
else
 echo php_flag[display_errors] = on >> /usr/local/etc/php-fpm.d/www.conf
fi

# Display Version Details or not
if [[ "$HIDE_NGINX_HEADERS" == "0" ]] ; then
 sed -i "s/server_tokens off;/server_tokens on;/g" /etc/nginx/nginx.conf
else
 sed -i "s/expose_php = On/expose_php = Off/g" /usr/local/etc/php-fpm.conf
fi

# Set the desired timezone
echo date.timezone=UTC > /usr/local/etc/php/conf.d/timezone.ini

# Display errors in docker logs
if [ ! -z "$PHP_ERRORS_STDERR" ]; then
  echo "log_errors = On" >> /usr/local/etc/php/conf.d/php-custom.ini
  echo "error_log = /dev/stderr" >> /usr/local/etc/php/conf.d/php-custom.ini
fi

# Increase the memory_limit
if [ ! -z "$PHP_MEM_LIMIT" ]; then
 sed -i "s/memory_limit = 256M/memory_limit = ${PHP_MEM_LIMIT}M/g" /usr/local/etc/php/conf.d/php-custom.ini
fi

# Increase the post_max_size
if [ ! -z "$PHP_POST_MAX_SIZE" ]; then
 sed -i "s/post_max_size = 4G/post_max_size = ${PHP_POST_MAX_SIZE}M/g" /usr/local/etc/php/conf.d/php-custom.ini
fi

# Increase the upload_max_filesize
if [ ! -z "$PHP_UPLOAD_MAX_FILESIZE" ]; then
 sed -i "s/upload_max_filesize = 4G/upload_max_filesize= ${PHP_UPLOAD_MAX_FILESIZE}M/g" /usr/local/etc/php/conf.d/php-custom.ini
fi

if [ ! -z "$PUID" ]; then
  if [ -z "$PGID" ]; then
    PGID=${PUID}
  fi
  deluser nginx
  addgroup -g ${PGID} nginx
  adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx -u ${PUID} nginx
else
  if [ -z "$SKIP_CHOWN" ]; then
    chown -Rf nginx.nginx /var/www/app
  fi
fi

# Run custom scripts
if [[ "$RUN_SCRIPTS" == "1" ]] ; then
  scripts_dir="${SCRIPTS_DIR:-/var/www/app/scripts}"
  if [ -d "$scripts_dir" ]; then
    if [ -z "$SKIP_CHMOD" ]; then
      # make scripts executable incase they aren't
      chmod -Rf 750 $scripts_dir; sync;
    fi
    # run scripts in number order
    for i in `ls $scripts_dir`; do $scripts_dir/$i ; done
  else
    echo "Can't find script directory"
  fi
fi

if [ -z "$SKIP_COMPOSER" ]; then
    # Try auto install for composer
    if [ -f "/var/www/app/composer.lock" ]; then
        if [ "$APPLICATION_ENV" == "development" ]; then
            composer global require hirak/prestissimo
            composer install --working-dir=/var/www/app
        else
            composer global require hirak/prestissimo
            composer install --no-dev --working-dir=/var/www/app
        fi
    fi
fi

# Start supervisord and services
exec /usr/bin/supervisord -n -c /etc/supervisord.conf
