#!/bin/sh
if test -r /etc/profile; then . /etc/profile; fi
if test -r "$HOME/.profile"; then . "$HOME/.profile"; fi
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec startxfce4
