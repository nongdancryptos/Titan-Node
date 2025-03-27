#!/bin/bash

#################################
# Phần 1: Tự động chạy bên trong screen (nếu chưa)
#################################
if [ -z "$RUNNING_IN_SCREEN" ]; then
    # 1) Kiểm tra & cài screen
    if ! command -v screen &> /dev/null; then
        sudo apt update
        sudo apt install screen -y
    fi

    # 2) Tạo screen "titan" và chạy script trong đó (chế độ nền)
    screen -S titan -dm bash -c "RUNNING_IN_SCREEN=1 $0"

    echo "Đã tạo screen 'titan' và khởi chạy script bên trong."
    echo "Để theo dõi/điều khiển, gõ: screen -r titan"
    exit 0
fi

#################################
# Phần 2: Nếu đã ở trong screen, ta chạy logic chính
#################################

# Màu sắc văn bản
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # Không có màu (đặt lại màu)

# Kiểm tra sự tồn tại của curl và cài đặt nếu chưa có
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
   
________________________________________________________________________________________________________________________________________

Ủng hộ: 0x431588aff8ea1becb1d8188d87195aa95678ba0a                                                                             
                                                                              

EOF
    echo -e "${NC}"
}

# Kiểm tra & cài Docker
install_docker() {
    echo -e "${BLUE}Kiểm tra Docker...${NC}"
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}Docker chưa được cài đặt. Đang cài đặt Docker...${NC}"
        sudo apt update
        sudo apt install docker.io -y
        sudo systemctl start docker
        sudo systemctl enable docker
        echo -e "${GREEN}Docker đã được cài đặt thành công!${NC}"
    else
        echo -e "${GREEN}Docker đã được cài đặt.${NC}"
    fi
}

# Kiểm tra & cài Docker Compose
install_docker_compose() {
    echo -e "${BLUE}Kiểm tra Docker Compose...${NC}"
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${YELLOW}Docker Compose chưa được cài đặt. Đang cài đặt Docker Compose...${NC}"
        sudo curl -L "https://github.com/docker/compose/releases/download/$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)/docker-compose-$(uname -s)-$(uname -m)" \
            -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        echo -e "${GREEN}Docker Compose đã được cài đặt thành công!${NC}"
    else
        echo -e "${GREEN}Docker Compose đã được cài đặt.${NC}"
    fi
}

# Hàm cài đặt node
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
            echo -e "${RED}Lỗi: Cổng $port đã bị chiếm. Chương trình không thể chạy.${NC}"
            exit 1
        fi
    done

    echo -e "${GREEN}Tất cả các cổng đều sẵn sàng! Bắt đầu cài đặt...${NC}\n"

    cd $HOME

    # Cập nhật & cài các gói cần thiết
    echo -e "${BLUE}Cập nhật và cài đặt các gói cần thiết...${NC}"
    sudo apt update -y && sudo apt upgrade -y
    sudo apt-get install nano git gnupg lsb-release apt-transport-https jq screen ca-certificates curl -y

    # Cài Docker
    install_docker
    # Cài Docker Compose
    install_docker_compose

    echo -e "${GREEN}Các phụ thuộc cần thiết đã được cài đặt. Bắt đầu khởi động node...${NC}"

    # Dừng & xóa container cũ (nếu có)
    docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" \
        | shuf -n $(docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | wc -l) \
        | while read container_id; do
            docker stop "$container_id"
            docker rm "$container_id"
        done

    # Nhập HASH
    while true; do
        echo -e "${YELLOW}Nhập HASH của bạn:${NC}"
        read -p "> " HASH
        if [ ! -z "$HASH" ]; then
            break
        fi
        echo -e "${RED}HASH không thể để trống.${NC}"
    done

    # Khởi động container và bind
    docker run --network=host -d -v ~/.titanedge:$HOME/.titanedge nezha123/titan-edge
    sleep 10

    docker run --rm -it -v ~/.titanedge:$HOME/.titanedge nezha123/titan-edge \
        bind --hash=$HASH https://api-test1.container1.titannet.io/api/v2/device/binding

    echo -e "${GREEN}Node đã được cài đặt và khởi động thành công!${NC}"
}

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

    echo -e "${BLUE}Cập nhật sysctl.conf với cấu hình mới...${NC}"
    echo "$CONFIG_VALUES" | sudo tee -a "$SYSCTL_CONF" > /dev/null

    echo -e "${BLUE}Áp dụng cài đặt mới...${NC}"
    sudo sysctl -p

    echo -e "${GREEN}Cài đặt đã được cập nhật thành công.${NC}"

    if command -v setenforce &> /dev/null; then
        echo -e "${BLUE}Tắt SELinux...${NC}"
        sudo setenforce 0
    else
        echo -e "${YELLOW}SELinux chưa được cài đặt.${NC}"
    fi
}

# Cài đặt nhiều node (vd: 5 node)
many_node() {
    # Dừng các container cũ
    docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" \
        | shuf -n $(docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | wc -l) \
        | while read container_id; do
            docker stop "$container_id"
            docker rm "$container_id"
        done

    # Nhập HASH
    echo -e "${YELLOW}Nhập HASH của bạn:${NC}"
    read -p "> " id

    # Cập nhật sysctl
    update_sysctl_config

    storage_gb=50
    start_port=1235
    container_count=5  # Số node muốn cài

    public_ips=$(curl -s https://api.ipify.org)
    if [ -z "$public_ips" ]; then
        echo -e "${RED}Không thể lấy địa chỉ IP.${NC}"
        exit 1
    fi

    # Tải image
    docker pull nezha123/titan-edge

    current_port=$start_port
    for ip in $public_ips; do
        echo -e "${BLUE}Cài đặt node trên IP $ip...${NC}"
        for ((i=1; i<=container_count; i++)); do
            storage_path="$HOME/titan_storage_${ip}_${i}"
            sudo mkdir -p "$storage_path"
            sudo chmod -R 777 "$storage_path"
  
            container_id=$(docker run -d --restart always \
                -v "$storage_path:$HOME/.titanedge/storage" \
                --name "titan_${ip}_${i}" \
                --net=host \
                nezha123/titan-edge)
  
            echo -e "${GREEN}Node titan_${ip}_${i} đã được khởi động với ID container $container_id${NC}"
            sleep 30
  
            docker exec $container_id bash -c "\
                sed -i 's/^[[:space:]]*#StorageGB = .*/StorageGB = $storage_gb/' $HOME/.titanedge/config.toml && \
                sed -i 's/^[[:space:]]*#ListenAddress = \"0.0.0.0:1234\"/ListenAddress = \"0.0.0.0:$current_port\"/' $HOME/.titanedge/config.toml && \
                echo 'Kho lưu trữ titan_${ip}_${i} đã được cài đặt với $storage_gb GB, cổng đã được đặt là $current_port'"

            docker restart $container_id
            docker exec $container_id bash -c "\
                titan-edge bind --hash=$id https://api-test1.container1.titannet.io/api/v2/device/binding"

            echo -e "${GREEN}Node titan_${ip}_${i} đã được cài đặt thành công.${NC}"
            current_port=$((current_port + 1))
        done
    done
    echo -e "${GREEN}Tất cả $container_count node đã được cài đặt thành công!${NC}"
}

docker_logs() {
    echo -e "${BLUE}Kiểm tra nhật ký node...${NC}"
    docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" \
        | shuf -n $(docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | wc -l) \
        | while read container_id; do
            docker logs "$container_id"
        done
    echo -e "${BLUE}Nhật ký đã được hiển thị. Quay lại menu...${NC}"
}

restart_node() {
    echo -e "${BLUE}Khởi động lại node...${NC}"
    docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" \
        | shuf -n $(docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | wc -l) \
        | while read container_id; do
            docker restart "$container_id"
        done
    echo -e "${GREEN}Node đã được khởi động lại thành công!${NC}"
}

stop_node() {
    echo -e "${BLUE}Dừng node...${NC}"
    docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" \
        | shuf -n $(docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | wc -l) \
        | while read container_id; do
            docker stop "$container_id"
        done
    echo -e "${GREEN}Node đã dừng!${NC}"
}

delete_node() {
    echo -e "${YELLOW}Nếu bạn chắc chắn muốn xóa node, hãy nhập một ký tự bất kỳ (CTRL+C để thoát):${NC}"
    read -p "> " checkjust

    echo -e "${BLUE}Đang xóa node...${NC}"
    docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" \
        | shuf -n $(docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | wc -l) \
        | while read container_id; do
            docker stop "$container_id"
            docker rm "$container_id"
        done

    sudo rm -rf $HOME/.titanedge
    sudo rm -rf $HOME/titan_storage_*

    echo -e "${GREEN}Node đã được xóa thành công!${NC}"
}

exit_from_script() {
    echo -e "${BLUE}Thoát khỏi script...${NC}"
    exit 0
}

main_menu() {
    while true; do
        channel_logo
        sleep 2
        echo -e "\n\n${YELLOW}Chọn hành động:${NC}"
        echo -e "${CYAN}1. Cài đặt và khởi động node${NC}"
        echo -e "${CYAN}2. Kiểm tra nhật ký${NC}"
        echo -e "${CYAN}3. Cài đặt 5 node${NC}"
        echo -e "${CYAN}4. Khởi động lại node${NC}"
        echo -e "${CYAN}5. Dừng node${NC}"
        echo -e "${CYAN}6. Xóa node${NC}"
        echo -e "${CYAN}7. Thoát${NC}"
        
        echo -en "${YELLOW}Nhập số lựa chọn:${NC} "
        read choice
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

###################
# Gọi menu chính
###################
main_menu
