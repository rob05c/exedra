#!/usr/bin/env bash
PRIVDIR="priv/exedra"
mkdir -p "$PRIVDIR"
rm -f "$PRIVDIR/ssh_host_rsa_key*"
ssh-keygen -t rsa -P "" -f "$PRIVDIR/ssh_host_rsa_key"
