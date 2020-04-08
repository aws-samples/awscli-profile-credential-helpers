#!/usr/bin/env bash

profiles="$(grep '\[profile' ~/.aws/config | tr -d '\[\]' | awk '{print $2}')"

complete -W "${profiles}" aws-profile
complete -W "${profiles}" aws-refresh-credentials
