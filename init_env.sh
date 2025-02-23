#!/bin/bash

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

username=`whoami`
if [[ ! ${username} == "root" ]];then
    echo "${RED}请使用root用户执行该脚本${RESET}"
    exit
fi

# 确保客户端的活性
n=`sudo grep -n "ClientAliveInterval " /etc/ssh/sshd_config | awk -F':' '{print $1}'`
TMPn='ClientAliveInterval 60'
m=`sudo grep -n "ClientAliveCountMax " /etc/ssh/sshd_config | awk -F':' '{print $1}'`
TMPm='ClientAliveCountMax 3'
sudo sed -i "$[ n ]c $TMPn" /etc/ssh/sshd_config
sudo sed -i "$[ m ]c $TMPm" /etc/ssh/sshd_config

# 更新软件源信息
echo "即将更新软件源信息"
apt update
echo "即将安装依赖软件"
apt install -y git zsh gcc g++ glibc-doc autojump universal-ctags
echo "即将下载环境配置脚本"
wget https://gitee.com/zhang-sichen/linux-script/blob/master/isoftstone_env.sh

regex="^[a-zA-Z]+$"
while [[ 1 ]];do
    echo -e " _______ _______ _______ _______ ______ _______ _____\n\
|   |   |__     |     __|     __|   __ \       |      \ \n\
|       |     __|__     |__     |   __ <   -  _|  --  |\n\
|__|_|__|_______|_______|_______|______/_______|_____/"
    echo "欢迎使用云主机配置脚本"
    echo "作者: ${PINK}mzssbqd${RESET}"
    echo "邮箱: ${PINK}mzssbqd@gmail.com${RESET}"
    read -p "请为你的主机设置一个${RED}主机名字${RESET}(${YELLOW}纯英文${RESET}) :" host_name
    if [[ ! ${host_name} =~ ${regex} ]];then
        echo "${RED}您的主机名不符合规则，请重新输入${RESET}"
        continue
    else
        break
    fi
done
# 设置主机名
hostnamectl set-hostname ${host_name}
# 获取主机的IP地址
host_ip=`ifconfig eth0 |grep inet|grep -v 127.0.0.1|grep -v inet6|awk '{print $2}'|tr -d "addr:"`
#echo $host_ip
host_isoftstone_xiaokai=`grep -n "$host_ip" /etc/hosts | head -1 | awk -F':' '{print $1}'`
host_isoftstone_xiaokai=${host_isoftstone_xiaokai[0]}
# 更新 /etc/hosts 文件
if [ ! -n "$host_isoftstone_xiaokai" ]; then
    echo "$host_ip	${host_name}	${host_name}" >> /etc/hosts
else 
    host_isoftstone_xiaokai_TMP="$host_ip	${host_name}	${host_name}"
    #bool_isoftstone_xiaokai=`sudo grep -n '%sudo	ALL=(ALL:ALL) ALL' /etc/sudoers | awk -F':' '{print $1}'`
    sed -i "$[ host_isoftstone_xiaokai ]c $host_isoftstone_xiaokai_TMP" /etc/hosts
fi

# 循环直到用户输入有效的用户名
while [[ 1 ]];do
    read -p "请输入你的${RED}用户名${RESET}（${YELLOW}必须英文${RESET}） :" username
    if [[ ! ${username} =~ ${regex} ]];then
        echo "${RED}您的用户名不符合规则，请重新输入${RESET}"
        continue
    else
        break
    fi
done

# 循环直到用户确认密码
while [[ 1 ]];do
    read -p "请为用户${BLUE}${username}${RESET}设置一个${RED}密码${RESET} :" USER_PASSWD
    read -p "请再次输入${RED}密码${RESET}:" USER_PASSWD1
    if [[ ${USER_PASSWD} != ${USER_PASSWD1} ]];then
        echo "两次的密码不一致,请重新输入密码!"
        continue
    fi
    read -p "你的密码为${GREEN}${USER_PASSWD}${RESET},请输入${YELLOW}y${RESET}确认,其他任何字符将重新设置密码 [y/n]:" in_tmp
    if [[ ${in_tmp} == 'y' ]];then
        break
    else
        continue
    fi
done

# 创建新用户并设置密码
useradd  ${username} -G sudo -m && echo "Add user successfully" ||( userdel -rf ${username}; echo "User del ${username}" && useradd ${username} -G sudo -m  && echo "Add user successfully")

sleep 1
(
    sleep 1
    echo ${USER_PASSWD}
    sleep 1
    echo ${USER_PASSWD}
)|passwd ${username}

# 检查密码是否设置成功
if [ $? -eq 0 ];
    then
    echo "PASSWD changed successfully"
    else
    echo "PASSWD change failed"
    exit
fi

echo "用户配置完成"

# 复制环境配置脚本到新用户主目录
cp isoftstone_env.sh /home/${username}/
chown ${username} /home/${username}/isoftstone_env.sh
chgrp ${username} /home/${username}/isoftstone_env.sh
chmod a+x /home/${username}/isoftstone_env.sh

# 修改 /etc/sudoers 文件，允许 sudo 命令不需要密码
q=`grep -n '%sudo	ALL=(ALL:ALL) ALL' /etc/sudoers | awk -F':' '{print $1}'`
#echo "q"$q

if [ ! -n "$q" ]; then
    echo "sudo命令权限已经改变"
else 
    TMPq='%sudo	ALL=(ALL:ALL) NOPASSWD: ALL'
    sed -i "$[ q ]c $TMPq" /etc/sudoers
    echo "sudo权限修改完成"
fi

# 确保 /etc/sudoers 文件中包含 'Defaults   visiblepw'
num=`grep -n 'Defaults   visiblepw' /etc/sudoers | awk -F':' '{print $1}'`
#echo $num
if [ ! -n "$num" ]; then
  echo "Defaults visiblepw IS NULL"
  sudo echo 'Defaults   visiblepw' >> /etc/sudoers
else
  echo "Defaults visiblepw NOT NULL"
fi

# 以新用户身份执行环境配置脚本
su - $username -c "bash isoftstone_env.sh $username ${USER_PASSWD}"

# 删除临时文件
rm /home/$username/install_vim.sh*
rm /home/$username/isoftstone_env.sh*
rm /home/$username/install_zsh.sh*

# 恢复 /etc/sudoers 文件中的 sudo 配置
l=`grep -n '%sudo	ALL=(ALL:ALL) NOPASSWD: ALL' /etc/sudoers | awk -F':' '{print $1}'`
if [ ! -n "$l" ]; then
    echo "sudo 命令不用修改或检查命令是否为原文件"
else 
    TMPl='%sudo	ALL=(ALL:ALL) ALL'
    sudo sed -i "$[ l ]c $TMPl" /etc/sudoers
    echo "sudo 内容已经恢复"
fi

# 删除脚本文件
cd
rm ./init_env.sh
rm ./isoftstone_env.sh
echo "Linux系统配置已完成, 请使用新账户登录系统"
echo "--------------------------------------"
echo -e "你的用户名${BLUE}${username}${RESET}\n密码为${GREEN}${USER_PASSWD}${RESET}\n"
su - ${username}