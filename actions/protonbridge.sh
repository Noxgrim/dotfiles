#!/usr/bin/env bash
pass show .sentinel || exit
systemctl --user restart protonmail-bridge.service
