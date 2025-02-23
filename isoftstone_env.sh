#!/bin/bash
new_user=$1
PASSWD=$2、

setup_color() {
    if [ -t 1 ]; then
        RED=$(printf '\033[31m')
        GREEN=$(printf '\033[32m')
        YELLOW=$(printf '\033[33m')
        BLUE=$(printf '\033[34m')
        BOLD=$(printf '\033[1m')
        PINK=$(printf '\033[35m')
        RESET=$(printf '\033[m')
    else
        RED=""
        GREEN=""
        YELLOW=""
        BLUE=""
        BOLD=""
        PINK=""
        RESET=""
    fi
}
setup_color

# 配置vim
echo "开始配置vim\n"> isoftstone_env_log
if [ ! -f "/home/$new_user/install_vim.sh" ]; then
    echo "install_vim.sh 文件不存在" >> isoftstone_env_log
else
    echo "install_vim.sh 文件已存在,删除中" >> isoftstone_env_log
    rm -f /home/$new_user/install_vim.sh*
fi
wget https://gitee.com/zhang-sichen/linux-script/blob/master/install_vim.sh
bash install_vim.sh
echo "配置vim成功\n" >> isoftstone_env_log

# zsh的安装及配置
echo "配置zsh\n" >> isoftstone_env_log
if [ ! -f "/home/$new_user/install_zsh.sh" ]; then
    echo "install_zsh.sh 文件不存在"
else
    echo "install_zsh.sh 文件已存在，已删除"
    rm -f  /home/$new_user/install_zsh.sh*
fi

wget https://gitee.com/zhang-sichen/linux-script/blob/master/install_zsh.sh
bash install_zsh.sh ${PASSWD}

git clone https://gitee.com/song_df/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting 
# 替换文件中的内容
sed -i 's/plugins=(git)/plugins=(git zsh-syntax-highlighting)/' ~/.zshrc
echo "配置zsh成功,内容替换完成">> isoftstone_env_log

#命令自动补全插件
echo "自动补全插件配置\n">> isoftstone_env_log
mkdir ~/.oh-my-zsh/plugins/incr
wget https://gitee.com/zhang-sichen/linux-script/blob/master/incr-0.2.zsh -O ~/.oh-my-zsh/plugins/incr/incr.plugin.zsh
echo "自动补全插件完成\n" >> isoftstone_env_log

##目录自动跳转插件
echo "目录跳转插件配置\n" >> isoftstone_env_log
echo 'autoload -U colors && colors'  >> ~/.zshrc
echo 'PROMPT="%{$fg[red]%}%n%{$reset_color%}@%{$fg[blue]%}%m %{$fg[yellow]%}%1~ %{$reset_color%}%# "' >> ~/.zshrc
echo 'RPROMPT="[%{$fg[yellow]%}%?%{$reset_color%}]"' >> ~/.zshrc
echo '[ -r "/etc/zshrc_$TERM_PROGRAM" ] && . "/etc/zshrc_$TERM_PROGRAM"' >> ~/.zshrc
echo 'source /usr/share/autojump/autojump.sh' >> ~/.zshrc
echo 'source ~/.oh-my-zsh/plugins/incr/incr*.zsh' >> ~/.zshrc
ctags -I __THROW -I __attribute_pure__ -I __nonnull -I __attribute__ --file-scope=yes --langmap=c:+.h --languages=c,c++ --links=yes --c-kinds=+p --c++-kinds=+p --fields=+iaS --extra=+q -R -f ~/.vim/systags /usr/include/ /usr/local/include

echo 'set tags+=~/.vim/systags' >> ~/.vimrc

# 文件直接覆盖
if [[ `uname -m` ==  x86* ]];then
    echo "这个是x86架构"
    wget wiki.haizeix.com/courses_resource/cloud_usage/kkb_check_ubuntu_18.04 -O isoftstone_check
else 
    echo "这个是arm架构"	
    wget wiki.haizeix.com/courses_resource/cloud_usage/kkb_check_ubuntu_18.04_arm -O isoftstone_check
fi
chmod a+x isoftstone_check
sudo mv isoftstone_check /usr/bin

# sudo cd ~
rm isoftstone_env_log
exit


