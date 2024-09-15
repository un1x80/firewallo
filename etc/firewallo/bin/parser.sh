#!/bin/bash

# Funzione per analizzare l'input
parse_input() {
    local input="$1"
    
    # Usa un'espressione regolare per estrarre i dettagli
    if [[ "$input" =~ ^src\ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?)\ dest\ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?)\ redirect\ port\ (tcp|udp)\ ([0-9]+)\ to\ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\ ([0-9]+)$ ]]; then
        SOURCE_IP="${BASH_REMATCH[1]}"
        DEST_IP="${BASH_REMATCH[3]}"
        PROTOCOL="${BASH_REMATCH[4]}"
        SOURCE_PORT="${BASH_REMATCH[5]}"
        REDIRECT_IP="${BASH_REMATCH[6]}"
        REDIRECT_PORT="${BASH_REMATCH[7]}"
    else
        echo "Formato di input non valido. Verifica la sintassi seguente:"
        echo "Sintassi corretta:"
        echo "src <IP_sorgente>/<maschera> dest <IP_destinazione>/<maschera> redirect port <tcp|udp> <porta_sorgente> to <IP_redirect> <porta_redirect>"
        echo ""
        echo "Esempio:"
        echo "src 192.168.1.0/24 dest 0.0.0.0/0 redirect port tcp 80 to 192.168.10.90 8080"
        echo ""
        echo "Dettagli degli errori:"
        
        # Verifica specifica per ciascun campo
        if [[ ! "$input" =~ ^src\ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?) ]]; then
            echo " - Errore nel campo 'src': Deve essere un IP con eventuale maschera."
        fi
        if [[ ! "$input" =~ dest\ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?) ]]; then
            echo " - Errore nel campo 'dest': Deve essere un IP con eventuale maschera."
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
echo "src <IP_sorgente>/<maschera> dest <IP_destinazione>/<maschera> redirect port <tcp|udp> <porta_sorgente> to <IP_redirect> <porta_redirect>"

# Chiedi all'utente di inserire il comando in formato meta linguaggio
read -p "Inserisci il comando in formato meta linguaggio: " user_input

# Analizza l'input
parse_input "$user_input"

# Aggiungi la regola NAT in PREROUTING per il port forwarding
echo iptables -t nat -A PREROUTING -p "$PROTOCOL" -s "$SOURCE_IP" --dport "$SOURCE_PORT" -j DNAT --to-destination "$REDIRECT_IP:$REDIRECT_PORT"

# Aggiungi una regola di POSTROUTING per permettere il forwarding
echo iptables -t nat -A POSTROUTING -p "$PROTOCOL" -d "$REDIRECT_IP" --dport "$REDIRECT_PORT" -j MASQUERADE

echo "Regola NAT aggiunta: $PROTOCOL porta $SOURCE_PORT -> $REDIRECT_IP:$REDIRECT_PORT (origine: $SOURCE_IP)"
