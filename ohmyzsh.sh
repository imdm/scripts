#!/bin/bash

#================================================
# Author: Milo
# System Required: CentOS/Debian/Ubuntu
# Description: auto install and config ohmyzsh
# Version: 1.0.0
# github: https://github.com/imdm/scripts
#================================================

Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"

#检查系统
check_sys(){
    if [[ `command -v apt-get` ]];then
        package_manager='apt-get'
    elif [[ `command -v dnf` ]];then
        package_manager='dnf'
    elif [[ `command -v yum` ]];then
        package_manager='yum'
    else
        echo -e "${Red_font_prefix}不支持当前操作系统${Font_color_suffix}" && exit 1
    fi
}

Install_ohmyzsh(){
    echo -e "当前SHELL是:$SHELL"
    echo "安装zsh.."
    ${package_manager} install zsh -y 
    echo "切换SHELL到zsh.." 
    chsh -s /bin/zsh
    echo "安装git.."
    ${package_manager} install git -y
    echo "安装oh-my-zsh.."
    curl https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh | sh
    echo "下载插件.."
    cd ~/.oh-my-zsh/custom/plugins/
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git
    git clone https://github.com/zsh-users/zsh-autosuggestions
    sed -i 's/robbyrussell/ys/g' ~/.zshrc
    sed -i 's/plugins=(git)/plugins=(git last-working-dir vi-mode zsh-autosuggestions zsh-syntax-highlighting)/g' ~/.zshrc
    source ~/.zshrc
    echo "安装成功~~"
}
main(){
    check_sys
    Install_ohmyzsh
}
main