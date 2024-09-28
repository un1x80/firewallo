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

# Funzione per leggere le variabili dal file
read_variables() {
# Definisce il percorso del file passato per variabile
file_path="$DIRCONF/filter/$1"
CATENA=$1
    if [[ -f "$file_path" ]]; then
        source "$file_path"
    else
        echo "Il file $file_path non esiste. Crealo con le variabili tcpports e udpports."
        exit 1
    fi
}
# Funzione per controllare la validità della porta
validate_port() {
    local port="$1"
    if [[ "$port" == "any" || "$port" =~ ^[0-9]+$ && "$port" -ge 1 && "$port" -le 65535 ]]; then
        return 0
    else
        return 1  # non valido
    fi
}

show_ports() {
    echo -e "\n--- Porte attuali in $CATENA ---"
    color_text "magenta" "TCP: $TCPPORT"
    color_text "cyan" "UDP: $UDPPORT"
    echo "----------------------------------"
}
# Funzione per mostrare il menu all'utente
show_menu_add_remove() {
    echo "Gestione porte TCP/UDP:"
    echo "1) Edita il file a mano"
    echo "2) Aggiungi una porta o un range TCP"
    echo "3) Rimuovi una porta o un range TCP"
    echo "4) Aggiungi una porta o un range UDP"
    echo "5) Rimuovi una porta o un range UDP"
    echo "6) Usa il Wizard per creare una regola complessa"
    echo "7) Esci"
}

update_file() {
    # Modifica le variabili direttamente nel file
    sed -i "s/^TCPPORT=.*/TCPPORT=\"$TCPPORT\"/" "$file_path"
    sed -i "s/^UDPPORT=.*/UDPPORT=\"$UDPPORT\"/" "$file_path"
}
# Funzione per aggiungere una porta o un range
add_port() {
    local protocol=$1
    local ports_var=$2
    local new_port

    read -p "Inserisci la porta o il range da aggiungere ($protocol, es. 80 o 100:200): " new_port
    validate_port "$new_port" 
    if [ "$?" = "0" ] ; then
        # Verifica che la porta o il range non sia già presente
        if [[ ! " ${!ports_var} " =~ " ${new_port} " ]]; then
            eval "$ports_var=\"\${$ports_var} \$new_port\""
            echo "Porta o range $new_port aggiunto con successo a $protocol."
        else
            echo "La porta o il range $new_port è già presente in $protocol."
        fi
    else 
    handle_error "$INVALID_PORT" ; echo "PRESS ENTER ... " ; read ENTER
    fi
}

# Funzione per rimuovere una porta o un range
remove_port() {
    local protocol=$1
    local ports_var_name=$2
    local port_to_remove

    # Ottieni il valore attuale delle porte
    ports_var_value=$(eval echo \$$ports_var_name)

    read -p "Inserisci la porta o il range da rimuovere ($protocol, es. 80 o 100:200): " port_to_remove

    # Verifica se la porta o il range esiste
    if [[ " ${ports_var_value} " =~ " ${port_to_remove} " ]]; then
        # Rimuove la porta o il range e ripulisce gli spazi in eccesso
        ports_var_value=$(echo "$ports_var_value" | sed -e "s/\b$port_to_remove\b//g" -e 's/  */ /g' -e 's/^ *//g' -e 's/ *$//g')

        # Assegna il nuovo valore alla variabile corretta (TCPPORT o UDPPORT)
        if [[ "$protocol" == "TCP" ]]; then
            TCPPORT="$ports_var_value"
        elif [[ "$protocol" == "UDP" ]]; then
            UDPPORT="$ports_var_value"
        fi

        echo "Porta o range $port_to_remove rimosso con successo da $protocol." ; echo "ENTER..." ; read INVIO
    else
        echo "La porta o il range $port_to_remove non è presente in $protocol." ; echo "ENTER..." ; read INVIO
    fi
}



# Funzione principale di gestione delle porte
manage_ports() {

    while true; do
        clear
        cat $DIRCONF/motd #Visualizza il banner motd
        show_ports
        show_menu_add_remove
        read -p "Seleziona un'opzione: " choice

        case $choice in
            1)
                $DIALOG $file_path
                ;;
            2)
                add_port "TCP" "TCPPORT"
                update_file
                ;;
            3)
                remove_port "TCP" "TCPPORT"
                update_file
                ;;
            4)
                add_port "UDP" "UDPPORT"
                update_file
                ;;
            5)
                remove_port "UDP" "UDPPORT"
                update_file
                ;;
            
            6)
                clear
                cat $DIRCONF/motd #Visualizza il banner motd
                echo "AGGIUNGI REGOLA A $CATENA"
                $DIRBIN/wiz/magic_filter.sh $CATENA
                ;;
            7)
                echo "Uscita."
                filter
                ;;
            *)
                echo "Scelta non valida!"
                ;;
        esac
    done
}