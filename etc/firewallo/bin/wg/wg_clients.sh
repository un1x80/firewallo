#!/bin/bash

WG_CONFIG_DIR="/etc/wireguard"
WG_INTERFACE="wg0"

# Funzione per generare le chiavi per WireGuard
function generate_wireguard_keys() {
    local privkey pubkey
    privkey=$(wg genkey)
    pubkey=$(echo "$privkey" | wg pubkey)
    echo "$privkey" "$pubkey"
}

# Funzione per configurare un nuovo utente WireGuard
function create_wireguard_user() {
    echo "Creazione di un nuovo utente WireGuard..."

    # Genera le chiavi del client
    client_keys=($(generate_wireguard_keys))
    client_private_key=${client_keys[0]}
    client_public_key=${client_keys[1]}
    echo "Chiave privata del client: $client_private_key"
    echo "Chiave pubblica del client: $client_public_key"

    # Chiedi l'indirizzo IP del client
    while true; do
        read -p "Inserisci l'IP del client (ad esempio, 10.0.0.2): " client_ip
        if [[ $client_ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
            break
        else
            echo "Indirizzo IP non valido, riprova."
        fi
    done

    # Chiedi l'indirizzo IP pubblico del server
    while true; do
        read -p "Inserisci l'IP pubblico del server WireGuard: " server_ip
        if [[ $server_ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
            break
        else
            echo "Indirizzo IP non valido, riprova."
        fi
    done

    # Chiedi la porta WireGuard del server
    while true; do
        read -p "Inserisci la porta di WireGuard del server (default 51820): " server_port
        if [[ $server_port =~ ^[0-9]+$ ]] && [[ $server_port -ge 1 ]] && [[ $server_port -le 65535 ]]; then
            break
        else
            echo "Porta non valida, riprova."
        fi
    done

    # Chiedi la chiave pubblica del server
    read -p "Inserisci la chiave pubblica del server: " server_public_key

    # Chiedi le risorse di rete che l'utente può accedere
    read -p "Inserisci gli IP o le subnet a cui l'utente può accedere (es. 192.168.1.0/24, separati da virgola): " allowed_ips
    if [[ -z "$allowed_ips" ]]; then
        allowed_ips="0.0.0.0/0"  # Default: accesso a tutte le risorse
    fi

    # Configura il file di configurazione del client
    client_config_file="$WG_CONFIG_DIR/client-$client_ip.conf"
    cat > "$client_config_file" <<EOL
[Interface]
PrivateKey = $client_private_key
Address = $client_ip/24
DNS = 8.8.8.8

[Peer]
PublicKey = $server_public_key
Endpoint = $server_ip:$server_port
AllowedIPs = $allowed_ips
PersistentKeepalive = 25

EOL

    echo "Configurazione client generata: $client_config_file"
    
    # Aggiungi il peer al file di configurazione del server
    echo "Aggiungo il client alla configurazione del server..."
    cat >> "$WG_CONFIG_DIR/$WG_INTERFACE.conf" <<EOL
[Peer]
PublicKey = $client_public_key
AllowedIPs = $client_ip/32

EOL

    # Ricarica la configurazione di WireGuard
    wg syncconf $WG_INTERFACE <(wg-quick strip $WG_INTERFACE)
    
    echo "Client $client_ip configurato correttamente."
    echo "L'utente può accedere alle seguenti risorse di rete: $allowed_ips"
}

# Funzione per listare gli utenti WireGuard (client)
function list_wireguard_users() {
    echo "Lista degli utenti WireGuard:"
    grep 'AllowedIPs' "$WG_CONFIG_DIR/$WG_INTERFACE.conf" | awk '{print $2}' | cut -d'/' -f1
}

# Funzione per vedere se un utente è connesso
function check_wireguard_user_status() {
    echo "Verifica dello stato degli utenti WireGuard..."
    wg show $WG_INTERFACE
}

# Menu principale
while true; do
    echo "Gestione utenti WireGuard - Seleziona un'opzione:"
    echo "1) Crea un nuovo utente"
    echo "2) Lista degli utenti"
    echo "3) Stato degli utenti (connessi)"
    echo "4) Esci"

    read -p "Seleziona un'opzione: " option

    case $option in
        1)
            create_wireguard_user
            ;;
        2)
            list_wireguard_users
            ;;
        3)
            check_wireguard_user_status
            ;;
        4)
            echo "Uscita dallo script."
            exit 0
            ;;
        *)
            echo "Opzione non valida, riprova."
            ;;
    esac
done
