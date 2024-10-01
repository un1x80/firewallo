# firewallo
Firewallo is a firewall manager for Debian GNU/Linux that uses iptables or nftables. This project was born in 2003 for personal use. If you think this is interesting for you, write to me, and you'll make me happy.

## 📌Supported OS

- Debian 12
  

## 🎇Install

get latest version from [Releases · un1x80/firewallo · GitHub](https://github.com/un1x80/firewallo/releases)

```bash
wget https://github.com/un1x80/firewallo/releases/download/24.9.1/firewallo-24.9.1-amd64.deb
apt install ./firewallo-24.9.1-amd64.deb -y
```

## 🔐Basic usage
WIP

## 🛠️Build

```bash
git clone https://github.com/un1x80/firewallo.git
dpkg-deb --build firewallo/ firewallo.deb
```

## 💣Uninstall

```bash
apt autoremove firewallo -y
```