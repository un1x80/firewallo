#!/bin/bash

WG_CONFIG_DIR="/etc/wireguard"
WG_INTERFACE="wg0"
CLIENT_CONFIG_DIR="/etc/wireguard/clients"
WG_CONFIG_FILE="$WG_CONFIG_DIR/$WG_INTERFACE.conf"

# Funzione per generare chiavi WireGuard
generate_wireguard_keys() {
    local private_key public_key
    private_key=$(wg genkey)
    public_key=$(echo "$private_key" | wg pubkey)
    echo "$private_key" "$public_key"
}

# Funzione per verificare se l'input è un IP valido
validate_ip() {
    local ip="$1"
    if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        for octet in $(echo "$ip" | tr "." " "); do
            if [[ "$octet" -lt 0 || "$octet" -gt 255 ]]; then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

# Funzione per verificare che gli IP o subnet siano validi
validate_allowed_ips() {
    local allowed_ips="$1"
    IFS=',' read -ra ADDR <<< "$allowed_ips"
    for ip in "${ADDR[@]}"; do
        ip=$(echo "$ip" | cut -d'/' -f1)  # Prendi solo la parte dell'IP, ignora il CIDR
        if ! validate_ip "$ip"; then
            return 1
        fi
    done
    return 0
}

# Funzione per creare la configurazione del server WireGuard
configure_wireguard_server() {
    # Chiedi l'IP pubblico e la porta del server
    read -rp "Inserisci l'IP pubblico del server WireGuard: " server_ip
    if ! validate_ip "$server_ip"; then
        echo "Errore: IP non valido. Riprova."
        return 1
    fi
    read -rp "Inserisci la porta da utilizzare per WireGuard (es. 51820): " server_port

    # Genera le chiavi del server se non esistono
    if [[ ! -f "$WG_CONFIG_DIR/server_private.key" || ! -f "$WG_CONFIG_DIR/server_public.key" ]]; then
        echo "Generazione delle chiavi del server..."
        read server_private_key server_public_key < <(generate_wireguard_keys)
        echo "$server_private_key" > "$WG_CONFIG_DIR/server_private.key"
        echo "$server_public_key" > "$WG_CONFIG_DIR/server_public.key"
    else
        echo "Chiavi del server trovate, utilizzando quelle esistenti."
        server_private_key=$(cat "$WG_CONFIG_DIR/server_private.key")
        server_public_key=$(cat "$WG_CONFIG_DIR/server_public.key")
    fi

    # Crea il file di configurazione del server
    cat > "$WG_CONFIG_FILE" <<EOL
[Interface]
PrivateKey = $server_private_key
Address = 10.0.0.1/24
ListenPort = $server_port
SaveConfig = true

# Aggiungi qui i client tramite [Peer]
EOL

    echo "Configurazione del server salvata in $WG_CONFIG_FILE"

    # Avvia e abilita WireGuard
    wg-quick up "$WG_INTERFACE"
    systemctl enable wg-quick@"$WG_INTERFACE"
    echo "WireGuard server configurato e avviato su $server_ip:$server_port"
}

# Funzione per ottenere informazioni dal file di configurazione del server WireGuard
get_server_info() {
    local server_ip server_port server_pubkey

    server_ip=$(grep 'Address' "$WG_CONFIG_FILE" | awk '{print $3}' | cut -d/ -f1)
    server_port=$(grep 'ListenPort' "$WG_CONFIG_FILE" | awk '{print $3}')
    server_pubkey=$(cat "$WG_CONFIG_DIR/server_public.key")
    
    echo "$server_ip" "$server_port" "$server_pubkey"
}

# Funzione per creare il file di configurazione del client
create_wireguard_user() {
    local client_ip="$1"
    local allowed_ips="$2"
    local username="$3"

    # Genera le chiavi del client
    read private_key public_key < <(generate_wireguard_keys)

    # Ottieni le informazioni del server
    read server_ip server_port server_pubkey < <(get_server_info)

    # Crea la directory dei client se non esiste
    mkdir -p "$CLIENT_CONFIG_DIR"

    # Crea il file di configurazione del client
    local client_config_file="$CLIENT_CONFIG_DIR/$username.conf"
    cat > "$client_config_file" <<EOL
[Interface]
PrivateKey = $private_key
Address = $client_ip/24
DNS = 8.8.8.8

[Peer]
PublicKey = $server_pubkey
Endpoint = $server_ip:$server_port
AllowedIPs = $allowed_ips
PersistentKeepalive = 25
EOL

    echo "Configurazione del client creata: $client_config_file"

    # Aggiungi il peer al server
    cat >> "$WG_CONFIG_FILE" <<EOL

[Peer]
PublicKey = $public_key
AllowedIPs = $client_ip/32
EOL

    echo "Client $client_ip aggiunto alla configurazione del server."

    # Ricarica la configurazione di WireGuard
    wg syncconf "$WG_INTERFACE" <(wg-quick strip "$WG_INTERFACE")
}

# Funzione per configurare il firewall con nftables
configure_firewall() {
    local client_ip="$1"
    local allowed_ips="$2"

    # Aggiungi regola di input per il client
    nft add rule inet wireguard input ip saddr "$client_ip" oif "$WG_INTERFACE" accept

    # Aggiungi regole di forward per gli AllowedIPs
    IFS=',' read -ra ADDR <<< "$allowed_ips"
    for ip in "${ADDR[@]}"; do
        nft add rule inet wireguard forward ip saddr "$client_ip" ip daddr "$ip" accept
    done

    echo "Regole firewall configurate per l'utente $client_ip"
}

# Funzione per elencare i client esistenti
list_wireguard_users() {
    echo "Client configurati:"
    ls "$CLIENT_CONFIG_DIR"
}

# Funzione per controllare se un client è connesso
check_wireguard_user_status() {
    local username="$1"
    local client_ip=$(grep 'Address' "$CLIENT_CONFIG_DIR/$username.conf" | awk '{print $3}' | cut -d/ -f1)

    wg show "$WG_INTERFACE" | grep -q "$client_ip"
    if [[ $? -eq 0 ]]; then
        echo "L'utente $username è attualmente connesso."
    else
        echo "L'utente $username non è connesso."
    fi
}

# Funzione principale del menu
main_menu() {
    while true; do
        echo "Gestione WireGuard - Seleziona un'opzione:"
        echo "1) Configura il server WireGuard"
        echo "2) Crea un nuovo utente"
        echo "3) Elenca gli utenti"
        echo "4) Controlla lo stato di connessione di un utente"
        echo "5) Esci"
        read -rp "Opzione: " option

        case $option in
            1)
                configure_wireguard_server
                ;;
            2)
                read -rp "Inserisci l'IP del client (es. 10.0.0.2): " client_ip
                if ! validate_ip "$client_ip"; then
                    echo "Errore: IP del client non valido."
                    continue
                fi

                read -rp "Inserisci gli IP o le subnet a cui l'utente può accedere (separati da virgole): " allowed_ips
                if ! validate_allowed_ips "$allowed_ips"; then
                    echo "Errore: uno o più AllowedIPs non validi."
                    continue
                fi

                read -rp "Inserisci un nome per l'utente: " username

                create_wireguard_user "$client_ip" "$allowed_ips" "$username"
                configure_firewall "$client_ip" "$allowed_ips"
                ;;
            3)
                list_wireguard_users
                ;;
            4)
                read -rp "Inserisci il nome dell'utente da controllare: " username
                check_wireguard_user_status "$username"
                ;;
            5)
                echo "Uscita..."
                exit 0
                ;;
            *)
                echo "Opzione non valida, riprova."
                ;;
        esac
    done
}

main_menu
