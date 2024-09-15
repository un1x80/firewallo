#!/bin/bash

DIRCONF="/etc/firewallo"
source $DIRCONF/firewallo.conf

# Carica il file di traduzione
load_translations() {
    local lang_file="$DIRCONF/lang/firewallo.lang.$LANG"
    if [[ -f "$lang_file" ]]; then
        source "$lang_file"
    else
        echo "LANG_NOT_FOUND"
        exit 1
    fi
}

# Funzione per mostrare un messaggio di errore e continuare
handle_error() {
    echo "$1" 1>&2
    echo "$INVALID_SELECTION_MSG"
}

# Funzione per configurare le regole PREROUTING in iptables
configure_iptables_prerouting() {
    local srcip_mask="$1"
    local iif="$2"
    local protocol="$3"
    local dport="$4"
    local to_dest_ip="$5"
    local to_dest_port="$6"
    local comment="$7"

    # Configurazione della regola DNAT in iptables
    echo "
    iptables -t nat -A PREROUTING -s \"$srcip_mask\" -i \"$iif\" -p \"$protocol\" --dport \"$dport\" -j LOG --log-prefix \"DNAT $comment\"
    iptables -t nat -A PREROUTING -s \"$srcip_mask\" -i \"$iif\" -p \"$protocol\" --dport \"$dport\" -j DNAT --to-destination \"$to_dest_ip:$to_dest_port\""\
    | cat - $DIRCONF/nat/firewallo.nat > temp && mv temp $DIRCONF/nat/firewallo.nat 
    
    if [ $? -ne 0 ]; then
        handle_error "$DNAT_CONFIG_ERROR"
    else
        echo "$DNAT_CONFIG_SUCCESS"
    fi
}

# Funzione per configurare le regole PREROUTING in nftables
configure_nftables_prerouting() {
    local srcip_mask="$1"
    local iif="$2"
    local protocol="$3"
    local dport="$4"
    local to_dest_ip="$5"
    local to_dest_port="$6"
    local comment="$7"

    # Configurazione della regola DNAT in nftables
    echo "nft \"add rule ip nat PREROUTING ip saddr \"$srcip_mask\" iif \"$iif\" $protocol dport \"$dport\" log prefix \"DNAT $comment : \" counter dnat to \"$to_dest_ip:$to_dest_port\"\""\
    | cat - $DIRCONF/nat/firewallo.nat > temp && mv temp $DIRCONF/nat/firewallo.nat
    
    if [ $? -ne 0 ]; then
        handle_error "$NFT_DNAT_CONFIG_ERROR"
    else
        echo "$NFT_DNAT_CONFIG_SUCCESS"
    fi
}

# Funzione per chiedere i parametri all'utente
ask_for_parameters() {
    echo "$PREROUTING_CONFIG_PROMPT"
    echo ""

    while true; do
        read -e -p "$SRCIP_MASK_PREROUTING_PROMPT" srcip_mask
        if [[ "$srcip_mask" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
            break
        else
            handle_error "Indirizzo IP di origine o maschera non valido."
        fi
    done

    while true; do
        read -e -p "$IIF_PROMPT" iif
        if [[ "$iif" =~ ^[a-zA-Z0-9]+$ ]]; then
            break
        else
            handle_error "Nome dell'interfaccia non valido."
        fi
    done

    # Mostra il menu per la scelta del protocollo (tcp o udp)
    while true; do
        echo ""
        echo "$PROTOCOL_PROMPT"
        echo "$TCP_OPTION"
        echo "$UDP_OPTION"
        read -e -p "Inserisci il numero corrispondente (1 o 2): " protocol_choice

        case $protocol_choice in
            1)
                protocol="tcp"
                break
                ;;
            2)
                protocol="udp"
                break
                ;;
            *)
                handle_error "Scelta non valida. Per favore, inserisci 1 per TCP o 2 per UDP."
                ;;
        esac
    done

    while true; do
        read -e -p "$PORT_DEST_PROMPT" dport
        if [[ "$dport" =~ ^[0-9]+$ ]] && [ "$dport" -ge 1 ] && [ "$dport" -le 65535 ]; then
            break
        else
            handle_error "$INVALID_DPORT"
        fi
    done

    while true; do
        read -e -p "$DEST_IP_PROMPT" to_dest_ip
        if [[ "$to_dest_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            break
        else
            handle_error "$INVALID_DEST_IP_FORMAT"
        fi
    done

    while true; do
        read -e -p "$DEST_PORT_PROMPT" to_dest_port
        if [[ "$to_dest_port" =~ ^[0-9]+$ ]] && [ "$to_dest_port" -ge 1 ] && [ "$to_dest_port" -le 65535 ]; then
            break
        else
            handle_error "$INVALID_DEST_PORT_FORMAT"
        fi
    done

    while true; do
        read -e -p "$COMMENT_PROMPT" comment
        if [[ "$comment" =~ ^[a-zA-Z0-9]+$ ]]; then
            break
        else
            handle_error "$INVALID_COMMENT_FORMAT"
        fi
    done

    # Applicare la configurazione in iptables
    configure_iptables_prerouting "$srcip_mask" "$iif" "$protocol" "$dport" "$to_dest_ip" "$to_dest_port" "$comment"

    # Applicare la configurazione in nftables
    configure_nftables_prerouting "$srcip_mask" "$iif" "$protocol" "$dport" "$to_dest_ip" "$to_dest_port" "$comment"
}

# Carica le traduzioni
load_translations

# Eseguire la funzione per chiedere i parametri
ask_for_parameters