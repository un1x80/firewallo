#!/bin/bash
source /usr/local/firewallo/lib/wiz.lib
source /usr/local/firewallo/lib/firewallo.lib

# Controlla se il file esiste
if [ -f /etc/firewallo/.sid ]; then
    # Leggi il valore attuale da .sid e incrementalo di uno
    SID=$(( $(cat /etc/firewallo/.sid) + 1 ))
else
    # Se il file non esiste, inizializza SID a 1
    SID=1
fi

# Array con i protocolli supportati da Suricata
declare -A protocols_map=(
    ["Facebook"]="facebook"
    ["Skype"]="skype"
    ["WhatsApp"]="whatsapp"
    ["YouTube"]="youtube"
    ["Netflix"]="netflix"
    ["Dropbox"]="dropbox"
    ["Google Drive"]="google-drive"
    ["OneDrive"]="onedrive"
    ["Steam"]="steam"
    ["PlayStation Network"]="playstation-network"
    ["Xbox Live"]="xbox-live"
    ["Zoom"]="zoom"
    ["Microsoft Teams"]="microsoft-teams"
    ["Instagram"]="instagram"
    ["Twitter"]="twitter"
    ["Telegram"]="telegram"
    ["TikTok"]="tiktok"
    ["Amazon Prime Video"]="amazon-prime-video"
    ["Spotify"]="spotify"
    ["Apple Music"]="apple-music"
    ["Discord"]="discord"
    ["Gmail"]="gmail"
    ["Bitcoin"]="bitcoin"
    ["Ethereum"]="ethereum"
    ["BitTorrent"]="bittorrent"
    ["Tor"]="tor"
    ["HTTP"]="http"
    ["HTTPS-TLS"]="tls"
    ["FTP"]="ftp"
    ["SMTP"]="smtp"
    ["SSH"]="ssh"
    ["IMAP"]="imap"
    ["SMB"]="smb"
    ["DCERPC"]="dcerpc"
    ["DNS"]="dns"
    ["NFS"]="nfs"
    ["NTP"]="ntp"
    ["FTP-DATA"]="ftp-data"
    ["TFTP"]="tftp"
    ["IKEV2"]="ikev2"
    ["KRB5"]="krb5"
    ["DHCP"]="dhcp"
    ["SNMP"]="snmp"
    ["SIP"]="sip"
    ["RFB"]="rfb"
    ["MQTT"]="mqtt"
    ["RDP"]="rdp"
)

# Mappatura hostname per regole speciali
declare -A special_rules_map=(
    ["Facebook"]="facebook.com"
    ["Skype"]="skype.com"
    ["WhatsApp"]="whatsapp.com"
    ["YouTube"]="youtube.com"
    ["Netflix"]="netflix.com"
    ["Dropbox"]="dropbox.com"
    ["Google Drive"]="google.com"
    ["OneDrive"]="onedrive.com"
    ["Steam"]="store.steampowered.com"
    ["PlayStation Network"]="playstation.com"
    ["Xbox Live"]="xbox.com"
    ["Zoom"]="zoom.us"
    ["Microsoft Teams"]="teams.microsoft.com"
    ["Instagram"]="instagram.com"
    ["Twitter"]="twitter.com"
    ["Telegram"]="telegram.org"
    ["TikTok"]="tiktok.com"
    ["Amazon Prime Video"]="primevideo.com"
    ["Spotify"]="spotify.com"
    ["Apple Music"]="music.apple.com"
    ["Discord"]="discord.com"
    ["Gmail"]="gmail.com"
    ["Bitcoin"]="bitcoin.org"
    ["Ethereum"]="ethereum.org"
    ["BitTorrent"]="bittorrent.org"
    ["Tor"]="torproject.org"
)

# Funzione per controllare se Suricata è attivo
check_suricata() {
    if ! systemctl is-active --quiet suricata; then
        echo "Il servizio Suricata non è attivo. Avviarlo con: sudo systemctl start suricata"
        exit 1
    fi
}

# Funzione per mostrare e selezionare i protocolli supportati
show_protocols() {
    echo "Scegli i protocolli da bloccare (inserisci 'fine' per terminare la selezione):"
    selected_protocols=()
    
    PS3="Inserisci il numero del protocollo che desideri bloccare o 'fine' per terminare: "
    
    select protocol in "${!protocols_map[@]}" "fine"; do
        if [[ $protocol == "fine" ]]; then
            break
        elif [[ -n $protocol ]]; then
            echo "Protocollo selezionato: $protocol"
            selected_protocols+=("$protocol")
        else
            echo "Scelta non valida, riprova."
        fi
    done
}

# Funzione per creare le regole di Suricata
create_rules() {
    for protocol in "${selected_protocols[@]}"; do
        echo "Aggiungendo regola per bloccare il traffico del protocollo $protocol..."
        protocol_key=${protocols_map[$protocol]} # Ottieni la chiave corrispondente

        # Verifica se ci sono regole speciali
        if [[ -n ${special_rules_map[$protocol]} ]]; then
            hostname=${special_rules_map[$protocol]}
            # Crea regola per TLS
            rule="drop tls any any -> any any (msg:\"Drop $protocol TLS\"; tls.sni:\"$hostname\"; sid:$SID; rev:1; classtype:policy-violation;)"
        else
            # Aggiungi la regola generale per app-layer
            rule="drop ip any any -> any any (msg:\"Drop $protocol\"; app-layer-protocol:$protocol_key; sid:$SID; rev:1; classtype:policy-violation;)"
        fi

        # Scrivi la regola nel file delle regole di Suricata
        echo "$rule" | sudo tee -a /etc/suricata/rules/block.rules > /dev/null
        SID=$((SID + 1))
    done

    echo "Regole aggiunte con successo al file delle regole."
    # Salva l'ultimo SID incrementato
    echo $SID > /etc/firewallo/.sid
}

# Funzione per riavviare Suricata
restart_suricata() {
    echo "Riavvio di Suricata per applicare le modifiche..."
    sudo systemctl restart suricata
    
    if [ $? -eq 0 ]; then
        echo "Suricata riavviato con successo."
    else
        echo "Errore durante il riavvio di Suricata."
    fi
}

# Funzione per mostrare le regole attuali di Suricata
show_current_rules() {
    echo "Regole attuali nel file block.rules:"
    RULESNOW=$(cat /etc/suricata/rules/block.rules)
    color_text "yellow" "$RULESNOW"
}

# Main script
banner_show # Visualizza il banner motd
echo ""
echo "---------------------------------------------"
color_text "yellow" "Wizard per la configurazione di Suricata"
echo "---------------------------------------------"

# Verifica se Suricata è attivo
check_suricata

# Mostra le regole correnti
show_current_rules

# Chiedi all'utente di scegliere i protocolli da bloccare
show_protocols

# Crea le regole di blocco per i protocolli scelti
create_rules

# Riavvia Suricata per applicare le modifiche
restart_suricata

# Mostra le regole aggiornate
show_current_rules
