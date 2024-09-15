#!/bin/bash

# Funzione per mostrare un messaggio di errore e continuare
handle_error() {
    echo "$1" 1>&2
    echo "Prova a reinserire i parametri correttamente."
}

# Funzione per configurare le regole POSTROUTING
configure_postrouting() {
    local srcip_mask="$1"
    local oif="$2"
    local type="$3"
    local to_source_ip_mask="$4"
    local dport="$5"

    # Configurazione del MASQUERADE
    if [ "$type" == "MASQUERADE" ]; then
        iptables -t nat -A POSTROUTING -s "$srcip_mask" -o "$oif" -p tcp --dport "$dport" -j MASQUERADE
        if [ $? -ne 0 ]; then
            handle_error "Errore nella configurazione MASQUERADE."
        else
            echo "Configurazione MASQUERADE completata con successo."
        fi
    fi

    # Configurazione del SNAT
    if [ "$type" == "SNAT" ]; then
        iptables -t nat -A POSTROUTING -s "$srcip_mask" -o "$oif" -p tcp --dport "$dport" -j SNAT --to-source "$to_source_ip_mask"
        if [ $? -ne 0 ]; then
            handle_error "Errore nella configurazione SNAT."
        else
            echo "Configurazione SNAT completata con successo."
        fi
    fi
}

# Funzione per chiedere i parametri all'utente
ask_for_parameters() {
    echo "Configurazione POSTROUTING con iptables"

    while true; do
        read -p "Inserisci l'indirizzo IP di origine (srcip) e la maschera (mask) (es. 192.168.1.0/24): " srcip_mask
        read -p "Inserisci l'interfaccia di uscita (oif) (es. eth0): " oif
        read -p "Scegli il tipo di masquerading (MASQUERADE o SNAT): " type

        if [ "$type" == "MASQUERADE" ] || [ "$type" == "SNAT" ]; then
            break
        else
            handle_error "Tipo di masquerading non valido. Usa MASQUERADE o SNAT."
        fi
    done

    read -p "Inserisci la porta di destinazione (dport) (es. 80): " dport

    if [ "$type" == "SNAT" ]; then
        while true; do
            read -p "Inserisci l'indirizzo IP e la maschera per SNAT (es. 192.168.1.1/24): " to_source_ip_mask
            # Verifica la validità dell'indirizzo IP e maschera (opzionale, può essere personalizzato)
            if [[ "$to_source_ip_mask" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
                break
            else
                handle_error "Formato dell'indirizzo IP e maschera per SNAT non valido."
            fi
        done
    else
        to_source_ip_mask=""
    fi

    # Applicare la configurazione
    configure_postrouting "$srcip_mask" "$oif" "$type" "$to_source_ip_mask" "$dport"
}

# Eseguire la funzione per chiedere i parametri
ask_for_parameters

# Mostrare le regole applicate
echo "Le regole iptables POSTROUTING sono:"
iptables -t nat -L POSTROUTING -v -n
