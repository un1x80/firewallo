# firewallo
Firewallo is a firewall manager for Debian GNU/Linux that uses iptables or nftables. This project was born in 2003 for personal use. If you think this is interesting for you, write to me, and you'll make me happy.

## 📌Supported OS

- Debian 12
  

## 🎇Install

get latest version from [Releases · un1x80/firewallo · GitHub](https://github.com/un1x80/firewallo/releases)

```bash
wget https://github.com/un1x80/firewallo/releases/download/current/firewallo-24.9.1.10-amd64.deb
apt install ./firewallo-24.9.1.10-amd64.deb -y
```

## 🔐Basic usage
Exec firewallo from a root shell and select a number of configuration menu. 

## 🛠️Build 
LOCAL Build 
```bash
git clone -b <main|test> https://github.com/un1x80/firewallo.git
cd firewallo/usr/share/doc/firewallo/ ; ./build.sh local 
```
or GIT BUILD Test or Main
```
wget https://raw.githubusercontent.com/un1x80/firewallo/main/usr/share/doc/firewallo/build.sh
chmod +x build.sh ; ./build.sh git <main|test>
```


## 💣Uninstall

```bash
apt autoremove firewallo -y
```