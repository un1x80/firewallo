#!/bin/bash

# Funzione per analizzare l'input
parse_input() {
    local src_ip="$1"
    local dest_ip="$2"
    local protocol="$3"
    local src_port="$4"
    local redirect_ip="$5"
    local redirect_port="$6"
    local interface="$7"

    # Verifica la validità dell'input
    if [[ ! "$src_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?$ ]]; then
        echo "Errore nel campo 'src': '$src_ip' non è un IP valido o manca la maschera di rete (es: 192.168.1.0/24)."
        exit 1
    fi

    if [[ ! "$dest_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?$ ]]; then
        echo "Errore nel campo 'dest': '$dest_ip' non è un IP valido o manca la maschera di rete (es: 0.0.0.0/0)."
        exit 1
    fi

    if [[ "$protocol" != "tcp" && "$protocol" != "udp" ]]; then
        echo "Errore nel campo 'protocol': '$protocol' non è valido. Usa 'tcp' o 'udp'."
        exit 1
    fi

    if [[ ! "$src_port" =~ ^[0-9]+$ || "$src_port" -lt 1 || "$src_port" -gt 65535 ]]; then
        echo "Errore nella porta di origine: '$src_port' non è un numero di porta valido. Deve essere tra 1 e 65535."
        exit 1
    fi

    if [[ ! "$redirect_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Errore nel campo 'to': '$redirect_ip' non è un IP di destinazione valido."
        exit 1
    fi

    if [[ ! "$redirect_port" =~ ^[0-9]+$ || "$redirect_port" -lt 1 || "$redirect_port" -gt 65535 ]]; then
        echo "Errore nella porta di destinazione: '$redirect_port' non è un numero di porta valido. Deve essere tra 1 e 65535."
        exit 1
    fi

    if [[ -z "$interface" ]]; then
        echo "Errore nel campo 'iif': l'interfaccia di rete non può essere vuota."
        exit 1
    fi
}

# Verifica se sono stati passati esattamente 13 argomenti
if [ "$#" -ne 13 ]; then
    echo "Errore: numero di argomenti non corretto."
    echo "Uso: $0 src <IP_sorgente>/<maschera> dest <IP_destinazione>/<maschera> iif <interfaccia> redirect port <tcp|udp> <porta_sorgente> to <IP_redirect> <porta_redirect>"
    exit 1
fi

# Estrai gli argomenti
SRC_ARG="$1"
SRC_IP="$2"
DEST_ARG="$3"
DEST_IP="$4"
IIF_ARG="$5"
IIF="$6"
REDIRECT_ARG="$7"
PROTOCOL_ARG="$8"
PROTOCOL="$9"
SRC_PORT="${10}"
TO_ARG="${11}"
REDIRECT_IP="${12}"
REDIRECT_PORT="${13}"

# Verifica la sintassi degli argomenti principali
if [[ "$SRC_ARG" != "src" ]]; then
    echo "Errore nel campo 'src': il primo argomento deve essere 'src'."
    exit 1
fi

if [[ "$DEST_ARG" != "dest" ]]; then
    echo "Errore nel campo 'dest': il terzo argomento deve essere 'dest'."
    exit 1
fi

if [[ "$IIF_ARG" != "iif" ]]; then
    echo "Errore nel campo 'iif': il quinto argomento deve essere 'iif'."
    exit 1
fi

if [[ "$REDIRECT_ARG" != "redirect" ]]; then
    echo "Errore nel campo 'redirect': il settimo argomento deve essere 'redirect'."
    exit 1
fi

if [[ "$PROTOCOL_ARG" != "port" ]]; then
    echo "Errore nel campo 'port': l'ottavo argomento deve essere 'port'."
    exit 1
fi

if [[ "$TO_ARG" != "to" ]]; then
    echo "Errore nel campo 'to': l'undicesimo argomento deve essere 'to'."
    exit 1
fi

# Analizza e valida l'input
parse_input "$SRC_IP" "$DEST_IP" "$PROTOCOL" "$SRC_PORT" "$REDIRECT_IP" "$REDIRECT_PORT" "$IIF"

# Creare la regola in nftables per il port forwarding
sudo nft add table ip nat

# Aggiungi la regola NAT in PREROUTING per il port forwarding con l'interfaccia di input
sudo nft add chain ip nat PREROUTING { type nat hook prerouting priority 0 \; }
sudo nft add rule ip nat PREROUTING iif "$IIF" ip saddr "$SRC_IP" ip daddr "$DEST_IP" "$PROTOCOL" dport "$SRC_PORT" dnat to "$REDIRECT_IP":"$REDIRECT_PORT"

# Aggiungi una regola di POSTROUTING per permettere il forwarding
sudo nft add chain ip nat POSTROUTING { type nat hook postrouting priority 100 \; }
sudo nft add rule ip nat POSTROUTING ip saddr "$SRC_IP" ip daddr "$REDIRECT_IP" "$PROTOCOL" dport "$REDIRECT_PORT" masquerade

echo "Regola NAT aggiunta: $PROTOCOL porta $SRC_PORT -> $REDIRECT_IP:$REDIRECT_PORT (origine: $SRC_IP su interfaccia $IIF)"
