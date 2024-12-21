#!/bin/bash

#Load library
source /usr/local/firewallo/lib/wiz.lib

# Carica le traduzioni
load_translations

# Funzione per configurare le regole PREROUTING in iptables
configure_iptables_prerouting() {
    local srcip_mask="$1"
    local iif="$2"
    local protocol="$3"
    local dport=$(parse_port_range_ipt "$4")
    local to_dest_ip="$5"
    local to_dest_port=$(parse_port_range_ipt "$6")
    local comment="$7"

    # Configurazione della regola DNAT in iptables
    echo "
    iptables -t nat -A PREROUTING -s \"$srcip_mask\" -i \"$iif\" -p \"$protocol\" --dport \"$dport\" -j LOG --log-prefix \"DNAT $comment\"
    iptables -t nat -A PREROUTING -s \"$srcip_mask\" -i \"$iif\" -p \"$protocol\" --dport \"$dport\" -j DNAT --to-destination \"$to_dest_ip:$to_dest_port\""
    echo "
    iptables -t nat -A PREROUTING -s \"$srcip_mask\" -i \"$iif\" -p \"$protocol\" --dport \"$dport\" -j LOG --log-prefix \"DNAT $comment\"
    iptables -t nat -A PREROUTING -s \"$srcip_mask\" -i \"$iif\" -p \"$protocol\" --dport \"$dport\" -j DNAT --to-destination \"$to_dest_ip:$to_dest_port\""\
    | cat - $DIRCONF/nat/firewallo.nat > temp && mv temp $DIRCONF/nat/firewallo.nat 
    


    if [ $? -ne 0 ]; then
        handle_error "$DNAT_CONFIG_ERROR"
    else
        echo "$DNAT_CONFIG_SUCCESS"
    fi
}

# Funzione per configurare le regole PREROUTING in nftables
configure_nftables_prerouting() {
    local srcip_mask="$1"
    local iif="$2"
    local protocol="$3"
    local dport=$(parse_port_range_nft "$4")
    local to_dest_ip="$5"
    local to_dest_port=$(parse_port_range_nft "$6")
    local comment="$7"

    # Configurazione della regola DNAT in nftables
    echo "nft add rule ip nat PREROUTING ip saddr $srcip_mask iif $iif $protocol dport $dport log prefix \"DNAT $comment : \" counter dnat to $to_dest_ip:$to_dest_port"
    echo "nft add rule ip nat PREROUTING ip saddr $srcip_mask iif $iif $protocol dport $dport log prefix \\\"DNAT $comment : \\\" counter dnat to $to_dest_ip:$to_dest_port"\
    | cat - $DIRCONF/nat/firewallo.nat > temp && mv temp $DIRCONF/nat/firewallo.nat
    
    if [ $? -ne 0 ]; then
        handle_error "$NFT_DNAT_CONFIG_ERROR"
    else
        echo "$NFT_DNAT_CONFIG_SUCCESS"
    fi
}

# Funzione per chiedere i parametri all'utente
ask_for_parameters() {
    echo "$PREROUTING_CONFIG_PROMPT"
    echo ""
   
    # Chiedi l'indirizzo IP di origine e verifica
    while true; do
        read -e -p "$SRCIP_MASK_PREROUTING_PROMPT" srcip_mask
        validate_ip_mask "$srcip_mask" && break
    done

    while true; do
        read -e -p "$IIF_PROMPT" iif
        validate_if "$iif" && break 
    done

    # Mostra il menu per la scelta del protocollo (tcp o udp)
    while true; do
        echo ""
        echo "$PROTOCOL_PROMPT"
        echo "$TCP_OPTION"
        echo "$UDP_OPTION"
        read -e -p "$CHOICE_PROMPT" protocol_choice

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
                handle_error "$INVALID_TCP_UDP_CHOICE"
                ;;
        esac
    done

    while true; do
        read -e -p "$PORT_DEST_PROMPT" dport
        if [ "$dport" = "" ] ; then  
            echo "null dport not ok" ;
        else
            validate_port $dport && break
        fi
    done

    while true; do
        read -e -p "$DEST_IP_PROMPT" to_dest_ip
        validate_ip $to_dest_ip && break
    done

    while true; do
        read -e -p "$DEST_PORT_PROMPT" to_dest_port
        if [ "$to_dest_port" = "" ] ; then  
            to_dest_port=$dport && break
        else    
            validate_port $to_dest_port && break
        fi
    done

    while true; do
        read -e -p "$COMMENT_PROMPT" comment
        if [[ "$comment" =~ ^[a-zA-Z0-9_]+$ ]]; then
            break
        else
            handle_error "$INVALID_COMMENT_FORMAT"
        fi
    done

    if [ "$IPT" != "" ]; then
     # Applicare la configurazione in iptables
     configure_iptables_prerouting "$srcip_mask" "$iif" "$protocol" "$dport" "$to_dest_ip" "$to_dest_port" "$comment"
    elif [ "$NFT" != "" ]; then
     # Applicare la configurazione in nftables
     configure_nftables_prerouting "$srcip_mask" "$iif" "$protocol" "$dport" "$to_dest_ip" "$to_dest_port" "$comment"
    else
     echo $INT_ERROR_MSG
    fi
}



# Eseguire la funzione per chiedere i parametri
ask_for_parameters