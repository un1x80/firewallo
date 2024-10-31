#!/bin/bash
#Questo script fa la build da locale o dal git 
#uso ./build -> per il git ./build local per locale
TYPE=$1
# Abilita modalità "exit on error"
set -e

# Verifica che lo script sia eseguito con permessi di root
if [ "$EUID" -ne 0 ]; then
  echo "Please execute as root"
  exit 1
fi

# Funzione per installare un pacchetto se non è già installato
install_if_not_present() {
  if ! dpkg -s "$1" >/dev/null 2>&1; then
    echo "Instal $1..."
    apt update
    apt install -y "$1"
  fi
}

# Installazione dei pacchetti necessari
install_if_not_present git
install_if_not_present iptables
install_if_not_present nftables
install_if_not_present dpkg-dev

# Creazione della directory di destinazione
mkdir -p /opt/firewallo
chown root:root /opt/firewallo
chmod 0755 /opt/firewallo

#Verifica se fare install locale o dal git clone
if [ "$TYPE" =  ""  ]; then
  # Clonazione del repository di firewallo
  echo "Clone firewallo repo..."
  git clone https://github.com/un1x80/firewallo.git /opt/firewallo --branch main --single-branch
elif [ "$TYPE" = "local" ]; then
  # Copia di firewallo su /opt/firewallo
  wd=$(pwd)
  if [[ "$wd" =~ usr/share/doc/firewallo$ ]]; then
	  cp -rf ../../../../* /opt/firewallo
  else
      echo "I am not in the correct position to be executed. right position : 'firewallo-dir/usr/share/doc/firewallo/'."
      exit 1
  fi
fi

# Creazione della struttura del pacchetto .deb
mkdir -p /opt/firewallo_pkg/DEBIAN
chmod 0755 /opt/firewallo_pkg/DEBIAN

# Creazione del file control per il pacchetto .deb
cat <<EOF > /opt/firewallo_pkg/DEBIAN/control
Package: firewallo
Version: 24.9.1-current
Section: utils
Priority: optional
Architecture: all
Depends: bash (>= 4.0), coreutils, iptables, nftables, suricata, nano
Maintainer: Matteo Fioriti <fioritim@gmail.com>
Description: Firewallo is a firewall manager for Debian GNU/Linux that uses iptables or nftables.
 Questo pacchetto include un sistema di gestione del firewall basato su iptables e nftables.
EOF

# Copia delle directory etc e usr dal repository clonato
cp -r /opt/firewallo/etc /opt/firewallo_pkg/
cp -r /opt/firewallo/usr /opt/firewallo_pkg/

# Creazione dello script postinst per la configurazione post-installazione
cat <<'EOF' > /opt/firewallo_pkg/DEBIAN/postinst
#!/bin/bash

# Installare Suricata se non è già installato
if ! dpkg -s suricata >/dev/null 2>&1; then
    apt update
    apt install -y suricata
fi

# Copia del file suricata.yaml personalizzato
if [ ! -f /etc/suricata/suricata.yaml ]; then
  install -m 644 /opt/firewallo_pkg/usr/local/firewallo/ansible/postinst/suricata.yaml /etc/suricata/suricata.yaml
else
  mv /etc/suricata/suricata.yaml /etc/suricata/suricata.yaml.bck
  install -m 644 /opt/firewallo_pkg/usr/local/firewallo/ansible/postinst/suricata.yaml /etc/suricata/suricata.yaml
fi

# Copia del file suricata.service personalizzato
install -m 644 /opt/firewallo_pkg/usr/local/firewallo/ansible/postinst/suricata.service /lib/systemd/system/suricata.service

# Creazione della directory di configurazione di firewallo
mkdir -p /etc/firewallo

# Copia dei file di configurazione
for file in /opt/firewallo_pkg/etc/firewallo/*; do
  filename=$(basename "$file")
  if [ ! -f "/etc/firewallo/$filename" ]; then
    install -m 644 "$file" "/etc/firewallo/$filename"
  fi
done

# Ricaricare il daemon di systemd
systemctl daemon-reload

# Avviare il servizio Suricata
systemctl start suricata

# Abilitare Suricata all'avvio del sistema
systemctl enable suricata

exit 0
EOF

# Imposta i permessi di esecuzione sullo script postinst
chmod 0755 /opt/firewallo_pkg/DEBIAN/postinst

# Costruzione del pacchetto .deb
echo "Creazione del pacchetto .deb..."
dpkg-deb --build /opt/firewallo_pkg

# Verifica se il pacchetto è stato creato
if [ -f /opt/firewallo_pkg.deb ]; then
  echo ".deb successfully build : /opt/firewallo_pkg.deb"
else
  echo "Error : error on build .deb !"
  exit 1
fi

# Disinstallazione di una eventuale vecchia versione di firewallo
apt remove -y firewallo || true

# Installazione del nuovo pacchetto .deb
echo "Installazione del pacchetto .deb..."
apt install -y /opt/firewallo_pkg.deb

echo "Install ok!"
