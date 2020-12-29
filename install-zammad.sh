#!/bin/bash

set -ex

# set env
export DEBIAN_FRONTEND=noninteractive

# updating package list
apt-get update

# install dependencies
apt-get --no-install-recommends -y install apt-transport-https ca-certificates-java curl libimlib2 libimlib2-dev libterm-readline-perl-perl locales memcached net-tools nginx default-jdk mc mcedit less psmisc strace

# install postfix
echo "postfix postfix/main_mailer_type string Internet site" > preseed.txt
debconf-set-selections preseed.txt
apt-get --no-install-recommends install -q -y postfix

# install postgresql server
locale-gen en_US.UTF-8
localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
echo "LANG=en_US.UTF-8" > /etc/default/locale
apt-get --no-install-recommends install -q -y postgresql

# configure elasticsearch repo & key
curl -s -J -L -o - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -
echo "deb https://artifacts.elastic.co/packages/oss-7.x/apt stable main" | tee -a /etc/apt/sources.list.d/elastic-7.x.list

# updating package list again
apt-get update

# install elasticsearch & attachment plugin
update-ca-certificates -f
apt-get --no-install-recommends -y install elasticsearch-oss
cd /usr/share/elasticsearch && bin/elasticsearch-plugin install -b ingest-attachment
service elasticsearch start

# create zammad user
useradd -M -d "${ZAMMAD_DIR}" -s /bin/bash zammad

