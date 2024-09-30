#!/bin/bash

# Array con tutti i protocolli supportati da nDPI
protocols=(
    "BitTorrent"
    "Facebook"
    "Skype"
    "WhatsApp"
    "YouTube"
    "Netflix"
    "Tor"
    "SSH"
    "HTTPS"
    "HTTP"
    "DNS"
    "Dropbox"
    "Google Drive"
    "OneDrive"
    "Steam"
    "PlayStation Network"
    "Xbox Live"
    "Zoom"
    "Microsoft Teams"
    "Instagram"
    "Twitter"
    "Snapchat"
    "Telegram"
    "TikTok"
    "Amazon Prime Video"
    "Spotify"
    "Apple Music"
    "Discord"
    "Gmail"
    "Office 365"
    "Slack"
    "Bitcoin"
    "Ethereum"
    "OpenVPN"
    "IPsec"
    "WireGuard"
    "SMTP"
    "IMAP"
    "POP3"
)

# Funzione per controllare se nftables è attivo
check_nftables() {
    if ! systemctl is-active --quiet nftables; then
        echo "Il servizio nftables non è attivo. Avviarlo con: sudo systemctl start nftables"
        exit 1
    fi
}

# Funzione per mostrare i protocolli nDPI supportati
show_protocols() {
    echo "Scegli il protocollo da gestire:"
    for i in "${!protocols[@]}"; do
        echo "$((i + 1))) ${protocols[$i]}"
    done
    echo -n "Inserisci il numero corrispondente al protocollo desiderato: "
    read protocol_choice
}

# Funzione per ottenere il protocollo nDPI selezionato
get_protocol() {
    if ((protocol_choice > 0 && protocol_choice <= ${#protocols[@]})); then
        protocol="${protocols[$((protocol_choice - 1))]}"
        protocol=$(echo "$protocol" | tr '[:upper:]' '[:lower:]') # Convert to lowercase
    else
        echo "Scelta non valida. Uscita."
        exit 1
    fi
}

# Funzione per mostrare il tipo di azione da applicare
show_actions() {
    echo "Scegli l'azione da applicare al protocollo $protocol:"
    echo "1) Blocca il traffico"
    echo "2) Limita il traffico (es. 1MB al secondo)"
    echo "3) Monitora e logga il traffico"
    echo -n "Inserisci il numero corrispondente all'azione desiderata: "
    read action_choice
}

# Funzione per ottenere l'azione corrispondente
get_action() {
    case $action_choice in
        1) action="drop" ;;
        2)
            echo -n "Inserisci il limite di velocità (es. 1 mbytes/second): "
            read rate_limit
            action="limit rate $rate_limit"
            ;;
        3) action="log" ;;
        *)
            echo "Scelta non valida. Uscita."
            exit 1
            ;;
    esac
}

# Funzione per creare la regola nftables
create_rule() {
    echo "Aggiungendo regola per $protocol con azione $action..."

    nft_command="nft add rule inet filter forward @ndpi_proto $protocol $action"

    # Esegui il comando per aggiungere la regola al firewall
    sudo bash -c "$nft_command"
    
    if [ $? -eq 0 ]; then
        echo "Regola aggiunta con successo."
    else
        echo "Errore durante l'aggiunta della regola."
    fi
}

# Funzione per mostrare la tabella corrente
show_current_rules() {
    echo "Regole correnti nel firewall nftables:"
    sudo nft list ruleset
}

# Main script
clear
echo "---------------------------------------------"
echo "Wizard per l'aggiunta di regole nDPI a nftables"
echo "---------------------------------------------"

# Verifica se nftables è attivo
check_nftables

# Mostra le regole correnti del firewall
show_current_rules

# Chiedi all'utente di scegliere un protocollo
show_protocols
get_protocol

# Chiedi l'azione da applicare
show_actions
get_action

# Crea la regola
create_rule

# Mostra le regole aggiornate
show_current_rules
