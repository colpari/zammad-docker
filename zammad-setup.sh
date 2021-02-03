#!/bin/bash

set -ex

# set env
export DEBIAN_FRONTEND=noninteractive

cd "${ZAMMAD_DIR}"

NCPUS=$(egrep -c "^processor" /proc/cpuinfo)

# install zammad
if [ "${RAILS_ENV}" == "production" ]; then
  bundle install --jobs $NCPUS --without test development mysql
elif [ "${RAILS_ENV}" == "development" ]; then
  bundle install --jobs $NCPUS --without mysql
else
  echo "unsupported RAILS_ENV: '${RAILS_ENV}'"
  exit 77
fi

#bundle install ${RAILS_SERVER}

# fetch locales
contrib/packager.io/fetch_locales.rb

# try to create db & user - if database.yml exists we assume the DB is already set up
if ! test -f "${ZAMMAD_DIR}"/config/database.yml
then
    su - postgres -c "createdb -E UTF8 ${ZAMMAD_DB}"
    ZAMMAD_DB_PASS="$(tr -dc A-Za-z0-9 < /dev/urandom | head -c10)"
    echo "CREATE USER \"${ZAMMAD_DB_USER}\" WITH PASSWORD '${ZAMMAD_DB_PASS}';" | su - postgres -c psql
    echo "GRANT ALL PRIVILEGES ON DATABASE \"${ZAMMAD_DB}\" TO \"${ZAMMAD_DB_USER}\";" | su - postgres -c psql

    # create database.yml
    sed -e "s#production:#${RAILS_ENV}:#" -e "s#.*adapter:.*#  adapter: postgresql#" -e "s#.*username:.*#  username: ${ZAMMAD_DB_USER}#" -e "s#.*password:.*#  password: ${ZAMMAD_DB_PASS}#" -e "s#.*database:.*#  database: ${ZAMMAD_DB}\n  host: localhost#" < "${ZAMMAD_DIR}"/contrib/packager.io/database.yml.pkgr > "${ZAMMAD_DIR}"/config/database.yml
fi

# enable memcached
sed -i -e "s/.*config.cache_store.*file_store.*cache_file_store.*/    config.cache_store = :dalli_store, '127.0.0.1:11211'\n    config.session_store = :dalli_store, '127.0.0.1:11211'/" config/application.rb

# populate database
bundle exec rake db:migrate
bundle exec rake db:seed

# assets precompile
bundle exec rake assets:precompile

# delete assets precompile cache
rm -r tmp/cache

# create es searchindex
bundle exec rails r "Setting.set('es_url', 'http://localhost:9200')"
bundle exec rake searchindex:rebuild

# create nginx zammad config
sed -e "s#server_name localhost#server_name _#g" < "${ZAMMAD_DIR}"/contrib/nginx/zammad.conf > /etc/nginx/sites-enabled/default
ln -sf /dev/stdout /var/log/nginx/access.log 
ln -sf /dev/stderr /var/log/nginx/error.log

mkdir -vp "${ZAMMAD_DIR}/tmp/pids"
chown -R "${ZAMMAD_USER}:${ZAMMAD_USER}" "${ZAMMAD_DIR}"

service nginx restart
