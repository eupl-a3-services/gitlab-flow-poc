sed -i '/^PS1=/d' /root/.bashrc
echo 'PS1="\[\033[0;31m\]\u\[\033[0m\]\[\033[0;33m\]@\[\033[0;36m\]\h:\w\$ \[\033[0m\]"' >> /root/.bashrc
source /root/.bashrc