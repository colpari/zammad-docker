#!/bin/bash

set -e

while ! test -f /stop
do
    echo -e "Starting scheduler.rb..."
    su -c "bundle exec script/scheduler.rb start" zammad
    sleep 1
    while pgrep -u zammad -if ^scheduler >/dev/null; do sleep 1; done
done
