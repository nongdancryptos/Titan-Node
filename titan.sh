#!/bin/bash

###############################################
# (0) CÀI FONT & LOCALE (UTF-8) NGAY TỪ ĐẦU
###############################################
echo -e "\nĐang cài font và thiết lập locale UTF-8..."
sudo apt-get update -y

# Cài gói font (bao gồm DejaVu, Liberation, Noto, font console v.v.)
sudo apt-get install -y fonts-dejavu fonts-liberation fonts-noto-cjk \
                       console-setup console-terminus locales

# Chạy dpkg-reconfigure để đảm bảo locale có UTF-8
sudo dpkg-reconfigure locales

# Thiết lập tạm thời biến môi trường (ví dụ en_US.UTF-8)
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

echo "Đã cài font và cấu hình locale xong. Bắt đầu phần code chính..."

##############################################################################
# (1) TỰ ĐỘNG CHẠY TRONG SCREEN “titan” + KIỂM TRA NẾU ĐÃ TỒN TẠI THÌ VÀO LUÔN
##############################################################################
if [ -z "$RUNNING_IN_SCREEN" ]; then
    # Kiểm tra screen, nếu chưa có thì cài
    if ! command -v screen &> /dev/null; then
        sudo apt update
        sudo apt install screen -y
    fi

    # Kiểm tra xem screen “titan” đã tồn tại chưa
    if screen -ls | grep -w "titan" &> /dev/null; then
        echo "Screen 'titan' đã tồn tại. Gắn vào screen cũ..."
        screen -r titan
        exit 0
    else
        echo "Chưa có screen 'titan'. Tạo screen 'titan'..."
        # Tạo screen “titan” ở chế độ nền (-dm), set biến RUNNING_IN_SCREEN=1
        screen -S titan -dm bash -c "RUNNING_IN_SCREEN=1 $0"

        # Đợi 1-2 giây cho script bên trong screen khởi chạy
        sleep 1

        # Tự động attach vào screen "titan"
        screen -r titan
        exit 0
    fi
fi

################################################################################
# (2) PHẦN CODE CHÍNH: CHỈ CHẠY KHI ĐANG Ở BÊN TRONG SCREEN (RUNNING_IN_SCREEN=1)
################################################################################

# Màu sắc
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Kiểm tra curl
if ! command -v curl &> /dev/null; then
    sudo apt update
    sudo apt install curl -y
fi

# Logo
channel_logo() {
    echo -e "${GREEN}"
    cat << "EOF"
████████ ██ ████████  █████  ███    ██     ███    ██  ██████  ██████  ███████ 
   ██    ██    ██    ██   ██ ████   ██     ████   ██ ██    ██ ██   ██ ██      
   ██    ██    ██    ███████ ██ ██  ██     ██ ██  ██ ██    ██ ██   ██ █████   
   ██    ██    ██    ██   ██ ██  ██ ██     ██  ██ ██ ██    ██ ██   ██ ██      
   ██    ██    ██    ██   ██ ██   ████     ██   ████  ██████  ██████  ███████ 
   
_____________________________________________________________________________________________________

Ủng hộ: 0x431588aff8ea1becb1d8188d87195aa95678ba0a                                                                             
                                                                              

EOF
    echo -e "${NC}"
}

###############################################################################
# (A) Kiểm tra & cài Docker
###############################################################################
install_docker() {
    echo -e "${BLUE}Kiểm tra Docker...${NC}"
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}Docker chưa được cài đặt. Đang cài Docker...${NC}"
        sudo apt update
        sudo apt install docker.io -y
        sudo systemctl start docker
        sudo systemctl enable docker
        echo -e "${GREEN}Docker đã được cài đặt!${NC}"
    else
        echo -e "${GREEN}Docker đã được cài đặt.${NC}"
    fi
}

###############################################################################
# (B) Kiểm tra & cài Docker Compose
###############################################################################
install_docker_compose() {
    echo -e "${BLUE}Kiểm tra Docker Compose...${NC}"
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${YELLOW}Docker Compose chưa có. Đang cài...${NC}"
        sudo curl -L "https://github.com/docker/compose/releases/download/$( \
            curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name \
        )/docker-compose-$(uname -s)-$(uname -m)" \
            -o /usr/local/bin/docker-compose

        sudo chmod +x /usr/local/bin/docker-compose
        echo -e "${GREEN}Docker Compose đã được cài đặt!${NC}"
    else
        echo -e "${GREEN}Docker Compose đã được cài đặt.${NC}"
    fi
}

###############################################################################
# (C) CÀI ĐẶT TITAN NODE
###############################################################################
download_node() {
    echo -e "${BLUE}Bắt đầu cài đặt node...${NC}"

    # Kiểm tra thư mục .titanedge
    if [ -d "$HOME/.titanedge" ]; then
        echo -e "${RED}Thư mục .titanedge đã tồn tại. Vui lòng xóa node và cài đặt lại. Thoát...${NC}"
        return 0
    fi

    # Cài đặt lsof để kiểm tra cổng
    sudo apt install lsof -y

    # Kiểm tra các cổng
    ports=(1234 55702 48710)
    for port in "${ports[@]}"; do
        if [[ $(lsof -i :"$port" | wc -l) -gt 0 ]]; then
            echo -e "${RED}Cổng $port đã bị chiếm. Thoát...${NC}"
            exit 1
        fi
    done

    echo -e "${GREEN}Các cổng đều sẵn sàng! Bắt đầu cài đặt...${NC}\n"

    cd $HOME

    # Cập nhật & cài các gói cần thiết
    echo -e "${BLUE}Cập nhật, nâng cấp gói...${NC}"
    sudo apt update -y && sudo apt upgrade -y
    sudo apt-get install nano git gnupg lsb-release apt-transport-https jq screen ca-certificates curl -y

    # Cài Docker & Docker Compose
    install_docker
    install_docker_compose

    echo -e "${GREEN}Hoàn thành cài phụ thuộc. Bắt đầu khởi động node...${NC}"

    # Dừng & xóa container cũ (nếu có)
    docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" \
        | shuf -n $(docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | wc -l) \
        | while read container_id; do
            docker stop "$container_id"
            docker rm "$container_id"
        done

    # Yêu cầu HASH
    while true; do
        echo -en "${YELLOW}Nhập HASH của bạn: ${NC}"
        read -r HASH
        if [ -n "$HASH" ]; then
            break
        fi
        echo -e "${RED}HASH không được trống.${NC}"
    done

    # Khởi động container & bind
    docker run --network=host -d -v ~/.titanedge:$HOME/.titanedge nezha123/titan-edge
    sleep 10

    docker run --rm -it -v ~/.titanedge:$HOME/.titanedge nezha123/titan-edge \
        bind --hash=$HASH https://api-test1.container1.titannet.io/api/v2/device/binding

    echo -e "${GREEN}Node đã cài và khởi động thành công!${NC}"
}

###############################################################################
# (D) UPDATE SYSCTL
###############################################################################
update_sysctl_config() {
    local CONFIG_VALUES="
net.core.rmem_max=26214400
net.core.rmem_default=26214400
net.core.wmem_max=26214400
net.core.wmem_default=26214400
"
    local SYSCTL_CONF="/etc/sysctl.conf"

    echo -e "${BLUE}Tạo bản sao lưu sysctl.conf.bak...${NC}"
    sudo cp "$SYSCTL_CONF" "$SYSCTL_CONF.bak"

    echo -e "${BLUE}Ghi các giá trị cấu hình mới...${NC}"
    echo "$CONFIG_VALUES" | sudo tee -a "$SYSCTL_CONF" > /dev/null

    echo -e "${BLUE}Áp dụng cài đặt sysctl...${NC}"
    sudo sysctl -p

    echo -e "${GREEN}Cài đặt sysctl đã được cập nhật!${NC}"

    # Tắt SELinux nếu có
    if command -v setenforce &> /dev/null; then
        echo -e "${BLUE}Tắt SELinux...${NC}"
        sudo setenforce 0
    else
        echo -e "${YELLOW}SELinux chưa được cài / không tồn tại.${NC}"
    fi
}

###############################################################################
# (E) CÀI NHIỀU NODE (5 NODE)
###############################################################################
many_node() {
    # Dừng container cũ
    docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" \
        | shuf -n $(docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | wc -l) \
        | while read container_id; do
            docker stop "$container_id"
            docker rm "$container_id"
        done

    echo -en "${YELLOW}Nhập HASH của bạn: ${NC}"
    read -r id

    # Cập nhật sysctl
    update_sysctl_config

    storage_gb=50
    start_port=1235
    container_count=5  # Số node muốn cài

    public_ips=$(curl -s https://api.ipify.org)
    if [ -z "$public_ips" ]; then
        echo -e "${RED}Không lấy được địa chỉ IP.${NC}"
        exit 1
    fi

    # Kéo image
    docker pull nezha123/titan-edge

    current_port=$start_port
    for ip in $public_ips; do
        echo -e "${BLUE}Cài node trên IP $ip...${NC}"

        for ((i=1; i<=container_count; i++)); do
            storage_path="$HOME/titan_storage_${ip}_${i}"
            sudo mkdir -p "$storage_path"
            sudo chmod -R 777 "$storage_path"

            container_id=$(
                docker run -d \
                    --restart always \
                    -v "$storage_path:$HOME/.titanedge/storage" \
                    --name "titan_${ip}_${i}" \
                    --net=host \
                    nezha123/titan-edge
            )

            echo -e "${GREEN}Node titan_${ip}_${i} khởi động, ID container: $container_id${NC}"
            sleep 30

            docker exec $container_id bash -c "\
                sed -i 's/^[[:space:]]*#StorageGB = .*/StorageGB = $storage_gb/' $HOME/.titanedge/config.toml && \
                sed -i 's/^[[:space:]]*#ListenAddress = \"0.0.0.0:1234\"/ListenAddress = \"0.0.0.0:$current_port\"/' $HOME/.titanedge/config.toml && \
                echo 'Kho lưu trữ titan_${ip}_${i} đã cài $storage_gb GB, cổng $current_port'"

            docker restart $container_id

            # Bind
            docker exec $container_id bash -c "\
                titan-edge bind --hash=$id https://api-test1.container1.titannet.io/api/v2/device/binding"

            echo -e "${GREEN}Node titan_${ip}_${i} cài thành công.${NC}"
            current_port=$((current_port+1))
        done
    done

    echo -e "${GREEN}Đã cài thành công $container_count node!${NC}"
}

###############################################################################
# (F) XEM LOGS
###############################################################################
docker_logs() {
    echo -e "${BLUE}Xem nhật ký...${NC}"
    docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" \
        | shuf -n $(docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | wc -l) \
        | while read container_id; do
            docker logs "$container_id"
        done
    echo -e "${BLUE}Đã hiển thị xong nhật ký!${NC}"
}

###############################################################################
# (G) KHỞI ĐỘNG LẠI NODE
###############################################################################
restart_node() {
    echo -e "${BLUE}Khởi động lại node...${NC}"
    docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" \
        | shuf -n $(docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | wc -l) \
        | while read container_id; do
            docker restart "$container_id"
        done
    echo -e "${GREEN}Node đã khởi động lại xong!${NC}"
}

###############################################################################
# (H) DỪNG NODE
###############################################################################
stop_node() {
    echo -e "${BLUE}Dừng node...${NC}"
    docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" \
        | shuf -n $(docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | wc -l) \
        | while read container_id; do
            docker stop "$container_id"
        done
    echo -e "${GREEN}Node đã dừng!${NC}"
}

###############################################################################
# (I) XOÁ NODE
###############################################################################
delete_node() {
    echo -en "${YELLOW}Xác nhận xóa node (nhập ký tự bất kỳ, Ctrl+C để hủy): ${NC}"
    read -r sure

    echo -e "${BLUE}Xóa node...${NC}"
    docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" \
        | shuf -n $(docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | wc -l) \
        | while read container_id; do
            docker stop "$container_id"
            docker rm "$container_id"
        done

    sudo rm -rf $HOME/.titanedge
    sudo rm -rf $HOME/titan_storage_*

    echo -e "${GREEN}Node đã xóa hoàn toàn!${NC}"
}

###############################################################################
# (J) THOÁT SCRIPT
###############################################################################
exit_from_script() {
    echo -e "${BLUE}Thoát script...${NC}"
    exit 0
}

###############################################################################
# (K) MENU CHÍNH
###############################################################################
main_menu() {
    while true; do
        channel_logo
        sleep 2
        echo -e "\n${YELLOW}Chọn hành động:${NC}"
        echo -e "${CYAN}1. Cài đặt và khởi động node${NC}"
        echo -e "${CYAN}2. Kiểm tra nhật ký (docker logs)${NC}"
        echo -e "${CYAN}3. Cài đặt 5 node (multi-node)${NC}"
        echo -e "${CYAN}4. Khởi động lại node${NC}"
        echo -e "${CYAN}5. Dừng node${NC}"
        echo -e "${CYAN}6. Xóa node${NC}"
        echo -e "${CYAN}7. Thoát${NC}"
        
        echo -en "${YELLOW}Nhập số (1-7): ${NC}"
        read -r choice
        case $choice in
            1) download_node ;;
            2) docker_logs ;;
            3) many_node ;;
            4) restart_node ;;
            5) stop_node ;;
            6) delete_node ;;
            7) exit_from_script ;;
            *) echo -e "${RED}Lựa chọn không hợp lệ, vui lòng thử lại.${NC}" ;;
        esac
    done
}

###############################################################################
# (L) GỌI HÀM MAIN_MENU - MENU CHÍNH
###############################################################################
main_menu

# Giữ session lại trong screen để không bị đóng
exec bash
