#!/bin/bash

# Funzione per mostrare un messaggio di errore e continuare
handle_error() {
    echo "$1" 1>&2
    echo "Prova a reinserire i parametri correttamente."
}

# Funzione per configurare le regole PREROUTING in iptables
configure_iptables_prerouting() {
    local srcip_mask="$1"
    local iif="$2"
    local protocol="$3"
    local dport="$4"
    local to_dest_ip="$5"
    local to_dest_port="$6"
    local comment="$7"
    # Configurazione della regola DNAT in iptables
    iptables -t nat -A PREROUTING -s "$srcip_mask" -i "$iif" -p "$protocol" --dport "$dport" -j LOG --log-prefix "DNAT $comment"
    iptables -t nat -A PREROUTING -s "$srcip_mask" -i "$iif" -p "$protocol" --dport "$dport" -j DNAT --to-destination "$to_dest_ip:$to_dest_port" 
    
    if [ $? -ne 0 ]; then
        handle_error "Errore nella configurazione del DNAT in iptables."
    else
        echo "Configurazione DNAT in iptables completata con successo."
    fi
}

# Funzione per configurare le regole PREROUTING in nftables
configure_nftables_prerouting() {
    local srcip_mask="$1"
    local iif="$2"
    local protocol="$3"
    local dport="$4"
    local to_dest_ip="$5"
    local to_dest_port="$6"
    local comment="$7"

    # Configurazione della regola DNAT in nftables
    nft "add rule ip nat PREROUTING ip saddr \"$srcip_mask\" iif \"$iif\" $protocol dport \"$dport\" log prefix \"DNAT $comment : \" counter dnat to \"$to_dest_ip:$to_dest_port\""
    
    if [ $? -ne 0 ]; then
        handle_error "Errore nella configurazione del DNAT in nftables."
    else
        echo "Configurazione DNAT in nftables completata con successo."
    fi
}

# Funzione per chiedere i parametri all'utente
ask_for_parameters() {
    echo "Configurazione PREROUTING con iptables e nftables"
    echo ""

    while true; do
        read -p "Inserisci l'indirizzo IP di origine (srcip) e la maschera (es. 192.168.1.0/24): " srcip_mask
        if [[ "$srcip_mask" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
            break
        else
            handle_error "Indirizzo IP di origine o maschera non valido."
        fi
    done

    while true; do
        read -p "Inserisci l'interfaccia di ingresso (iif) (es. eth0): " iif
        if [[ "$iif" =~ ^[a-zA-Z0-9]+$ ]]; then
            break
        else
            handle_error "Nome dell'interfaccia non valido."
        fi
    done

    # Mostra il menu per la scelta del protocollo (tcp o udp)
    while true; do
        echo ""
        echo "Scegli il protocollo:"
        echo "1) TCP"
        echo "2) UDP"
        read -p "Inserisci il numero corrispondente (1 o 2): " protocol_choice

        case $protocol_choice in
            1)
                protocol="tcp"
                break
                ;;
            2)
                protocol="udp"
                break
                ;;
            *)
                handle_error "Scelta non valida. Per favore, inserisci 1 per TCP o 2 per UDP."
                ;;
        esac
    done

    while true; do
        read -p "Inserisci la porta di destinazione (dport) (es. 80): " dport
        if [[ "$dport" =~ ^[0-9]+$ ]] && [ "$dport" -ge 1 ] && [ "$dport" -le 65535 ]; then
            break
        else
            handle_error "Numero di porta non valido."
        fi
    done

    while true; do
        read -p "Inserisci l'indirizzo IP e la maschera per il DNAT (es. 192.168.10.10): " to_dest_ip
        if [[ "$to_dest_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            break
        else
            handle_error "Indirizzo IP di destinazione non valido."
        fi
    done

    while true; do
        read -p "Inserisci la porta di destinazione finale (es. 8080): " to_dest_port
        if [[ "$to_dest_port" =~ ^[0-9]+$ ]] && [ "$to_dest_port" -ge 1 ] && [ "$to_dest_port" -le 65535 ]; then
            break
        else
            handle_error "Numero di porta di destinazione non valido."
        fi
    done

    while true; do
        read -p "Inserisci il commento alla regola: " comment
        if [[ "$comment" =~ ^[a-zA-Z0-9]+$ ]]; then
            break
        else
            echo "La stringa contiene caratteri non validi."
        fi
    done
    # Applicare la configurazione in iptables
    configure_iptables_prerouting "$srcip_mask" "$iif" "$protocol" "$dport" "$to_dest_ip" "$to_dest_port" "$comment"

    # Applicare la configurazione in nftables
    configure_nftables_prerouting "$srcip_mask" "$iif" "$protocol" "$dport" "$to_dest_ip" "$to_dest_port" "$comment"
}

# Eseguire la funzione per chiedere i parametri
ask_for_parameters

# Mostrare le regole applicate in iptables
echo ""
echo "Le regole iptables PREROUTING sono:"
iptables -t nat -L PREROUTING -v -n

# Mostrare le regole applicate in nftables
echo ""
echo "Le regole nftables PREROUTING sono:"
nft list table ip nat
