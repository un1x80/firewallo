#!/bin/bash

DIRCONF="/etc/firewallo"
source $DIRCONF/firewallo.conf

# Carica il file di traduzione
load_translations() {
    local lang_file="$DIRCONF/lang/firewallo.lang.$LANG"
    if [[ -f "$lang_file" ]]; then
        source "$lang_file"
    else
        echo "LANG_NOT_FOUND"
        exit 1
    fi
}

# Funzione per mostrare un messaggio di errore e continuare
handle_error() {
    echo "$1" 1>&2
    echo "$INVALID_SELECTION_MSG"
}

# Funzione per configurare le regole POSTROUTING
configure_postrouting() {
    local srcip_mask="$1"
    local oif="$2"
    local type="$3"
    local to_source_ip_mask="$4"
    local dport="$5"

    echo "$POSTROUTING_CONFIG_PROMPT"
    echo ""

    # Configurazione del MASQUERADE
    if [ "$type" == "MASQUERADE" ]; then
        if [ -z "$dport" ]; then
            if [ "$IPT" != "" ]; then
                $IPT -t nat -A POSTROUTING -s "$srcip_mask" -o "$oif" -j MASQUERADE\
                | cat - $DIRCONF/nat/firewallo.nat > temp && mv temp $DIRCONF/nat/firewallo.nat
            elif [ "$NFT" != "" ]; then
                $NFT "add rule ip nat POSTROUTING ip saddr \"$srcip_mask\" oif \"$oif\" masquerade"\
                | cat - $DIRCONF/nat/firewallo.nat > temp && mv temp $DIRCONF/nat/firewallo.nat
            else
                echo $INT_ERROR_MSG
            fi
        else
            if [ "$IPT" != "" ]; then
                $IPT -t nat -A POSTROUTING -s "$srcip_mask" -o "$oif" -p tcp --dport "$dport" -j MASQUERADE\
                | cat - $DIRCONF/nat/firewallo.nat > temp && mv temp $DIRCONF/nat/firewallo.nat
            elif [ "$NFT" != "" ]; then
                echo "$NFT \"add rule ip nat POSTROUTING ip saddr \"$srcip_mask\" oif \"$oif\" tcp dport \"$dport\" masquerade\"" \
                | cat - $DIRCONF/nat/firewallo.nat > temp && mv temp $DIRCONF/nat/firewallo.nat
            else
                echo $INT_ERROR_MSG
            fi
        fi
        if [ $? -ne 0 ]; then
            handle_error "$CONFIG_ERROR"
        else
            echo "$CONFIG_SUCCESS"
        fi
    fi

    # Configurazione del SNAT
    if [ "$type" == "SNAT" ]; then
        if [ -z "$dport" ]; then
            iptables -t nat -A POSTROUTING -s "$srcip_mask" -o "$oif" -j SNAT --to-source "$to_source_ip_mask"\
                | cat - $DIRCONF/nat/firewallo.nat > temp && mv temp $DIRCONF/nat/firewallo.nat
        else
            iptables -t nat -A POSTROUTING -s "$srcip_mask" -o "$oif" -p tcp --dport "$dport" -j SNAT --to-source "$to_source_ip_mask"\
                | cat - $DIRCONF/nat/firewallo.nat > temp && mv temp $DIRCONF/nat/firewallo.nat
        fi
        if [ $? -ne 0 ]; then
            handle_error "$SNAT_CONFIG_ERROR"
        else
            echo "$SNAT_CONFIG_SUCCESS"
        fi
    fi
}

# Funzione per chiedere i parametri all'utente
ask_for_parameters() {
    echo "$POSTROUTING_CONFIG_PROMPT"
    echo ""

    read -e -p "$SRCIP_MASK_PROMPT" srcip_mask
    read -e -p "$OIF_PROMPT" oif

    # Mostra il menu per la scelta del tipo di masquerading
    while true; do
        echo ""
        echo "$MASQUERADE_PROMPT"
        echo "$MASQUERADE_OPTION"
        echo "$SNAT_OPTION"
        read -p "$CHOICE_PROMPT" choice

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
                handle_error "$ERROR_HANDLER_MASQ"
                ;;
        esac
    done

    read -e -p "$PORT_PROMPT" dport

    if [ "$type" == "SNAT" ]; then
        while true; do
            read -e -p "$SNAT_SOURCE_IP_PROMPT" to_source_ip_mask
            # Verifica la validità dell'indirizzo IP e maschera
            if [[ "$to_source_ip_mask" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
                break
            else
                handle_error "$INVALID_SOURCIP_MASK_FORMAT"
            fi
        done
    else
        to_source_ip_mask=""
    fi

    # Applicare la configurazione
    configure_postrouting "$srcip_mask" "$oif" "$type" "$to_source_ip_mask" "$dport"
}

# Carica le traduzioni
load_translations

# Eseguire la funzione per chiedere i parametri
ask_for_parameters

