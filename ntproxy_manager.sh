#!/bin/bash

# Definindo cores
vermelha='\033[1;31m'
verde='\033[1;32m'
amarelo='\033[1;33m'
azul='\033[1;34m'
rosa='\033[1;35m'
cinza='\033[1;36m'
sem_cor='\033[0m'

prompt() {
    echo -e "${amarelo}$1${sem_cor}"
}

pause_prompt() {
    read -rp "$(prompt 'Enter para continuar...')" voidResponse
}

restart_ntproxy() {
    while true; do
        read -rp "$(prompt 'Porta: ')" PORT

        if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
            echo -e "${vermelha}Porta inválida.${sem_cor}"
        elif [ "$PORT" -le 0 ] || [ "$PORT" -gt 65535 ]; then
            echo -e "${vermelha}Porta fora do intervalo permitido.${sem_cor}"
        else
            break
        fi
    done
    local service_name="ntproxy-$PORT"
    if ! systemctl is-active "$service_name" >/dev/null; then
        echo -e "${vermelha}Proxy na porta${sem_cor} ${azul}$PORT${sem_cor} ${vermelha}não está ativo.${sem_cor}"
        pause_prompt
        return
    fi

    systemctl restart "$service_name"

    echo -e "${verde}Proxy na porta${sem_cor} ${azul}$PORT${sem_cor} ${verde}reiniciado.${sem_cor}"
    pause_prompt
}

show_ntproxy() {
    echo -e "\n${verde}----- Serviços em Execução -----${sem_cor}\n"
    for service in $(systemctl list-units --type=service --state=running | grep ntproxy- | awk '{print $1}'); do
        service_name=$(basename "$service" .service)
        porta=$(echo "$service_name" | cut -d '-' -f 2)
        estado_ativo=$(systemctl show -p ActiveState --value $service | sed 's/active/Ativo/g')
        estado_subestado=$(systemctl show -p SubState --value $service | sed 's/running/executando/g')
        
        # Colorir o estado
        if [ "$estado_ativo" == "Ativo" ]; then
            estado_ativo="${verde}$estado_ativo${sem_cor}"
        else
            estado_ativo="${vermelha}$estado_ativo${sem_cor}"
        fi

        if [ "$estado_subestado" == "executando" ]; then
            estado_subestado="${verde}$estado_subestado${sem_cor}"
        else
            estado_subestado="${vermelha}$estado_subestado${sem_cor}"
        fi

        # Imprimir o estado
        echo -e "Estado: $estado_ativo e $estado_subestado, na porta ${azul}$porta${sem_cor}"
    done
    pause_prompt
}

show_ports_in_use() {
    local ports_in_use=$(systemctl list-units --all --plain --no-legend | grep -oE 'ntproxy-[0-9]+' | cut -d'-' -f2)
    if [ -n "$ports_in_use" ]; then
        ports_in_use=$(echo "$ports_in_use" | tr '\n' ' ')
        echo -e "${azul}║${verde}Em uso:${amarelo} $(printf '%-21s' "$ports_in_use")${azul}║${sem_cor}"
        echo -e "${azul}║═════════════════════════════║${sem_cor}"
    fi
}

configure_and_start_service() {
    while true; do
        read -rp "$(prompt 'Porta: ')" PORT
        PT=$(lsof -V -i tcp -P -n | grep -v "ESTABLISHED" | grep -v "COMMAND" | grep "LISTEN")

        porta_em_uso=false
        for pton in $(echo -e "$PT" | cut -d: -f2 | cut -d' ' -f1 | uniq); do
            svcs=$(echo -e "$PT" | grep -w "$pton" | awk '{print $1}' | uniq)
            if [[ "$PORT" == "$pton" ]]; then
                porta_em_uso=true
            fi
        done

        if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
            echo -e "${vermelha}Porta inválida.${sem_cor}"
        elif [ "$PORT" -le 0 ] || [ "$PORT" -gt 65535 ]; then
            echo -e "${vermelha}Porta fora do intervalo permitido.${sem_cor}"
        elif [ "$porta_em_uso" = true ]; then
            echo -e "${vermelha}PORTA ${azul}$PORT ${vermelha}EM USO PELO ${verde}$svcs${sem_cor}"
        else
            break
        fi
    done

    
    OPTIONS="/opt/NTProxy/ntproxy.py $PORT"

    SERVICE_FILE="/etc/systemd/system/ntproxy-$PORT.service"
    {
        echo "[Unit]"
        echo "Description=NTProxy Service on Port $PORT"
        echo "After=network.target"
        echo ""
        echo "[Service]"
        echo "LimitNOFILE=infinity"
		echo "LimitNPROC=infinity"
		echo "LimitMEMLOCK=infinity"
		echo "LimitSTACK=infinity"
        echo "LimitCORE=0"
		echo "LimitAS=infinity"
		echo "LimitRSS=infinity"
		echo "LimitCPU=infinity"
		echo "LimitFSIZE=infinity"
        echo "Type=simple"
        echo "ExecStart=$OPTIONS"
        echo "Restart=always"
        echo ""
        echo "[Install]"
        echo "WantedBy=multi-user.target"
    } > "$SERVICE_FILE"
    
    chmod +x "$SERVICE_FILE"
    systemctl enable "ntproxy-$PORT.service" > /dev/null 2>&1
    systemctl start "ntproxy-$PORT.service" > /dev/null 2>&1
    systemctl daemon-reload

    echo -e "${verde}Proxy iniciado na porta${sem_cor} ${azul}$PORT${sem_cor}${verde}.${sem_cor}"
    pause_prompt
}

stop_and_remove_service() {
    while true; do
        read -rp "$(prompt 'Porta: ')" PORT

        if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
            echo -e "${vermelha}Porta inválida.${sem_cor}"
        elif [ "$PORT" -le 0 ] || [ "$PORT" -gt 65535 ]; then
            echo -e "${vermelha}Porta fora do intervalo permitido.${sem_cor}"
        else
            break
        fi
    done
    local service_name="ntproxy-$PORT"
    systemctl stop "$service_name" > /dev/null 2>&1
    systemctl disable "$service_name" > /dev/null 2>&1
    systemctl daemon-reload
    rm "/etc/systemd/system/$service_name.service" > /dev/null 2>&1

    echo -e "${verde}Proxy na porta${sem_cor} ${azul}$PORT${sem_cor} ${verde}parado e removido.${sem_cor}"
    pause_prompt
}

exit_ntproxy_menu() {
    echo -e "${vermelha}Saindo...${sem_cor}"
	sleep 1
    exit 0
}

menu_main() {
    clear

    echo -e "${azul}╔═════════════════════════════╗\033[0m"
    echo -e "${azul}║\033[1;41m${verde}      NTunnel Proxy Menu     \033[0m${azul}║"
    echo -e "${azul}║═════════════════════════════║\033[0m"

    show_ports_in_use

    local option
    echo -e "${azul}║${cinza}[${verde}01${cinza}] ${verde}• \033[1;31mABRIR PORTA           ${azul}║"
    echo -e "${azul}║${cinza}[${verde}02${cinza}] ${verde}• \033[1;31mFECHAR PORTA          ${azul}║"
    echo -e "${azul}║${cinza}[${verde}03${cinza}] ${verde}• \033[1;31mREINICIAR PORTA       ${azul}║"
    echo -e "${azul}║${cinza}[${verde}04${cinza}] ${verde}• \033[1;31mMONITOR               ${azul}║"
    echo -e "${azul}║${cinza}[${verde}00${cinza}] ${verde}• \033[1;31mSAIR                  ${azul}║"
    echo -e "${azul}╚═════════════════════════════╝\033[0m"
    read -rp "$(prompt 'Escolha uma opção: ')" option

    case "$option" in
        1) configure_and_start_service ;;
        2) stop_and_remove_service ;;
        3) restart_ntproxy ;;
        4) show_ntproxy ;;
        0) exit_ntproxy_menu ;;
        *) echo -e "\033[1;31mOpção inválida.\033[0m" ; pause_prompt ;;
    esac

    menu_main
}
menu_main
