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

# Funzione per visualizzare le catene disponibili e permettere la selezione
select_chain() {
    echo "$SELECT_CHAIN_PROMPT"
    CHAINS=(
        fw2fw	fw2lan	fw2wan	fw2vpns	fw2dmz \
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
            break
        else
            echo "$INVALID_SELECTION_MSG"
        fi
    done
}

# Funzione per adattare i valori 'any' e 'range' per iptables e nftables
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

# Funzione per adattare i valori 'any' e 'range' per iptables e nftables
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
            echo "Azione non valida"
            exit 1
            ;;
    esac
}

# Carica le traduzioni
load_translations

# Seleziona la catena
select_chain

# Chiedi i dettagli uno per uno all'utente
read -e -p "$SOURCE_ADDR_PROMPT" SRC_ADDR
read -e -p "$PROTOCOL_PROMPT" PROTOCOL
read -e -p "$SRC_PORT_PROMPT" SRC_PORT
SRC_PORT=${SRC_PORT:-any}
read -e -p "$DST_ADDR_PROMPT" DST_ADDR
read -e -p "$DST_PORT_PROMPT" DST_PORT
DST_PORT=${DST_PORT:-any}
read -e -p "$ACTION_PROMPT" ACTION

if [ "$IPT" != "" ] ; then
    # Adatta le porte per iptables e nftables
    SRC_PORT_OPTION_IPT=$(parse_port_range "$SRC_PORT")
    DST_PORT_OPTION_IPT=$(parse_port_range "$DST_PORT")
    # Aggiungi la regola in iptables
    iptables_cmd="iptables -t filter -A $CHAIN_SELECTED -p $PROTOCOL -s $SRC_ADDR --sport $SRC_PORT_OPTION_IPT -d $DST_ADDR --dport $DST_PORT_OPTION_IPT -j $ACTION"
    echo "$IPT_RULE_MSG"
    echo "$iptables_cmd"

elif [ "$NFT" != "" ]; then
    SRC_PORT_OPTION_NFT=$(parse_port_range_nft "$SRC_PORT")
    DST_PORT_OPTION_NFT=$(parse_port_range_nft "$DST_PORT")
    # Aggiungi la regola in nftables
    nft_action=$(translate_action "$ACTION")
    nft_cmd="nft add rule ip filter $CHAIN_SELECTED ip saddr $SRC_ADDR ip daddr $DST_ADDR $PROTOCOL sport $SRC_PORT_OPTION_NFT $PROTOCOL dport $DST_PORT_OPTION_NFT $nft_action"
    echo "$NFT_RULE_MSG"
    echo "$nft_cmd" | cat - $DIRCONF/filter/$CHAIN_SELECTED > temp && mv temp $DIRCONF/filter/$CHAIN_SELECTED
else
    echo "$INT_ERROR_MSG"
fi
