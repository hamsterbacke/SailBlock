#!/bin/bash
systemctl stop privoxy.service
rm -f /lib/systemd/system/privoxy.service
rm -f /lib/systemd/system/privoxy_update.timer
rm -f /lib/systemd/system/privoxy_update.service
systemctl daemon-reload
userdel -r privoxy > /dev/null
