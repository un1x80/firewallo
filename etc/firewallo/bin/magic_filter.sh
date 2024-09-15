#!/bin/bash

# Funzione per visualizzare le catene disponibili e permettere la selezione
select_chain() {
    echo "Seleziona la catena dalla seguente lista:"
    CHAINS=(
fw2fw	fw2lan		fw2wan		fw2vpns		fw2dmz		\
lan2fw	lan2lan		lan2wan		lan2vpns 	lan2dmz  	\
wan2fw	wan2lan		wan2wan		wan2vpns 	wan2dmz   	\
vpns2fw	vpns2lan	vpns2wan	vpns2vpns 	vpns2dmz 	\
dmz2fw	dmz2lan		dmz2wan		dmz2vpns 	dmz2dmz 	\
exit"
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
# Funzione per analizzare l'input
parse_input() {
    local input="$1"
    
    # Usa un'espressione regolare per estrarre i dettagli
    if [[ "$input" =~ ^([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+)\ (tcp|udp)\ (any|[0-9:]+)\ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+)\ (any|[0-9:]+)\ (ACCEPT|DROP|REJECT)$ ]]; then
        SRC_ADDR="${BASH_REMATCH[1]}"
        PROTOCOL="${BASH_REMATCH[2]}"
        SRC_PORT="${BASH_REMATCH[3]}"
        DST_ADDR="${BASH_REMATCH[4]}"
        DST_PORT="${BASH_REMATCH[5]}"
        ACTION="${BASH_REMATCH[6]}"
    else
        echo "Formato di input non valido. Verifica la sintassi seguente:"
        echo "Sintassi corretta:"
        echo "<srcaddr/mask> <tcp|udp> <sport|range|any> <dstaddr/mask> <dport|range|any> <ACCEPT|DROP|REJECT>"
        echo ""
        echo "Esempio:"
        echo "192.168.1.1/32 tcp any 192.168.10.1/32 80 ACCEPT"
        exit 1
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
# Mostra la sintassi all'utente

echo "Sintassi del comando:"
echo "<srcaddr/mask> <tcp|udp> <sport|range|any> <dstaddr/mask> <dport|range|any> <ACCEPT|DROP|REJECT>"
# Chiedi all'utente di inserire i parametri
read -p "Inserisci i parametri (esempio: 192.168.1.1/32 tcp any 192.168.10.1/32 80 ACCEPT): " user_input

# Analizza l'input
parse_input "$user_input"

# Adatta le porte per iptables e nftables
SRC_PORT_OPTION_IPT=$(parse_port_range "$SRC_PORT")
SRC_PORT_OPTION_NFT=$(parse_port_range_nft "$SRC_PORT")
DST_PORT_OPTION_IPT=$(parse_port_range "$DST_PORT")
DST_PORT_OPTION_NFT=$(parse_port_range_nft "$DST_PORT")

# Aggiungi la regola in iptables
iptables_cmd="iptables -t filter -A $CHAIN_SELECTED -p $PROTOCOL -s $SRC_ADDR --sport $SRC_PORT_OPTION -d $DST_ADDR --dport $DST_PORT_OPTION -j $ACTION"
echo "Regola iptables:"
echo "$iptables_cmd"

# Aggiungi la regola in nftables
nft_action=$(translate_action "$ACTION")
nft_cmd="nft add rule ip filter $CHAIN_SELECTED ip saddr $SRC_ADDR ip daddr $DST_ADDR $PROTOCOL sport $SRC_PORT_OPTION_NFT $PROTOCOL dport $DST_PORT_OPTION_NFT $nft_action"
echo "Regola nftables:"
echo "$nft_cmd"