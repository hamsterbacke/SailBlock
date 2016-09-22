#!/bin/bash
# install service file
cat <<-'________EOF' >> /lib/systemd/system/privoxy.service
	[Unit]
	Description=Privacy enhancing HTTP Proxy
	
	[Service]
	Environment=PIDFILE=/var/run/privoxy.pid
	Environment=OWNER=privoxy
	Environment=GROUP=privoxy
	Environment=CONFIGFILE=/usr/local/etc/privoxy/config
	Type=forking
	PIDFile=/var/run/privoxy.pid
	ExecStart=/usr/local/sbin/privoxy --pidfile ${PIDFILE} --user ${OWNER}.${GROUP} ${CONFIGFILE}
	ExecStartPost=/usr/local/etc/privoxy/privoxy-iptables-start.sh
	ExecStop=/usr/local/etc/privoxy/privoxy-iptables-stop.sh
	ExecStopPost=/bin/rm -f ${PIDFILE}
	
	[Install]
	WantedBy=multi-user.target
________EOF
cat <<-'________EOF' >> /lib/systemd/system/privoxy_update.service
	[Unit]
	Description=this updates the privoxy blocklist lists
	
	[Service]
	Type=simple
	ExecStart=/usr/local/etc/privoxy/controller.sh
________EOF
cat <<-'________EOF' >> /lib/systemd/system/privoxy_update.timer
	[Unit]
	Description=Runs privoxy blocklist updater every hour
	
	[Timer]
	# Time to wait after booting before we run first time
	OnBootSec=10min
	# Time between running each consecutive time
	OnUnitActiveSec=1h
	Unit=privoxy_update.service
	
	[Install]
	WantedBy=multi-user.target
________EOF
systemctl daemon-reload
systemctl enable privoxy.service
systemctl start privoxy.service
systemctl enable privoxy_update.timer
systemctl start privoxy_update.timer
chown privoxy:privoxy -R /usr/local/etc/privoxy/
