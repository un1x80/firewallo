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
    if [[ "$input" =~ ^(tcp|udp)\ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\ ([0-9]+)\ ([0-9]+)\ (ACCEPT|DROP|REJECT)$ ]]; then
        PROTOCOL="${BASH_REMATCH[1]}"
        SOURCE_IP="${BASH_REMATCH[2]}"
        DEST_IP="${BASH_REMATCH[3]}"
        SOURCE_PORT="${BASH_REMATCH[4]}"
        DEST_PORT="${BASH_REMATCH[5]}"
        ACTION="${BASH_REMATCH[6]}"
    else
        echo "Formato di input non valido. Verifica la sintassi seguente:"
        echo "Sintassi corretta:"
        echo "<tcp|udp> <IP_sorgente> <IP_destinazione> <porta_sorgente> <porta_destinazione> <ACCEPT|DROP|REJECT>"
        echo ""
        echo "Esempio:"
        echo "tcp 192.168.1.1 192.168.10.10 12345 80 ACCEPT"
        echo ""
        echo "Dettagli degli errori:"
        
        # Verifica specifica per ciascun campo
        if [[ ! "$input" =~ ^(tcp|udp) ]]; then
            echo " - Errore nel campo 'protocollo': Deve essere 'tcp' o 'udp'."
        fi
        if [[ ! "$input" =~ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) ]]; then
            echo " - Errore negli IP: Entrambi devono essere indirizzi IP validi."
        fi
        if [[ ! "$input" =~ ([0-9]+)\ ([0-9]+) ]]; then
            echo " - Errore nelle porte: Devono essere numeri validi per porta."
        fi
        if [[ ! "$input" =~ (ACCEPT|DROP|REJECT)$ ]]; then
            echo " - Errore nell'azione: Deve essere 'ACCEPT', 'DROP' o 'REJECT'."
        fi
        
        exit 1
    fi
}

# Mostra la sintassi all'utente
echo "Sintassi del comando:"
echo "<tcp|udp> <IP_sorgente> <IP_destinazione> <porta_sorgente> <porta_destinazione> <ACCEPT|DROP|REJECT>"

# Seleziona la catena
select_chain

# Chiedi all'utente di inserire il comando in formato meta linguaggio
read -p "Inserisci il comando in formato meta linguaggio: " user_input

# Analizza l'input
parse_input "$user_input"

# Aggiungi la regola in iptables per la catena selezionata
echo "iptables -A $CHAIN_SELECTED -p $PROTOCOL -s $SOURCE_IP --sport $SOURCE_PORT -d $DEST_IP --dport $DEST_PORT -j $ACTION"

# Aggiungi la regola in nftables per la catena selezionata
echo "nft add table inet filter"
echo "nft add chain inet filter $CHAIN_SELECTED { type filter hook forward priority 0 \; }"
echo "nft add rule inet filter $CHAIN_SELECTED ip saddr $SOURCE_IP ip daddr $DEST_IP $PROTOCOL sport $SOURCE_PORT dport $DEST_PORT $ACTION"

# Output delle regole finali
echo ""
echo "Regole iptables:"
echo "iptables -A $CHAIN_SELECTED -p $PROTOCOL -s $SOURCE_IP --sport $SOURCE_PORT -d $DEST_IP --dport $DEST_PORT -j $ACTION"

echo ""
echo "Regole nftables:"
echo "nft add table inet filter"
echo "nft add chain inet filter $CHAIN_SELECTED { type filter hook forward priority 0 \; }"
echo "nft add rule inet filter $CHAIN_SELECTED ip saddr $SOURCE_IP ip daddr $DEST_IP $PROTOCOL sport $SOURCE_PORT dport $DEST_PORT $ACTION"

echo ""
echo "Regola aggiunta nella catena '$CHAIN_SELECTED': $PROTOCOL da $SOURCE_IP:$SOURCE_PORT a $DEST_IP:$DEST_PORT ($ACTION)"
