#!/bin/bash

# Funzione per analizzare l'input
parse_input() {
    local input="$1"
    # Usa un'espressione regolare per estrarre i dettagli
    if [[ "$input" =~ ^src\ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?)\ dest\ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?)\ iif\ ([a-zA-Z0-9]+)\ redirect\ port\ (tcp|udp)\ ([0-9]+)\ to\ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\ ([0-9]+)$ ]]; then
        SOURCE_IP="${BASH_REMATCH[1]}"
        DEST_IP="${BASH_REMATCH[3]}"
        INTERFACE="${BASH_REMATCH[5]}"
        PROTOCOL="${BASH_REMATCH[6]}"
        SOURCE_PORT="${BASH_REMATCH[7]}"
        REDIRECT_IP="${BASH_REMATCH[8]}"
        REDIRECT_PORT="${BASH_REMATCH[9]}"
    else
        echo "Formato di input non valido. Verifica la sintassi seguente:"
        echo "Sintassi corretta:"
        echo "src <IP_sorgente>/<maschera> dest <IP_destinazione>/<maschera> iif <interfaccia> redirect port <tcp|udp> <porta_sorgente> to <IP_redirect> <porta_redirect>"
        echo ""
        echo "Esempio:"
        echo "src 192.168.1.0/24 dest 0.0.0.0/0 iif eth0 redirect port tcp 80 to 192.168.10.90 8080"
        echo ""
        echo "Dettagli degli errori:"
        # Verifica specifica per ciascun campo
        if [[ ! "$input" =~ ^src\ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?) ]]; then
            echo " - Errore nel campo 'src': Deve essere un IP con eventuale maschera."
        fi
        if [[ ! "$input" =~ dest\ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?) ]]; then
            echo " - Errore nel campo 'dest': Deve essere un IP con eventuale maschera."
        fi
        if [[ ! "$input" =~ iif\ ([a-zA-Z0-9]+) ]]; then
            echo " - Errore nel campo 'iif': Deve essere un nome di interfaccia valido."
        fi
        if [[ ! "$input" =~ redirect\ port\ (tcp|udp) ]]; then
            echo " - Errore nel campo 'redirect port': Deve essere seguito da 'tcp' o 'udp'."
        fi
        if [[ ! "$input" =~ redirect\ port\ (tcp|udp)\ ([0-9]+) ]]; then
            echo " - Errore nella porta di origine: Deve essere un numero di porta valido."
        fi
        if [[ ! "$input" =~ to\ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) ]]; then
            echo " - Errore nel campo 'to': Deve essere seguito da un IP di destinazione."
        fi
        if [[ ! "$input" =~ to\ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\ ([0-9]+) ]]; then
            echo " - Errore nella porta di destinazione: Deve essere un numero di porta valido."
        fi

        exit 1
    fi
}

# Mostra la sintassi all'utente
echo "Sintassi del comando:"
echo "src <IP_sorgente>/<maschera> dest <IP_destinazione>/<maschera> iif <interfaccia> redirect port <tcp|udp> <porta_sorgente> to <IP_redirect> <porta_redirect>"

# Chiedi all'utente di inserire il comando in formato meta linguaggio
read -p "Inserisci il comando in formato meta linguaggio: " user_input

# Analizza l'input
parse_input "$user_input"

# Aggiungi la regola NAT in PREROUTING per il port forwarding in iptables
echo "iptables -t nat -A PREROUTING -p $PROTOCOL -i $INTERFACE -s $SOURCE_IP --dport $SOURCE_PORT -j DNAT --to-destination $REDIRECT_IP:$REDIRECT_PORT"

# Aggiungi una regola di POSTROUTING in iptables per permettere il forwarding
echo "iptables -t nat -A POSTROUTING -p $PROTOCOL -d $REDIRECT_IP --dport $REDIRECT_PORT -j MASQUERADE"

# Aggiungi le regole in nftables per il port forwarding
echo "nft add rule ip nat PREROUTING iif $INTERFACE ip saddr $SOURCE_IP ip daddr $DEST_IP $PROTOCOL dport $SOURCE_PORT dnat to $REDIRECT_IP:$REDIRECT_PORT"

# Aggiungi una regola di POSTROUTING in nftables per permettere il forwarding
echo "nft add rule ip nat POSTROUTING ip saddr $SOURCE_IP ip daddr $REDIRECT_IP $PROTOCOL dport $REDIRECT_PORT masquerade"

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
