#!/bin/bash
source /etc/firewallo/firewallo.conf
# Elenco delle catene valide
valid_chains=(
    "dmz2lan" "fw2dmz" "fw2vpns" "lan2fw" "lan2wan" "vpns2lan" "wan2dmz" "wan2vpns"
    "dmz2dmz" "dmz2vpns" "fw2fw" "fw2wan" "lan2lan" "vpns2dmz" "vpns2vpns" "wan2fw" "wan2wan"
    "dmz2fw" "dmz2wan" "fw2lan" "lan2dmz" "lan2vpns" "vpns2fw" "vpns2wan" "wan2lan"
)

# Funzione per validare un indirizzo IP (incluso CIDR)
validate_ip_cidr() {
    local ip_cidr="$1"
    if [[ "$ip_cidr" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}(\/[0-9]{1,2})?$ ]]; then
        local ip="${ip_cidr%%/*}"
        IFS='.' read -r -a octets <<< "$ip"

        # Controllo che ogni ottetto sia tra 0 e 255
        for octet in "${octets[@]}"; do
            if (( octet < 0 || octet > 255 )); then
                return 1
            fi
        done

        # Controllo che il CIDR sia tra 0 e 32
        local cidr="${ip_cidr##*/}"
        if [[ "$cidr" != "$ip_cidr" && ( "$cidr" -lt 0 || "$cidr" -gt 32 ) ]]; then
            return 1
        fi

        return 0
    else
        return 1
    fi
}

# Funzione per adattare i valori 'any' e 'range' per iptables e nftables
parse_port_range() {
    local port_range="$1"
    if [[ "$port_range" == "any" ]]; then
        if [ "$IPT" != "" ] ; then
            echo "1:65535"
        elif [ "$NFT" != "" ] ; then    
            echo "1-65535"
        else
            return 1
        fi
    elif [[ "$port_range" =~ ^([0-9]+):([0-9]+)$ ]]; then
        echo "$port_range" | sed 's/:/-/' # Trasforma "100:200" in "100-200"
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
            echo "Errore: Azione non valida '$1'. Utilizzare ACCEPT, DROP o REJECT."
            return 1
            ;;
    esac
}

# Controllo che il numero di argomenti sia corretto
if [ "$#" -ne 8 ]; then
    echo "Errore: numero di argomenti non corretto."
    echo "Uso: $0 <chain> <srcaddr/mask> <tcp|udp> <sport|range|any> <dstaddr/mask> <dport|range|any> <ACCEPT|DROP|REJECT> <comment>"
    exit 0  # Esce solo dal controllo ma non termina la shell
fi

# Assegna gli argomenti a variabili
CHAIN_SELECTED="$1"
SRC_ADDR="$2"
PROTOCOL="$3"
SRC_PORT="$4"
DST_ADDR="$5"
DST_PORT="$6"
ACTION="$7"
COMMENT="$8"

# Verifica che la catena sia valida
if [[ ! " ${valid_chains[@]} " =~ " ${CHAIN_SELECTED} " ]]; then
    echo "Errore: catena '$CHAIN_SELECTED' non valida. Le catene valide sono: ${valid_chains[*]}"
    exit 0  # Esce solo dal controllo ma non termina la shell
fi

# Validazione indirizzi IP CIDR
if ! validate_ip_cidr "$SRC_ADDR"; then
    echo "Errore: indirizzo IP sorgente '$SRC_ADDR' non valido."
fi

if ! validate_ip_cidr "$DST_ADDR"; then
    echo "Errore: indirizzo IP destinazione '$DST_ADDR' non valido."
fi

# Verifica del protocollo
if [[ "$PROTOCOL" != "tcp" && "$PROTOCOL" != "udp" ]]; then
    echo "Errore: protocollo '$PROTOCOL' non valido. Deve essere 'tcp' o 'udp'."
fi

# Converte sport e dport
SRC_PORT_OPTION=$(parse_port_range "$SRC_PORT")
DST_PORT_OPTION=$(parse_port_range "$DST_PORT")

# Traduci l'azione per nftables
nft_action=$(translate_action "$ACTION")
if [ $? -ne 0 ]; then
    exit 0  # Esce solo dal controllo ma non termina la shell
fi

if [ "$IPT" != "" ]; then
# Genera e mostra la regola iptables
iptables_cmd="iptables -t filter -A $CHAIN_SELECTED -p $PROTOCOL -s $SRC_ADDR --sport $SRC_PORT_OPTION -d $DST_ADDR --dport $DST_PORT_OPTION -j $ACTION"
echo "Regola iptables:"
echo "$iptables_cmd" 
#echo "$iptables_cmd" | cat - /etc/firewallo/filter/$CHAIN_SELECTED > temp && mv temp /etc/firewallo/filter/$CHAIN_SELECTED

echo  "
#COMMENT:$COMMENT
$iptables_cmd" >> /etc/firewallo/filter/$CHAIN_SELECTED

# applicare le regole ho scoperto eval :-)
eval "$iptables_cmd"


elif [ "$NFT" != "" ] ; then
# Genera e mostra la regola nftables
nft_cmd="nft add rule ip filter $CHAIN_SELECTED ip saddr $SRC_ADDR ip daddr $DST_ADDR $PROTOCOL sport $SRC_PORT_OPTION $PROTOCOL dport $DST_PORT_OPTION log prefix \\\"$CHAIN_SELECTED : $COMMENT \\\" $nft_action"
echo "Regola nftables:"
echo "$nft_cmd"
#così lo ficca in cima
#echo "$nft_cmd" | cat - /etc/firewallo/filter/$CHAIN_SELECTED > temp && mv temp /etc/firewallo/filter/$CHAIN_SELECTED

#così lo ficca infondo
echo  "
#COMMENT:$COMMENT
$nft_cmd" >> /etc/firewallo/filter/$CHAIN_SELECTED

# applicare le regole ho scoperto eval :-)
eval "$nft_cmd"
fi
