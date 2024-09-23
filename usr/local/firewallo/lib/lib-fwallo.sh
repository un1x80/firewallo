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

handle_error() {
    echo "$1" 1>&2
    echo "$INVALID_SELECTION_MSG"
}


# Funzione per visualizzare le catene disponibili e permettere la selezione
select_chain() {
    echo "$SELECT_CHAIN_PROMPT"
    CHAINS=(
        fw2fw	fw2lan	fw2wan	fw2vpns	    fw2dmz \
        lan2fw	lan2lan	lan2wan	lan2vpns	lan2dmz \
        wan2fw	wan2lan	wan2wan	wan2vpns	wan2dmz \
        vpns2fw	vpns2lan	vpns2wan	vpns2vpns	vpns2dmz \
        dmz2fw	dmz2lan	dmz2wan	dmz2vpns	dmz2dmz \
        exit
    )

    # Mostra le catene all'utente
    select chain in "${CHAINS[@]}"; do
        if [[ " ${CHAINS[@]} " =~ " $chain " ]]; then
            echo "$(printf "$CHAIN_SELECTED_MSG" "$chain")"
            CHAIN_SELECTED=$chain
            if [ "$chain" = "exit" ] ; then
                exit    
            else
                break
            fi
        else
            echo "$INVALID_SELECTION_MSG"
        fi
    done
}

# Funzione per controllare la validità dell'indirizzo IP
validate_ip() {
    local ip="$1"
    if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?$ ]]; then
        return 0
    else
        return 1
    fi
}

# Funzione per controllare la validità del protocollo
validate_protocol() {
    local protocol="$1"
    if [[ "$protocol" == "tcp" || "$protocol" == "udp" ]]; then
        return 0
    else
        return 1
    fi
}

# Funzione per controllare la validità della porta
validate_port() {
    local port="$1"
    if [[ "$port" == "any" || "$port" =~ ^[0-9]+$ && "$port" -ge 1 && "$port" -le 65535 ]]; then
        return 0
    else
        return 1
    fi
}

# Funzione per adattare i valori 'any' e 'range' per iptables
parse_port_range_ipt() {
    local port_range="$1"
    if [[ "$port_range" == "any" ]]; then
        echo "1:65535"
    elif [[ "$port_range" =~ ^([0-9]+):([0-9]+)$ ]]; then
        echo "$port_range"
    else
        echo "$port_range"
    fi
}

# Funzione per adattare i valori 'any' e 'range' per nftables
parse_port_range_nft() {
    local port_range="$1"
    if [[ "$port_range" == "any" ]]; then
        echo "1-65535"
    elif [[ "$port_range" =~ ^([0-9]+):([0-9]+)$ ]]; then
        echo "$port_range"
    else
        echo "$port_range"
    fi
}

# Funzione per tradurre le azioni in nftables
translate_action() {
    case "$1" in
        ACCEPT)
            echo "counter accept"
            ;;
        DROP)
            echo "counter drop"
            ;;
        REJECT)
            echo "counter reject"
            ;;
        *)
            echo "Invalid action"
            exit 1
            ;;
    esac
}
