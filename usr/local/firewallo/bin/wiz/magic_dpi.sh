#!/bin/bash
#
# Copyright (C) 2024 Matteo Fioriti
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, see <http://www.gnu.org/licenses/>.

# Carica la libreria
source /usr/local/firewallo/lib/wiz.lib
source /usr/local/firewallo/lib/firewallo.lib

# Carica le traduzioni
load_translations

# Imposta la catena fissa
CHAIN_SELECTED="dpi"

# Chiedi i dettagli uno per uno all'utente con controlli
while true; do

  
    
    banner_show #Visualizza il banner 
    echo ""
    echo "--------------------------------------------------"
    echo "---Network Dpi Rules-Send Traffic on DPI Engine---"
    echo "--------------------------------------------------"

    read -e -p "$SOURCE_ADDR_PROMPT" SRC_ADDR
    if validate_ip_mask "$SRC_ADDR"; then
        break
    else
        echo "$INVALID_ADDR" ; sleep 1
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
            handle_error "$INVALID_PROTOCOL" ; sleep 1
            ;;
    esac
done

# Chiede la porta sorgente, opzionale (default "any")
while true; do
    read -e -p "$SRC_PORT_PROMPT" SRC_PORT
    SRC_PORT=${SRC_PORT:-any}
    if validate_port "$SRC_PORT"; then
        break
    else
        echo "$INVALID_SPORT" ; sleep 1
    fi
done

# Chiede l'indirizzo di destinazione
while true; do
    read -e -p "$DST_ADDR_PROMPT" DST_ADDR
    if validate_ip_mask "$DST_ADDR"; then
        break
    else
        echo "$INVALID_ADDR" ; sleep 1
    fi
done

# Chiede la porta di destinazione, opzionale (default "any")
while true; do
    read -e -p "$DST_PORT_PROMPT" DST_PORT
    DST_PORT=${DST_PORT:-any}
    if validate_port "$DST_PORT"; then
        break
    else
        echo "$INVALID_DPORT" ; sleep 1
    fi
done

# Chiede il commento per la regola
while true; do
    read -e -p "$COMMENT_PROMPT" comment
    comment=$(echo $comment | tr -s " " "_")
    if [[ "$comment" =~ ^[a-zA-Z0-9_]+$ ]]; then
        break
    else
        handle_error "$INVALID_COMMENT_FORMAT" ; sleep 1
    fi
done

# Aggiungi la regola con nftables per inserire il traffico nella queue 0
if [ "$NFT" != "" ]; then
    # Adatta le porte per nftables
    SRC_PORT_OPTION_NFT=$(parse_port_range_nft "$SRC_PORT")
    DST_PORT_OPTION_NFT=$(parse_port_range_nft "$DST_PORT")
    
    # Costruisci il comando nftables per aggiungere la regola nella catena dpi
    nft_cmd="nft \"insert rule ip filter FORWARD ip saddr $SRC_ADDR ip daddr $DST_ADDR $PROTOCOL sport $SRC_PORT_OPTION_NFT $PROTOCOL dport $DST_PORT_OPTION_NFT counter jump dpi comment \\\"$comment\\\"\""
    
    echo "$NFT_RULE_MSG"; echo "$nft_cmd"
    
    # Aggiungi la regola al file di configurazione, posizionandola in fondo
    echo "
#COMMENT:$comment
$nft_cmd" >> $DIRCONF/filter/$CHAIN_SELECTED

 #   echo "PRESS ENTER TO CONTINUE..." ; read ENTER
else
    echo "$INT_ERROR_MSG"
  #  echo "PRESS ENTER TO CONTINUE..." ; read ENTER
fi
