# gitlab-runner

## install gitlab-runner
```
# https://docs.gitlab.com/runner/install/linux-repository/
sudo -i

# set timezone

date
timedatectl set-timezone Europe/Bratislava
date

# install

apt-get update
apt-get install -y docker.io mc

mkdir -p /cache-volume
chown -R gitlab-runner:gitlab-runner /cache-volume
chmod -R 777 /cache-volume
ls -ld /cache-volume

curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | sudo bash
apt install gitlab-runner -y

```

## command to configure runner
```
cat /etc/gitlab-runner/config.toml

###### add this on top ######
concurrent = 10
check_interval = 0


sed -i '1s/.*/concurrent = 10/' /etc/gitlab-runner/config.toml
```

## Useges
```
docker system df
```

## Cleanup
```
docker system prune -a --volumes -f
```