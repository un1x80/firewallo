#!/bin/bash
source /usr/local/firewallo/lib/lib-wiz.sh

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
    "Facebook" "Skype" "WhatsApp" "YouTube"
    "Netflix" "Dropbox" "Google Drive" "OneDrive"
    "Steam" "PlayStation Network" "Xbox Live" "Zoom"
    "Microsoft Teams" "Instagram" "Twitter" "Telegram"
    "TikTok" "Amazon Prime Video" "Spotify" "Apple Music"
    "Discord" "Gmail" "Bitcoin" "Ethereum" "BitTorrent"
    "OpenVPN" "IPsec" "WireGuard" "SMTP" "IMAP"
    "POP3" "Tor" "SSH" "HTTPS" "HTTP" "DNS"
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
    
    select protocol in "${protocols[@]}" "fine"; do
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
        protocol=$(echo "$protocol" | tr '[:upper:]' '[:lower:]' | tr -d " ")

        # Aggiungi la regola al file delle regole di Suricata
        rule="drop ip any any -> any any (msg:\"Blocco traffico $protocol\"; app-layer-protocol:$protocol; sid:$SID; rev:1; classtype:policy-violation;)"
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
    color_text "yellow" $RULESNOW
}

# Main script
clear
cat $DIRCONF/motd # Visualizza il banner motd
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

echo "Configurazione di Suricata completata con successo!"
