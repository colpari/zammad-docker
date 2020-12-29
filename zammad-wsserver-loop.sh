#!/bin/bash

set -e

while ! test -f /stop
do
    echo -e "Starting websocket-server.rb..."
    su -c "bundle exec script/websocket-server.rb -b 0.0.0.0 start" zammad
    sleep 1
    while pgrep -u zammad -if ^script/websocket-server.rb >/dev/null; do sleep 1; done
done
