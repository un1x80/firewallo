#!/bin/bash

# Funzione per mostrare un messaggio di errore
handle_error() {
    echo "$1" 1>&2
}

# Funzione per analizzare l'input
parse_input() {
    local input="$1"
    if [[ "$input" =~ ^src\ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?)\ dest\ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?)\ iif\ ([a-zA-Z0-9]+)\ redirect\ port\ (tcp|udp)\ ([0-9]+)\ to\ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\ ([0-9]+)$ ]]; then
        SOURCE_IP="${BASH_REMATCH[1]}"
        DEST_IP="${BASH_REMATCH[3]}"
        INTERFACE="${BASH_REMATCH[5]}"
        PROTOCOL="${BASH_REMATCH[6]}"
        SOURCE_PORT="${BASH_REMATCH[7]}"
        REDIRECT_IP="${BASH_REMATCH[8]}"
        REDIRECT_PORT="${BASH_REMATCH[9]}"
        return 0
    else
        return 1
    fi
}

# Funzione per chiedere i parametri all'utente
ask_for_parameters() {
    while true; do
        echo "Sintassi del comando:"
        echo "src <IP_sorgente>/<maschera> dest <IP_destinazione>/<maschera> iif <interfaccia> redirect port <tcp|udp> <porta_sorgente> to <IP_redirect> <porta_redirect>"

        read -p "Inserisci il comando in formato meta linguaggio: " user_input
        
        if parse_input "$user_input"; then
            break
        else
            handle_error "Formato di input non valido. Verifica la sintassi e riprova."
        fi
    done
}

# Funzione per applicare le regole
apply_rules() {
    # Aggiungi la regola NAT in PREROUTING per il port forwarding in iptables
    echo "iptables -t nat -A PREROUTING -p $PROTOCOL -i $INTERFACE -s $SOURCE_IP --dport $SOURCE_PORT -j DNAT --to-destination $REDIRECT_IP:$REDIRECT_PORT"

    # Aggiungi una regola di POSTROUTING in iptables per permettere il forwarding
    echo "iptables -t nat -A POSTROUTING -p $PROTOCOL -d $REDIRECT_IP --dport $REDIRECT_PORT -j MASQUERADE"

    # Aggiungi le regole in nftables per il port forwarding
    echo "nft add rule ip nat PREROUTING iif $INTERFACE ip saddr $SOURCE_IP ip daddr $DEST_IP $PROTOCOL dport $SOURCE_PORT dnat to $REDIRECT_IP:$REDIRECT_PORT"

    # Aggiungi una regola di POSTROUTING in nftables per permettere il forwarding
    echo "nft add rule ip nat POSTROUTING ip saddr $SOURCE_IP ip daddr $REDIRECT_IP $PROTOCOL dport $REDIRECT_PORT masquerade"
}

# Mostra la sintassi e chiede i parametri
ask_for_parameters

# Applicare le regole
apply_rules

# Output delle regole finali
echo ""
echo "Regole iptables:"
echo "iptables -t nat -A PREROUTING -p $PROTOCOL -i $INTERFACE -s $SOURCE_IP --dport $SOURCE_PORT -j DNAT --to-destination $REDIRECT_IP:$REDIRECT_PORT"
echo "iptables -t nat -A POSTROUTING -p $PROTOCOL -d $REDIRECT_IP --dport $REDIRECT_PORT -j MASQUERADE"

echo ""
echo "Regole nftables:"
echo "nft add rule ip nat PREROUTING iif $INTERFACE ip saddr $SOURCE_IP ip daddr $DEST_IP $PROTOCOL dport $SOURCE_PORT dnat to $REDIRECT_IP:$REDIRECT_PORT"
echo "nft add rule ip nat POSTROUTING ip saddr $SOURCE_IP ip daddr $REDIRECT_IP $PROTOCOL dport $REDIRECT_PORT masquerade"

echo ""
echo "Regola NAT aggiunta: $PROTOCOL porta $SOURCE_PORT -> $REDIRECT_IP:$REDIRECT_PORT (origine: $SOURCE_IP su interfaccia $INTERFACE)"
