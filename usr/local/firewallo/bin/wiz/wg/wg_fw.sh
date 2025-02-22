#!/bin/bash
#
# Copyright (C) 2024 Matteo Fioriti
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, see <http://www.gnu.org/licenses/>.
WG_INTERFACE="wg0"

# Funzione per configurare regole di firewall per WireGuard
function configure_firewall_rules() {
    local client_ip=$1
    local allowed_ips=$2

    echo "Configurazione del firewall per l'utente con IP $client_ip..."

    # Definisci la tabella nft per WireGuard se non esiste già
    nft list tables | grep -q "inet wireguard" || nft add table inet wireguard

    # Definisci la catena input e forward se non esiste già
    nft list chain inet wireguard input || nft add chain inet wireguard input { type filter hook input priority 0 \; policy drop \; }
    nft list chain inet wireguard forward || nft add chain inet wireguard forward { type filter hook forward priority 0 \; policy drop \; }

    # Permetti il traffico su WireGuard
    nft add rule inet wireguard input ip saddr "$client_ip" oif "$WG_INTERFACE" accept

    # Aggiungi regole per il traffico in forward (limitato agli AllowedIPs)
    for ip in $(echo "$allowed_ips" | tr ',' '\n'); do
        nft add rule inet wireguard forward ip saddr "$client_ip" ip daddr "$ip" accept
    done

    echo "Regole di firewall configurate per l'utente $client_ip."
}

# Funzione per rimuovere le regole di firewall per un client WireGuard
function remove_firewall_rules() {
    local client_ip=$1
    echo "Rimozione delle regole di firewall per l'utente con IP $client_ip..."

    nft delete rule inet wireguard input ip saddr "$client_ip" oif "$WG_INTERFACE"
    nft list ruleset | grep -A 1 "ip saddr $client_ip" | while read -r line; do
        nft delete rule inet wireguard forward handle $(echo $line | grep -oP '\d+')
    done

    echo "Regole di firewall rimosse per l'utente $client_ip."
}

# Funzione per elencare le regole di firewall attive per WireGuard
function list_firewall_rules() {
    echo "Regole di firewall attive per WireGuard:"
    nft list ruleset | grep -A 5 "table inet wireguard"
}

# Menu principale per la gestione del firewall
while true; do
    echo "Gestione firewall WireGuard - Seleziona un'opzione:"
    echo "1) Configura regole di firewall per un nuovo utente"
    echo "2) Rimuovi le regole di firewall per un utente"
    echo "3) Lista delle regole di firewall attive"
    echo "4) Esci"

    read -p "Seleziona un'opzione: " option

    case $option in
        1)
            read -p "Inserisci l'IP del client: " client_ip
            read -p "Inserisci le AllowedIPs per il client (separati da virgola, es. 192.168.1.0/24,10.0.0.0/8): " allowed_ips
            configure_firewall_rules "$client_ip" "$allowed_ips"
            ;;
        2)
            read -p "Inserisci l'IP del client: " client_ip
            remove_firewall_rules "$client_ip"
            ;;
        3)
            list_firewall_rules
            ;;
        4)
            echo "Uscita dallo script."
            exit 0
            ;;
        *)
            echo "Opzione non valida, riprova."
            ;;
    esac
done
