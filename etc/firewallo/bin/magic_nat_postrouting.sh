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

    echo "Configurazione di tipo: $type"
    # Configurazione del MASQUERADE
    if [ "$type" == "MASQUERADE" ]; then
        if [ -z "$dport" ]; then
            iptables -t nat -A POSTROUTING -s "$srcip_mask" -o "$oif" -j MASQUERADE
        else
            iptables -t nat -A POSTROUTING -s "$srcip_mask" -o "$oif" -p tcp --dport "$dport" -j MASQUERADE
        fi
        if [ $? -ne 0 ]; then
            handle_error "Errore nella configurazione MASQUERADE."
        else
            echo "Configurazione MASQUERADE completata con successo."
        fi
    fi

    # Configurazione del SNAT
    if [ "$type" == "SNAT" ]; then
        if [ -z "$dport" ]; then
            iptables -t nat -A POSTROUTING -s "$srcip_mask" -o "$oif" -j SNAT --to-source "$to_source_ip_mask"
        else
            iptables -t nat -A POSTROUTING -s "$srcip_mask" -o "$oif" -p tcp --dport "$dport" -j SNAT --to-source "$to_source_ip_mask"
        fi
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
    echo ""

    read -e -p "Inserisci l'indirizzo IP di origine (srcip) e la maschera (mask) (es. 192.168.1.0/24): " srcip_mask
    read -e -p "Inserisci l'interfaccia di uscita (oif) (es. eth0): " oif

    # Mostra il menu per la scelta del tipo di masquerading
    while true; do
        echo ""
        echo "Scegli il tipo di masquerading:"
        echo "1) MASQUERADE"
        echo "2) SNAT"
        read -p "Inserisci il numero corrispondente (1 o 2): " choice

        case $choice in
            1)
                type="MASQUERADE"
                break
                ;;
            2)
                type="SNAT"
                break
                ;;
            *)
                handle_error "Scelta non valida. Per favore, inserisci 1 per MASQUERADE o 2 per SNAT."
                ;;
        esac
    done

    read -e -p "Inserisci la porta di destinazione (dport) (lascia vuoto se non applicabile): " dport

    if [ "$type" == "SNAT" ]; then
        while true; do
            read -e -p "Inserisci l'indirizzo IP e la maschera per SNAT (es. 192.168.1.1/24): " to_source_ip_mask
            # Verifica la validità dell'indirizzo IP e maschera
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
echo ""
echo "Le regole iptables POSTROUTING sono:"
iptables -t nat -L POSTROUTING -v -n
