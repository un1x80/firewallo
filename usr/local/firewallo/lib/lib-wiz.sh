#!/bin/bash

DIRCONF="/etc/firewallo"
source $DIRCONF/firewallo.conf
color_text() {
    local color="$1"
    local text="$2"

    # Mappa dei colori
    case "$color" in
        black) color_code="30" ;;
        red) color_code="31" ;;
        green) color_code="32" ;;
        yellow) color_code="33" ;;
        blue) color_code="34" ;;
        magenta) color_code="35" ;;
        cyan) color_code="36" ;;
        white) color_code="37" ;;
        *) color_code="37" ;; # Default to white if color not found
    esac

    # Restituisce la stringa colorata con reset alla fine
    echo -e "\e[${color_code}m${text}\e[0m"
}


# Carica il file di traduzione
load_translations() {
    local lang_file="$DIRCONF/lang/firewallo.lang.$LANG"
    if [[ -f "$lang_file" ]]; then
        source "$lang_file"
    else
        echo "LANG_NOT_FOUND"
        exit 1
    fi
};load_translations
#Infatti carico subito le traduzioni


handle_error() {
    echo "$1" 1>&2
    color_text "red" "$INVALID_SELECTION_MSG"
}


# Funzione per visualizzare le catene disponibili e permettere la selezione
select_chain() {
    echo "$SELECT_CHAIN_PROMPT"
    CHAINS=(
        fw2fw	fw2lan	    fw2wan	    fw2vpns	    fw2dmz      \
        lan2fw	lan2lan	    lan2wan	    lan2vpns	lan2dmz     \
        wan2fw	wan2lan	    wan2wan	    wan2vpns	wan2dmz     \
        vpns2fw	vpns2lan	vpns2wan	vpns2vpns	vpns2dmz    \
        dmz2fw	dmz2lan	    dmz2wan	    dmz2vpns	dmz2dmz     \
        exit
    )

    # Mostra le catene all'utente
    select chain in "${CHAINS[@]}"; do
        if [[ " ${CHAINS[@]} " =~ " $chain " ]]; then
            echo "$(printf "$CHAIN_SELECTED_MSG" "$chain")"
            CHAIN_SELECTED=$chain
            if [ "$chain" = "exit" ] ; then
                exit    
            else
                break
            fi
        else
            echo "$INVALID_SELECTION_MSG"
        fi
    done
}



# Funzione per controllare la validità del protocollo
validate_protocol() {
    local protocol="$1"
    if [[ "$protocol" == "tcp" || "$protocol" == "udp" ]]; then
        return 0
    else
        return 1
    fi
}

# Funzione per controllare la validità della porta
validate_port() {
    local port="$1"
    # Condizioni per uscire con "Exit", "exit", "Quit" o "quit"
    if [[ "$port" == "Exit" || "$port" == "exit" || "$port" == "Quit" || "$port" == "quit" ]]; then
        exit 1  # Uscita richiesta
    fi
    
    if [[ "$port" == "any" || "$port" =~ ^[0-9]+$ && "$port" -ge 1 && "$port" -le 65535 ]]; then
        return 0
    else
        handle_error "$INVALID_PORT"
        return 1  # non valido
    fi
}


# Funzione per validare l'interfaccia di rete
validate_if() {
    local if="$1"
        # Condizioni per uscire con "Exit", "exit", "Quit" o "quit"
    if [[ "$if" == "Exit" || "$if" == "exit" || "$if" == "Quit" || "$if" == "quit" ]]; then
        exit 1  # Uscita richiesta
    fi
    if [[ "$if" =~ ^[a-zA-Z0-9]+$ ]]; then
        return 0  # valido
    else
        handle_error "$INVALID_SELECTION_MSG"
        return 1  # non valido
    fi
}

# Funzione per adattare i valori 'any' e 'range' per iptables
parse_port_range_ipt() {
    local port_range="$1"
    if [[ "$port_range" == "any" ]]; then
        echo "1:65535"
    elif [[ "$port_range" =~ ^([0-9]+):([0-9]+)$ ]]; then
        echo "$port_range"
    else
        echo "$port_range"
    fi
}

# Funzione per adattare i valori 'any' e 'range' per nftables
parse_port_range_nft() {
    local port_range="$1"
    if [[ "$port_range" == "any" ]]; then
        echo "1-65535"
    elif [[ "$port_range" =~ ^([0-9]+):([0-9]+)$ ]]; then
        echo "$port_range"
    else
        echo "$port_range"
    fi
}

# Funzione per tradurre le azioni in nftables
translate_action() {
    case "$1" in
        ACCEPT)
            echo "counter accept"
            ;;
        DROP)
            echo "counter drop"
            ;;
        REJECT)
            echo "counter reject"
            ;;
        *)
            echo "Invalid action"
            exit 1
            ;;
    esac
}
#Funzione che valida l'ip con mashera
validate_ip_mask() {
    local ip_mask="$1"
        # Condizioni per uscire con "Exit", "exit", "Quit" o "quit"
    if [[ "$ip_mask" == "Exit" || "$ip_mask" == "exit" || "$ip_mask" == "Quit" || "$ip_mask" == "quit" ]]; then
        exit 1  # Uscita richiesta
    fi
    # Regex per IP validi (0-255) e maschera di rete valida (0-32)
    if [[ "$ip_mask" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[12][0-9]|3[0-2])$ ]]; then
        local ip="${ip_mask%/*}"
        local mask="${ip_mask#*/}"

        # Verifica che ogni ottetto dell'indirizzo IP sia compreso tra 0 e 255
        IFS='.' read -r -a octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if ((octet < 0 || octet > 255)); then
                handle_error "$INVALID_SADDR"
                return 1  # non valido
            fi
        done

        return 0  # valido
    else
        handle_error "$INVALID_SADDR"
        return 1  # non valido
    fi
}

#Funzione che valida l'ip senza maschera
validate_ip() {
    local ip="$1"
            # Condizioni per uscire con "Exit", "exit", "Quit" o "quit"
    if [[ "$ip" == "Exit" || "$ip" == "exit" || "$ip" == "Quit" || "$ip" == "quit" ]]; then
        exit 1 # Uscita richiesta
    fi
    # Verifica se l'indirizzo IP corrisponde al formato IPv4 senza maschera
    if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        # Estrai i singoli byte dell'IP
       IFS='.' read -r -a octets <<< "$ip"
        
        # Controlla che ogni byte sia compreso tra 0 e 255
        for octet in "${octets[@]}"; do
            if ((octet < 0 || octet > 255)); then
                handle_error "$INVALID_ADDR"
                return 1  # Non valido
            fi
        done
        return 0  # Valido
    else
        handle_error "$INVALID_ADDR"
        return 1  # Non valido
    fi
}
# Funzione per controllare la validità dell'indirizzo IP
#validate_ip() {
#    local ip="$1"
#    if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?$ ]]; then
#        return 0
#    else
#        return 1
#    fi
#}
# Funzione per validare la porta anche vuota null
validate_port_null() {
    local port="$1"
            # Condizioni per uscire con "Exit", "exit", "Quit" o "quit"
    if [[ "$port" == "Exit" || "$port" == "exit" || "$port" == "Quit" || "$port" == "quit" ]]; then
        exit 1  # Uscita richiesta
    fi
    if [[ "$port" =~ ^[0-9]+$ ]] || [[ "$port" == "any" ]] || [[ -z "$port" ]]; then
        return 0  # valido
    else
        handle_error "$INVALID_DPORT"
        return 1  # non valido
    fi
}

