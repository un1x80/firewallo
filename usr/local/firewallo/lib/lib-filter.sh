#!/bin/bash

DIRCONF="/etc/firewallo"
source $DIRCONF/firewallo.conf

# Funzione per leggere le variabili dal file
read_variables() {
# Definisce il percorso del file passato per variabile
file_path="$DIRCONF/filter/$1"
    if [[ -f "$file_path" ]]; then
        source "$file_path"
    else
        echo "Il file $file_path non esiste. Crealo con le variabili tcpports e udpports."
        exit 1
    fi
}
show_ports() {
    echo -e "\n--- Porte attuali in $1---"
    echo "TCP: $TCPPORT"
    echo "UDP: $UDPPORT"
    echo "---------------------"
}
# Funzione per mostrare il menu all'utente
show_menu_add_remove() {
    echo "Gestione porte TCP/UDP:"
    echo "1) Edita il file a mano"
    echo "2) Aggiungi una porta o un range TCP"
    echo "3) Rimuovi una porta o un range TCP"
    echo "4) Aggiungi una porta o un range UDP"
    echo "5) Rimuovi una porta o un range UDP"
    echo "6) Esci"
}

# Funzione per aggiornare il file
#update_file() {
#    echo "TCPPORT=\"$TCPPORT\"" > "$file_path"
#    echo "UDPPORT=\"$UDPPORT\"" >> "$file_path"
#}
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

    # Verifica che la porta o il range non sia già presente
    if [[ ! " ${!ports_var} " =~ " ${new_port} " ]]; then
        eval "$ports_var=\"\${$ports_var} \$new_port\""
        echo "Porta o range $new_port aggiunto con successo a $protocol."
    else
        echo "La porta o il range $new_port è già presente in $protocol."
    fi
}

# Funzione per rimuovere una porta o un range
remove_port() {
    local protocol=$1
    local ports_var=$2
    local port_to_remove

    read -p "Inserisci la porta o il range da rimuovere ($protocol, es. 80 o 100:200): " port_to_remove

    # Verifica se la porta o il range esiste
    if [[ " ${!ports_var} " =~ " ${port_to_remove} " ]]; then
        eval "$ports_var=\"\$(echo \${$ports_var} | sed 's/\b$port_to_remove\b//g' | xargs)\""
        echo "Porta o range $port_to_remove rimosso con successo da $protocol."
    else
        echo "La porta o il range $port_to_remove non è presente in $protocol."
    fi
}

# Funzione principale di gestione delle porte
manage_ports() {

    while true; do
        clear
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
                remove_port "TCP" "UDPPORT"
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
                echo "Uscita."
                filter
                ;;
            *)
                echo "Scelta non valida!"
                ;;
        esac
    done
}