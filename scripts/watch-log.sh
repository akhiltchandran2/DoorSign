#!/usr/bin/env bash
# Streams the app's status changes. Leave this running in a terminal while testing.
exec log stream --predicate 'subsystem == "com.company.doorsign"' --level info
