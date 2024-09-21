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
parse_port_range() {
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

# Carica le traduzioni
load_translations

# Seleziona la catena
select_chain

# Chiedi i dettagli uno per uno all'utente con controlli
while true; do
    read -e -p "$SOURCE_ADDR_PROMPT" SRC_ADDR
    if validate_ip "$SRC_ADDR"; then
        break
    else
        echo "$INVALID_SADDR"
    fi
done

 # Mostra il menu per la scelta del protocollo (tcp o udp)
    while true; do
        echo ""
        echo "$PROTOCOL_PROMPT"
        echo "$TCP_OPTION"
        echo "$UDP_OPTION"
        read -e -p "$CHOICE_PROMPT" protocol_choice

        case $protocol_choice in
            1)
                PROTOCOL="tcp"
                break
                ;;
            2)
                PROTOCOL="udp"
                break
                ;;
            *)
                handle_error "$INVALID_PROTOCOL"
                ;;
        esac
    done

while true; do
    read -e -p "$SRC_PORT_PROMPT" SRC_PORT
    SRC_PORT=${SRC_PORT:-any}
    if validate_port "$SRC_PORT"; then
        break
    else
        echo "$INVALID_SPORT"
    fi
done

while true; do
    read -e -p "$DST_ADDR_PROMPT" DST_ADDR
    if validate_ip "$DST_ADDR"; then
        break
    else
        echo "$INVALID_DADDR"
    fi
done

while true; do
    read -e -p "$DST_PORT_PROMPT" DST_PORT
    DST_PORT=${DST_PORT:-any}
    if validate_port "$DST_PORT"; then
        break
    else
        echo "$INVALID_DPORT"
    fi
done

while true; do
    read -e -p "$ACTION_PROMPT" ACTION
    if [[ "$ACTION" =~ ^(ACCEPT|DROP|REJECT)$ ]]; then
        break
    else
        echo "$ERROR_INVALID_ACTION"
    fi
done
while true; do
    read -e -p "$COMMENT_PROMPT" comment
    if [[ "$comment" =~ ^[a-zA-Z0-9_]+$ ]]; then
        break
    else
        handle_error "$INVALID_COMMENT_FORMAT"
    fi
done
if [ "$IPT" != "" ] ; then
    # Adatta le porte per iptables
    SRC_PORT_OPTION_IPT=$(parse_port_range "$SRC_PORT")
    DST_PORT_OPTION_IPT=$(parse_port_range "$DST_PORT")
    # Aggiungi la regola in iptables
    iptables_cmd="iptables -t filter -A $CHAIN_SELECTED -p $PROTOCOL -s $SRC_ADDR --sport $SRC_PORT_OPTION_IPT -d $DST_ADDR --dport $DST_PORT_OPTION_IPT -j $ACTION"
    echo "$IPT_RULE_MSG" ; echo "$iptables_cmd"
    echo "$iptables_cmd"| cat - $DIRCONF/filter/$CHAIN_SELECTED > temp && mv temp $DIRCONF/filter/$CHAIN_SELECTED

elif [ "$NFT" != "" ]; then
    # Adatta le porte per nftables
    SRC_PORT_OPTION_NFT=$(parse_port_range_nft "$SRC_PORT")
    DST_PORT_OPTION_NFT=$(parse_port_range_nft "$DST_PORT")
    # Traduci l'azione in nftables
    nft_action=$(translate_action "$ACTION")
    nft_cmd="nft \"add rule ip filter $CHAIN_SELECTED ip saddr $SRC_ADDR ip daddr $DST_ADDR $PROTOCOL sport $SRC_PORT_OPTION_NFT $PROTOCOL dport $DST_PORT_OPTION_NFT log prefix \\\"$CHAIN_SELECTED $comment : \\\" $nft_action\""
    echo "$NFT_RULE_MSG"; echo "$nft_cmd"
    echo $nft_cmd | cat - $DIRCONF/filter/$CHAIN_SELECTED > temp && mv temp $DIRCONF/filter/$CHAIN_SELECTED
else
    echo "$INT_ERROR_MSG"
fi
