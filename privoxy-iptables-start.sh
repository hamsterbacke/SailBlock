#!/bin/bash
/sbin/iptables -A OUTPUT -t nat ! -d 127.0.0.1 -p tcp --dport 80 -m owner ! --uid-owner privoxy -j REDIRECT --to-ports 8118
/sbin/iptables -A POSTROUTING -t nat -o lo -p tcp --dport 8118 -j SNAT --to 127.0.0.1
