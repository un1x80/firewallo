#!/bin/bash

#Load library
source /usr/local/firewallo/lib/lib-wiz.sh

# Carica le traduzioni
load_translations

# Seleziona la catena se non ti viene passata
if [ "$1" = "" ] ; then
select_chain
elif [ "$1 != " ] ; then
CHAIN_SELECTED=$1
fi

# Chiedi i dettagli uno per uno all'utente con controlli
while true; do
    read -e -p "$SOURCE_ADDR_PROMPT" SRC_ADDR
    if validate_ip_mask "$SRC_ADDR"; then
        break
    fi
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
                PROTOCOL="tcp"
                break
                ;;
            2)
                PROTOCOL="udp"
                break
                ;;
            *)
                handle_error "$INVALID_PROTOCOL"
                ;;
        esac
    done

while true; do
    read -e -p "$SRC_PORT_PROMPT" SRC_PORT
    SRC_PORT=${SRC_PORT:-any}
    if validate_port "$SRC_PORT"; then
        break
    else
        echo "$INVALID_SPORT"
    fi
done

while true; do
    read -e -p "$DST_ADDR_PROMPT" DST_ADDR
    if validate_ip_mask "$DST_ADDR"; then
        break
    fi
done

while true; do
    read -e -p "$DST_PORT_PROMPT" DST_PORT
    DST_PORT=${DST_PORT:-any}
    if validate_port "$DST_PORT"; then
        break
    else
        echo "$INVALID_DPORT"
    fi
done

while true; do
    read -e -p "$ACTION_PROMPT" ACTION
    if [[ "$ACTION" =~ ^(ACCEPT|DROP|REJECT)$ ]]; then
        break
    else
        echo "$ERROR_INVALID_ACTION"
    fi
done
while true; do
    read -e -p "$COMMENT_PROMPT" comment
    comment=$(echo $commet| tr -s " " "_")
        if [[ "$comment" =~ ^[a-zA-Z0-9_]+$ ]]; then
        break
    else
        handle_error "$INVALID_COMMENT_FORMAT"
    fi
done
if [ "$IPT" != "" ] ; then
    
    # Adatta le porte per iptables
    SRC_PORT_OPTION_IPT=$(parse_port_range_ipt "$SRC_PORT")
    DST_PORT_OPTION_IPT=$(parse_port_range_ipt "$DST_PORT")
    # Aggiungi la regola in iptables
    iptables_cmd="iptables -t filter -A $CHAIN_SELECTED -p $PROTOCOL -s $SRC_ADDR --sport $SRC_PORT_OPTION_IPT -d $DST_ADDR --dport $DST_PORT_OPTION_IPT -j $ACTION"
    echo "$IPT_RULE_MSG" ; echo "$iptables_cmd"
    #Così lo ficca in cima
    # echo "$iptables_cmd"| cat - $DIRCONF/filter/$CHAIN_SELECTED > temp && mv temp $DIRCONF/filter/$CHAIN_SELECTED
    #così lo ficca infondo
    printf  "\n$iptables_cmd" >> $DIRCONF/filter/$CHAIN_SELECTED
    echo "PRESS ENTER TO CONTINUE..." ; read ENTER

elif [ "$NFT" != "" ]; then
    
    # Adatta le porte per nftables
    SRC_PORT_OPTION_NFT=$(parse_port_range_nft "$SRC_PORT")
    DST_PORT_OPTION_NFT=$(parse_port_range_nft "$DST_PORT")
    # Traduci l'azione in nftables
    nft_action=$(translate_action "$ACTION")
    nft_cmd="nft \"add rule ip filter $CHAIN_SELECTED ip saddr $SRC_ADDR ip daddr $DST_ADDR $PROTOCOL sport $SRC_PORT_OPTION_NFT $PROTOCOL dport $DST_PORT_OPTION_NFT log prefix \\\"$CHAIN_SELECTED $comment : \\\" $nft_action\""
    echo "$NFT_RULE_MSG"; echo "$nft_cmd"
    #Così lo ficca in cima
    #echo $nft_cmd | cat - $DIRCONF/filter/$CHAIN_SELECTED > temp && mv temp $DIRCONF/filter/$CHAIN_SELECTED
    #così lo ficca infondo
    printf "\n$nft_cmd" >> $DIRCONF/filter/$CHAIN_SELECTED
    echo "PRESS ENTER TO CONTINUE..." ; read ENTER

else
    echo "$INT_ERROR_MSG" ;     echo "PRESS ENTER TO CONTINUE..." ; read ENTER

fi
