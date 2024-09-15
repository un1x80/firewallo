#!/bin/bash

# Funzione per visualizzare le catene disponibili e permettere la selezione
select_chain() {
    echo "Seleziona la catena dalla seguente lista:"
    CHAINS=(
        "dmz2lan" "fw2dmz" "fw2vpns" "lan2fw" "lan2wan" "vpns2lan" "wan2dmz" "wan2vpns"
        "dmz2dmz" "dmz2vpns" "fw2fw" "fw2wan" "lan2lan" "vpns2dmz" "vpns2vpns" "wan2fw" "wan2wan"
        "dmz2fw" "dmz2wan" "fw2lan" "lan2dmz" "lan2vpns" "vpns2fw" "vpns2wan" "wan2lan"
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

# Funzione per analizzare l'input
parse_input() {
    local input="$1"
    
    # Usa un'espressione regolare per estrarre i dettagli
    if [[ "$input" =~ ^srcip\ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?)\ (tcp|udp)\ sport\ ([0-9:|any]+)\ dstip\ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?)\ ([0-9:|any]+)\ (ACCEPT|DROP|REJECT)$ ]]; then
        SOURCE_IP="${BASH_REMATCH[1]}"
        PROTOCOL="${BASH_REMATCH[2]}"
        SOURCE_PORT="${BASH_REMATCH[3]}"
        DEST_IP="${BASH_REMATCH[4]}"
        DEST_PORT="${BASH_REMATCH[5]}"
        ACTION="${BASH_REMATCH[6]}"
    else
        echo "Formato di input non valido. Verifica la sintassi seguente:"
        echo "Sintassi corretta:"
        echo "srcip <IP_sorgente/CIDR> <tcp|udp> sport <porta_sorgente|range|any> dstip <IP_destinazione/CIDR> <porta_destinazione|range|any> <ACCEPT|DROP|REJECT>"
        echo ""
        echo "Esempio:"
        echo "srcip 192.168.10.0/24 tcp sport 1024:1028|80|any dstip 192.168.20.1/32 80 ACCEPT"
        echo ""
        echo "Dettagli degli errori:"
        
        # Verifica specifica per ciascun campo
        if [[ ! "$input" =~ srcip\ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?) ]]; then
            echo " - Errore nel campo 'srcip': Deve essere un IP con eventuale maschera."
        fi
        if [[ ! "$input" =~ (tcp|udp) ]]; then
            echo " - Errore nel campo 'protocollo': Deve essere 'tcp' o 'udp'."
        fi
        if [[ ! "$input" =~ sport\ ([0-9:|any]+) ]]; then
            echo " - Errore nel campo 'sport': Deve essere un numero di porta, un range o 'any'."
        fi
        if [[ ! "$input" =~ dstip\ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?) ]]; then
            echo " - Errore nel campo 'dstip': Deve essere un IP con eventuale maschera."
        fi
        if [[ ! "$input" =~ ([0-9:|any]+) ]]; then
            echo " - Errore nel campo 'dport': Deve essere un numero di porta, un range o 'any'."
        fi
        if [[ ! "$input" =~ (ACCEPT|DROP|REJECT)$ ]]; then
            echo " - Errore nell'azione: Deve essere 'ACCEPT', 'DROP' o 'REJECT'."
        fi
        
        exit 1
    fi
}

# Funzione per adattare il valore 'any' in iptables/nftables
parse_port() {
    local port="$1"
    if [[ "$port" == "any" ]]; then
        echo ""
    else
        echo "$port"
    fi
}

# Funzione per convertire il range di porte in formato nftables
parse_port_range() {
    local port_range="$1"
    if [[ "$port_range" == "any" ]]; then
        echo ""
    elif [[ "$port_range" =~ ^([0-9]+):([0-9]+)$ ]]; then
        echo "$port_range"
    else
        echo "$port_range"
    fi
}

# Mostra la sintassi all'utente
echo "Sintassi del comando:"
echo "srcip <IP_sorgente/CIDR> <tcp|udp> sport <porta_sorgente|range|any> dstip <IP_destinazione/CIDR> <porta_destinazione|range|any> <ACCEPT|DROP|REJECT>"

# Seleziona la catena
select_chain

# Chiedi all'utente di inserire il comando in formato meta linguaggio
read -p "Inserisci il comando in formato meta linguaggio: " user_input

# Analizza l'input
parse_input "$user_input"

# Adatta la porta sorgente e destinazione
SOURCE_PORT_OPTION=$(parse_port_range "$SOURCE_PORT")
DEST_PORT_OPTION=$(parse_port_range "$DEST_PORT")

# Aggiungi la regola in iptables per la catena selezionata
if [[ "$SOURCE_PORT_OPTION" == "" ]]; then
    SOURCE_PORT_OPTION=""
else
    SOURCE_PORT_OPTION="--sport $SOURCE_PORT_OPTION"
fi

if [[ "$DEST_PORT_OPTION" == "" ]]; then
    DEST_PORT_OPTION=""
else
    DEST_PORT_OPTION="--dport $DEST_PORT_OPTION"
fi

echo "iptables -A $CHAIN_SELECTED -p $PROTOCOL -s $SOURCE_IP $SOURCE_PORT_OPTION $DEST_PORT_OPTION -d $DEST_IP -j $ACTION"

# Aggiungi la regola in nftables per la catena selezionata
echo "nft add table inet filter"
echo "nft add chain inet filter $CHAIN_SELECTED { type filter hook forward priority 0 \; }"
if [[ "$SOURCE_PORT_OPTION" == "" ]]; then
    SOURCE_PORT_NFT=""
else
    SOURCE_PORT_NFT="sport $SOURCE_PORT_OPTION"
fi

if [[ "$DEST_PORT_OPTION" == "" ]]; then
    DEST_PORT_NFT=""
else
    DEST_PORT_NFT="dport $DEST_PORT_OPTION"
fi

echo "nft add rule inet filter $CHAIN_SELECTED ip saddr $SOURCE_IP ip daddr $DEST_IP $PROTOCOL $SOURCE_PORT_NFT $DEST_PORT_NFT $ACTION"

# Output delle regole finali
echo ""
echo "Regole iptables:"
echo "iptables -A $CHAIN_SELECTED -p $PROTOCOL -s $SOURCE_IP $SOURCE_PORT_OPTION $DEST_PORT_OPTION -d $DEST_IP -j $ACTION"

echo ""
echo "Regole nftables:"
echo "nft add rule inet filter $CHAIN_SELECTED ip saddr $SOURCE_IP ip daddr $DEST_IP $PROTOCOL $SOURCE_PORT_NFT $DEST_PORT_NFT $ACTION"

echo ""
echo "Regola aggiunta nella catena '$CHAIN_SELECTED': $PROTOCOL da $SOURCE_IP:$SOURCE_PORT a $DEST_IP:$DEST_PORT ($ACTION)"
