#!/bin/bash

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
        echo "1-65535"
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
            echo "Azione non valida: utilizzare ACCEPT, DROP o REJECT."
            return 1
            ;;
    esac
}

# Loop per assicurarsi che gli input siano corretti
while true; do
    # Richiedi l'input all'utente
    read -p "Inserisci il comando in formato: filter <chain> <srcaddr/mask> <tcp|udp> <sport|range|any> <dstaddr/mask> <dport|range|any> <ACCEPT|DROP|REJECT>: " CHAIN_SELECTED SRC_ADDR PROTOCOL SRC_PORT DST_ADDR DST_PORT ACTION

    # Verifica che il numero di argomenti sia esatto
    if [ "$#" -ne 8 ]; then
        echo "Errore: numero di argomenti non corretto."
        continue
    fi

    # Verifica che la catena sia valida
    if [[ ! " ${valid_chains[@]} " =~ " ${CHAIN_SELECTED} " ]]; then
        echo "Errore: catena '$CHAIN_SELECTED' non valida. Le catene valide sono: ${valid_chains[*]}"
        continue
    fi

    # Validazione indirizzi IP CIDR
    if ! validate_ip_cidr "$SRC_ADDR"; then
        echo "Errore: indirizzo IP sorgente '$SRC_ADDR' non valido."
        continue
    fi

    if ! validate_ip_cidr "$DST_ADDR"; then
        echo "Errore: indirizzo IP destinazione '$DST_ADDR' non valido."
        continue
    fi

    # Adatta le porte per iptables e nftables
    SRC_PORT_OPTION=$(parse_port_range "$SRC_PORT")
    DST_PORT_OPTION=$(parse_port_range "$DST_PORT")

    # Traduzione azione per nftables
    nft_action=$(translate_action "$ACTION")
    if [ $? -ne 0 ]; then
        continue
    fi

    # Aggiungi la regola in iptables
    iptables_cmd="iptables -t filter -A $CHAIN_SELECTED -p $PROTOCOL -s $SRC_ADDR --sport $SRC_PORT_OPTION -d $DST_ADDR --dport $DST_PORT_OPTION -j $ACTION"
    echo "Regola iptables:"
    echo "$iptables_cmd"

    # Aggiungi la regola in nftables
    nft_cmd="nft add rule ip filter $CHAIN_SELECTED ip saddr $SRC_ADDR ip daddr $DST_ADDR $PROTOCOL sport $SRC_PORT_OPTION dport $DST_PORT_OPTION $nft_action"
    echo "Regola nftables:"
    echo "$nft_cmd"

    # Esegui i comandi (facoltativo, togliere i commenti per eseguire)
    # eval "$iptables_cmd"
    # eval "$nft_cmd"

    # Se tutto è andato a buon fine, esci dal loop
    break
done
