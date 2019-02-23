# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
    export PATH=$PATH:/usr/local/ibmcloud/bin
    . /etc/bashrc
fi

if [ -f /etc/profile ]; then
    export PATH=$PATH:/usr/local/ibmcloud/bin
    . /etc/profile
fi
