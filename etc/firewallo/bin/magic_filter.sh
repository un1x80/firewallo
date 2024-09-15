#!/bin/bash

# Funzione per visualizzare le catene disponibili e permettere la selezione
select_chain() {
    echo "Seleziona la catena dalla seguente lista:"
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
            echo "Hai selezionato la catena: $chain"
            CHAIN_SELECTED=$chain
            break
        else
            echo "Selezione non valida. Riprova."
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

# Seleziona la catena
select_chain

# Chiedi i dettagli uno per uno all'utente
read -e -p "Inserisci l'indirizzo sorgente (es. 192.168.1.1/32): " SRC_ADDR
read -e -p "Inserisci il protocollo (tcp o udp): " PROTOCOL

# Chiedi la porta sorgente (usa 'any' come predefinito)
read -e -p "Inserisci la porta sorgente (es. 80 o 'any'): " SRC_PORT
SRC_PORT=${SRC_PORT:-any}

# Chiedi l'indirizzo di destinazione
read -e -p "Inserisci l'indirizzo di destinazione (es. 192.168.10.1/32): " DST_ADDR

# Chiedi la porta di destinazione (usa 'any' come predefinito)
read -e -p "Inserisci la porta di destinazione (es. 80 o 'any'): " DST_PORT
DST_PORT=${DST_PORT:-any}

# Chiedi l'azione (ACCEPT, DROP, REJECT)
read -e -p "Inserisci l'azione (ACCEPT, DROP, REJECT): " ACTION


if [ "$IPT" != "" ] ; then
# Adatta le porte per iptables e nftables
SRC_PORT_OPTION_IPT=$(parse_port_range "$SRC_PORT")
DST_PORT_OPTION_IPT=$(parse_port_range "$DST_PORT")
# Aggiungi la regola in iptables
iptables_cmd="iptables -t filter -A $CHAIN_SELECTED -p $PROTOCOL -s $SRC_ADDR --sport $SRC_PORT_OPTION_IPT -d $DST_ADDR --dport $DST_PORT_OPTION_IPT -j $ACTION"
echo "Regola iptables:"
echo "$iptables_cmd"

elif [ "$NFT" != "" ]; then
SRC_PORT_OPTION_NFT=$(parse_port_range_nft "$SRC_PORT")
DST_PORT_OPTION_NFT=$(parse_port_range_nft "$DST_PORT")
# Aggiungi la regola in nftables
nft_action=$(translate_action "$ACTION")
nft_cmd="nft add rule ip filter $CHAIN_SELECTED ip saddr $SRC_ADDR ip daddr $DST_ADDR $PROTOCOL sport $SRC_PORT_OPTION_NFT $PROTOCOL dport $DST_PORT_OPTION_NFT $nft_action"
echo "Regola nftables:"
echo "$nft_cmd" | cat - $DIRCONF/filter/$CHAIN_SELECTED > temp && mv temp $DIRCONF/filter/$CHAIN_SELECTED
else
echo "Intenarl Error NFT or IPT are not set!"
fi