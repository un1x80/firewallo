#!/bin/bash
#Questo script fa la build da locale o dal git 
#uso ./build git -> per il git ./build local per locale
TYPE=$1
DATE=$(date +"%y-%m-%d-%H_%M")
UNINST="" #Yes se vuoi che la vecchia versione venga disistallata e non aggiornata
# Abilita modalità "exit on error"
set -e
#
# Verifica che lo script sia eseguito con permessi di root
if [ "$EUID" -ne 0 ]; then
  echo "Please execute as root"
  exit 1
fi
#Controllo se c'è almeno un parametro
if [ "$1" = "" ] ; then
  echo "usage with git: $0 <git> <main|test>
  usage with local: $0 <local>"
  exit 1
fi

#Controllo se c'è almeno un altro parametro
if [ "$2" != "main" && "$2" != "test" ] ; then
  echo "usage with git: $0 <git> <main|test>"
  exit 1
fi

#Rimuovo le vecchie build se ci sono
if [ -e /opt/firewallo ] && [ -e /opt/firewallo_pkg ] ; then 
  rm -rf /opt/firewallo ; 
  rm -rf /opt/firewallo_pkg ; 
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
if [ "$TYPE" =  "git"  ]; then
  # Clonazione del repository di firewallo
  echo "Clone firewallo repo..."
  git clone https://github.com/un1x80/firewallo.git /opt/firewallo --branch $2 --single-branch

elif [ "$TYPE" = "local" ]; then
  # Copia di firewallo su /opt/firewallo
  wd=$(pwd)
  if [[ "$wd" =~ usr/share/doc/firewallo$ ]]; then
	  cp -rf ../../../../* /opt/firewallo
  else
      echo "I am not in the correct position to be executed. right position : '<firewallo-dir>/usr/share/doc/firewallo/'."
      exit 1
  fi
fi

# Creazione della struttura del pacchetto .deb
mkdir -p /opt/firewallo_pkg/DEBIAN
chmod 0755 /opt/firewallo_pkg/DEBIAN
VERSION=$(cat /opt/firewallo/etc/firewallo/firewallo.conf| grep VERS| tr -d "\"" | cut -d '=' -f 2)
conffiles=$(find /opt/firewallo/etc/firewallo -type f | sed 's|/opt/firewallo||')

# Creazione del file control per il pacchetto .deb
cat <<EOF > /opt/firewallo_pkg/DEBIAN/control
Package: firewallo
Version: $VERSION
Section: utils
Priority: optional
Architecture: all
Depends: bash (>= 4.0), coreutils, iptables, nftables, suricata, nano
Maintainer: Matteo Fioriti <fioritim@gmail.com>
Description: Firewallo is a firewall manager for Debian GNU/Linux that uses iptables or nftables.
 Questo pacchetto include un sistema di gestione del firewall basato su iptables e nftables.
EOF

# Aggiungi i percorsi dei file di configurazione al file conffiles
for file in $conffiles; do
    echo "$file" >> /opt/firewallo_pkg/DEBIAN/conffiles
done


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
if [ ! -e /etc/suricata/suricata.yaml ]; then
  install -m 644 /usr/local/firewallo/ansible/postinst/suricata.yaml /etc/suricata/suricata.yaml
else
  mv /etc/suricata/suricata.yaml /etc/suricata/suricata.yaml.bck
  install -m 644 /usr/local/firewallo/ansible/postinst/suricata.yaml /etc/suricata/suricata.yaml
fi

# Copia del file suricata.service personalizzato
install -m 644 /usr/local/firewallo/ansible/postinst/suricata.service /lib/systemd/system/suricata.service

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
echo "building .deb..."
dpkg-deb --build /opt/firewallo_pkg "/opt/firewallo_pkg_$VERSION_$DATE.deb"

# Verifica se il pacchetto è stato creato
if [ -f /opt/firewallo_pkg_$VERSION_$DATE.deb ]; then
  echo ".deb successfully build : /opt/firewallo_pkg_$VERSION_$DATE.deb"
else
  echo "Error : error on build .deb !"
  exit 1
fi


echo "Do you want to install firewallo? y/n"
read Risp

if [[ "$Risp" == "Y" || "$Risp" == "y" || "$Risp" == "Yes" || "$Risp" == "yes" ]]; then
    # Disinstallazione di una eventuale vecchia versione di firewallo
    if [ "$UNIST" = "yes" ]; then
    apt remove -y firewallo || true
    fi

    # Installazione del nuovo pacchetto .deb
    echo "Intall package /opt/firewallo_pkg_$VERSION_$DATE.deb..."
    apt install -y /opt/firewallo_pkg_$VERSION_$DATE.deb

    echo "Install ok!"
else
    exit 0
fi
