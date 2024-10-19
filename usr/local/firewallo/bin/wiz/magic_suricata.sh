#!/bin/bash
# Controlla se il file esiste
if [ -f /etc/firewallo/.sid ]; then
    # Leggi il valore attuale da .sid e incrementalo di uno
    SID=$(( $(cat /etc/firewallo/.sid) + 1 ))
else
    # Se il file non esiste, inizializza SID a 1
    SID=1
fi

# Scrivi il nuovo valore nel file .sid
echo $SID > /etc/firewallo/.sid
# Array con tutti i protocolli supportati da Suricata
protocols=(
    "BitTorrent" "Facebook" "Skype" "WhatsApp" "YouTube"
    "Netflix" "Tor" "SSH" "HTTPS" "HTTP" "DNS" "Dropbox"
    "Google Drive" "OneDrive" "Steam" "PlayStation Network"
    "Xbox Live" "Zoom" "Microsoft Teams" "Instagram" "Twitter"
    "Snapchat" "Telegram" "TikTok" "Amazon Prime Video" "Spotify"
    "Apple Music" "Discord" "Gmail" "Office 365" "Slack" "Bitcoin"
    "Ethereum" "OpenVPN" "IPsec" "WireGuard" "SMTP" "IMAP" "POP3"
)

# Funzione per controllare se Suricata è attivo
check_suricata() {
    if ! systemctl is-active --quiet suricata; then
        echo "Il servizio Suricata non è attivo. Avviarlo con: sudo systemctl start suricata"
        exit 1
    fi
}

# Funzione per mostrare i protocolli supportati
show_protocols() {
    echo "Scegli i protocolli da bloccare (puoi selezionarne più di uno separando i numeri con uno spazio):"
    for i in "${!protocols[@]}"; do
        echo "$((i + 1))) ${protocols[$i]}"
    done
    echo -n "Inserisci i numeri corrispondenti ai protocolli desiderati: "
    read -a protocol_choices
}

# Funzione per ottenere i protocolli selezionati
get_protocols() {
    selected_protocols=()
    for choice in "${protocol_choices[@]}"; do
        if ((choice > 0 && choice <= ${#protocols[@]})); then
            selected_protocols+=("${protocols[$((choice - 1))]}")
        else
            echo "Scelta non valida: $choice. Ignorato."
        fi
    done
}

# Funzione per creare le regole di Suricata
create_rules() {
    for protocol in "${selected_protocols[@]}"; do
        echo "Aggiungendo regola per bloccare il traffico del protocollo $protocol..."
	protocol=$(echo "$protocol" | tr '[:upper:]' '[:lower:]'| tr -d " ")

        # Aggiungi la regola al file delle regole di Suricata
        rule="drop ip any any -> any any (msg:\"Blocco traffico $protocol\"; app-layer-protocol:$protocol; sid:$SID; rev:1; classtype:policy-violation;)"
        echo "$rule" | sudo tee -a /etc/suricata/rules/block.rules > /dev/null
    done

    echo "Regole aggiunte con successo al file delle regole."
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
    sudo cat /etc/suricata/rules/block.rules
}

# Main script
clear
cat $DIRCONF/motd #Visualizza il banner motd
echo "---------------------------------------------"
echo "Wizard per la configurazione di Suricata"
echo "---------------------------------------------"

# Verifica se Suricata è attivo
check_suricata

# Mostra le regole correnti
show_current_rules

# Chiedi all'utente di scegliere i protocolli da bloccare
show_protocols
get_protocols

# Crea le regole di blocco per i protocolli scelti
create_rules

# Riavvia Suricata per applicare le modifiche
restart_suricata

# Mostra le regole aggiornate
show_current_rules

echo "Configurazione di Suricata completata con successo!"
