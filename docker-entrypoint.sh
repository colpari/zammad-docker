#!/bin/bash

set -e

rm -f /stop

trap /zammad-stop.sh SIGKILL

if [ "$1" = 'zammad' ]; then

  SERVICES="postgresql elasticsearch postfix memcached nginx"

  for s in $SERVICES
  do
    # using restart to circumvent possibly existing pid files
    echo "Starting $s"
    service "$s" restart
  done

  # wait for postgres to come up
  until su - postgres -c 'psql -c "select version()"' &> /dev/null; do
    echo "Waiting for PostgreSQL to be ready..."
    sleep 2
  done

  cd "${ZAMMAD_DIR}"

  rm -vf tmp/pids/*

  SET_UP_FILE="set-up-docker-$(hostname)"
  if ! ls -l "$SET_UP_FILE"
  then
    echo -e "\n Setting up... \n"
    /zammad-setup.sh
    touch "$SET_UP_FILE"
  fi

  /zammad-wsserver-loop.sh &
  /zammad-scheduler-loop.sh &

  echo "Starting rails server..."

  # start railsserver
  if [ "${RAILS_SERVER}" == "puma" ]; then
    while ! test -f /stop ; do su -c "bundle exec puma -b tcp://0.0.0.0:3000 -e ${RAILS_ENV}" zammad || sleep 1; done
  elif [ "${RAILS_SERVER}" == "unicorn" ]; then
    while ! test -f /stop ; do su -c "bundle exec unicorn -p 3000 -c config/unicorn.rb -E ${RAILS_ENV}" zammad || sleep 1; done
  fi

  for s in $SERVICES
  do
    echo "Stopping $s"
    service "$s" stop
  done

  echo "docker-entrypoint.sh EXIT"

else
    exec "$@"
fi
