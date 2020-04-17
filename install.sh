#!/bin/bash -e

# Since it sets an environment variable, the aws-profile
# helper must be installed as a bash function
if ! grep -q 'function aws-profile' ~/.bash_profile; then
  echo >> ~/.bash_profile
  cat aws-profile >> ~/.bash_profile
fi

# Install the credential helper as an executable
cp aws-whoami aws-refresh-credentials /usr/local/bin/

# Finally configure bash completion for the above tools
cp aws-profile-completion.bash /usr/local/etc/bash_completion.d/
