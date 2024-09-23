#!/bin/bash

source /sur/local/firewallo/lib/lib-fwallo.sh

# Funzione per configurare le regole POSTROUTING
configure_postrouting() {
    local srcip_mask="$1"
    local oif="$2"
    local type="$3"
    local to_source_ip="$4"
    local dport="$5"
    local comment="$6"


    # Configurazione del MASQUERADE
    if [ "$type" == "MASQUERADE" ]; then
        if [ -z "$dport" ]; then
            if [ "$IPT" != "" ]; then
                echo "$IPT -t nat -A POSTROUTING -s \"$srcip_mask\" -o \"$oif\" -j MASQUERADE"
                echo "$IPT -t nat -A POSTROUTING -s \"$srcip_mask\" -o \"$oif\" -j MASQUERADE"\
                | cat - $DIRCONF/nat/firewallo.nat > temp && mv temp $DIRCONF/nat/firewallo.nat
            elif [ "$NFT" != "" ]; then
                echo "$NFT \"add rule ip nat POSTROUTING ip saddr \"$srcip_mask\" oif \"$oif\" log prefix \\\" POSTROUTING $comment : \\\" counter masquerade\""
                echo "$NFT \"add rule ip nat POSTROUTING ip saddr \"$srcip_mask\" oif \"$oif\" log prefix \\\" POSTROUTING $comment : \\\" counter masquerade\""\
                | cat - $DIRCONF/nat/firewallo.nat > temp && mv temp $DIRCONF/nat/firewallo.nat
            else
                echo $INT_ERROR_MSG
            fi
        else
            if [ "$IPT" != "" ]; then
                echo "$IPT -t nat -A POSTROUTING -s \"$srcip_mask\" -o \"$oif\" -p tcp --dport \"$dport\" -j MASQUERADE"
                echo "$IPT -t nat -A POSTROUTING -s \"$srcip_mask\" -o \"$oif\" -p tcp --dport \"$dport\" -j MASQUERADE"\
                | cat - $DIRCONF/nat/firewallo.nat > temp && mv temp $DIRCONF/nat/firewallo.nat
            elif [ "$NFT" != "" ]; then
                echo "$NFT \"add rule ip nat POSTROUTING ip saddr \"$srcip_mask\" oif \"$oif\" tcp dport \"$dport\" log prefix \\\" POSTROUTING $comment : \\\" counter masquerade\""
                echo "$NFT \"add rule ip nat POSTROUTING ip saddr \"$srcip_mask\" oif \"$oif\" tcp dport \"$dport\" log prefix \\\" POSTROUTING $comment : \\\" counter masquerade\"" \
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
          if [ "$IPT" != "" ]; then
             echo "iptables -t nat -A POSTROUTING -s \"$srcip_mask\" -o \"$oif\" -j SNAT --to-source \"$to_source_ip\""
             echo "iptables -t nat -A POSTROUTING -s \"$srcip_mask\" -o \"$oif\" -j SNAT --to-source \"$to_source_ip\""\
                | cat - $DIRCONF/nat/firewallo.nat > temp && mv temp $DIRCONF/nat/firewallo.nat
           elif [ "$NFT" != "" ]; then
             echo "nft add rule ip nat POSTROUTING ip saddr \"$srcip_mask\" oif \"$oif\" log prefix \\\" POSTROUTING $comment : \\\" counter snat to \"$to_source_ip\""
             echo "nft add rule ip nat POSTROUTING ip saddr \"$srcip_mask\" oif \"$oif\" log prefix \\\" POSTROUTING $comment : \\\" counter snat to \"$to_source_ip\""\
                | cat - $DIRCONF/nat/firewallo.nat > temp && mv temp $DIRCONF/nat/firewallo.nat
           else
             echo $INT_ERROR_MSG
          fi
        else
            if [ "$IPT" != "" ]; then
             echo "iptables -t nat -A POSTROUTING -s \"$srcip_mask\" -o \"$oif\" -p tcp --dport \"$dport\" -j SNAT --to-source \"$to_source_ip\""
             echo "iptables -t nat -A POSTROUTING -s \"$srcip_mask\" -o \"$oif\" -p tcp --dport \"$dport\" -j SNAT --to-source \"$to_source_ip\""\
                | cat - $DIRCONF/nat/firewallo.nat > temp && mv temp $DIRCONF/nat/firewallo.nat
            elif [ "$NFT" != "" ]; then
             echo "nft add rule ip nat POSTROUTING ip saddr \"$srcip_mask\" oif \"$oif\" tcp dport \"$dport\" log prefix \\\" POSTROUTING $comment : \\\" counter snat to \"$to_source_ip\""
             echo "nft add rule ip nat POSTROUTING ip saddr \"$srcip_mask\" oif \"$oif\" tcp dport \"$dport\" log prefix \\\" POSTROUTING $comment : \\\" counter snat to \"$to_source_ip\""\
              | cat - $DIRCONF/nat/firewallo.nat > temp && mv temp $DIRCONF/nat/firewallo.nat
            else
            echo $INT_ERROR_MSG
          fi
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

    # Chiedi l'indirizzo IP di origine e verifica
    while true; do
        read -e -p "$SRCIP_MASK_PROMPT" srcip_mask
        validate_ip_mask "$srcip_mask" && break
    done

    # Chiedi l'interfaccia di uscita e verifica
    while true; do
        read -e -p "$OIF_PROMPT" oif
        validate_if "$oif" && break
    done

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

    # Chiedi la porta e verifica
    while true; do
        read -e -p "$PORT_PROMPT" dport
        validate_port "$dport" && break
    done

    # Se il tipo è SNAT, chiedi l'indirizzo IP di destinazione
    if [ "$type" == "SNAT" ]; then
        while true; do
            read -e -p "$SNAT_SOURCE_IP_PROMPT" to_source_ip
            validate_ip "$to_source_ip" && break
        done
    else
        to_source_ip=""
    fi
    while true; do
        read -e -p "$COMMENT_PROMPT" comment
        if [[ "$comment" =~ ^[a-zA-Z0-9_]+$ ]]; then
            break
        else
            handle_error "$INVALID_COMMENT_FORMAT"
        fi
    done
    # Applicare la configurazione
    configure_postrouting "$srcip_mask" "$oif" "$type" "$to_source_ip" "$dport" "$comment"
}

# Carica le traduzioni
load_translations

# Eseguire la funzione per chiedere i parametri
ask_for_parameters
