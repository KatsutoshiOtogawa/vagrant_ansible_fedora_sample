dnf -y update
dnf -y install git

# ansible 利用のための設定
## デフォルトのログインユーザー,vagrantの場合はvagrant,awsなどはec2-userなど
loginuser=vagrant

## pwmakeを使うためにインストール
dnf -y install libpwquality

## ansible からwordpressや、redmineなどの構成をインストールできるように
## ansibleユーザーを作成しておく。
## クライアントがansibleでsshからログインできるように
## /home/ansible/.ssh/ansible_ecdsa をクライアント側にダウンロード。
## 秘密鍵をダウンロードしたら、vagrant(server)側の秘密鍵を削除すること。
useradd -m ansible -s /bin/bash

## ansibleからsudoを実行するために必要
usermod -aG sudo ansible

## ansibleユーザーのパスワードはansible-vault encryptで設定するので、秘密鍵のパスワードの設定はしない。
su ansible -c 'ssh-keygen -t ecdsa -f /home/ansible/.ssh/ansible_ecdsa -N ""'
su ansible -c 'cat /home/ansible/.ssh/ansible_ecdsa.pub >> /home/ansible/.ssh/authorized_keys'
rm /home/ansible/.ssh/ansible_ecdsa.pub

## デフォルトのログインユーザーで秘密鍵をダウンロード、削除できるようにファイルを移動
mv /home/ansible/.ssh/ansible_ecdsa /home/$loginuser/

## デフォルトのログインユーザーで秘密鍵をダウンロード、削除できるように所有者を変更
chown $loginuser:$loginuser /home/$loginuser/ansible_ecdsa

## ansibleがplyabookでsudoが使えるように設定
ansible_password=$(pwmake 64)
echo ansible:${ansible_password} | chpasswd
echo ansible_become_pass: ${ansible_password} > /home/$loginuser/ansible_password.yml

## vagrantユーザーでansibleのパスワードをダウンロード、削除できるようにユーザーを変更
chown $loginuser:$loginuser /home/$loginuser/ansible_password.yml

## 特定のプロジェクトだけダウンロードする。
# ex)
# su - $loginuser << EOF
#     git clone https://github.com/KatsutoshiOtogawa/puppet_itigo.git
#     cd puppet_itigo
#     git config core.sparsecheckout true
#     echo project/ >> .git/info/sparse-checkout
#     echo backend/ >> .git/info/sparse-checkout
#     git read-tree -m -u HEAD
# EOF

# $loginuserのファイルを他のユーザーに渡すためのディレクトリ
mkdir -m 755 /home/public
mkdir -m 750 /home/public/$loginuser
chown $loginuser:$loginuser /home/public/$loginuser

# ansibleユーザーに対してのみ、ディレクトリに対し読み込みと実行権限を与える。
# ここにあるファイルの削除は$loginuserの責任とする。
usermod -aG $loginuser ansible

# ログインユーザーの環境変数に他のユーザーとの共有用のディレクトリを書いておく。
su $loginuser -c "echo export APP_DATA=/home/public/$loginuser >> /home/$loginuser/.profile"

## install wireguard
## 未実装
# dnf install wireguard-tools
# # サーバー側の秘密鍵を作成
# wg genkey >> /etc/wireguard/server.key
# chmod 600 /etc/wireguard/server.key

# # ユーザー配布用のサーバーの公開鍵を作成
# cat /etc/wireguard/server.key | wg pubkey >> /etc/wireguard/server.pub
# chmod 600 /etc/wireguard/server.pub

# # ログインユーザーにサーバーの公開鍵を配布
# cp /etc/wireguard/server.pub /home/$loginuser/
# chown $loginuser:$loginuser /home/$loginuser/server.pub

# # 
# serverkey=$(cat /etc/wireguard/server.key)
# echo "
# [Interface]
# PrivateKey = $serverkey
# Address = 10.0.0.1
# ListenPort = 51820

# [Peer]
# PublicKey = I1HvSRbkkpHErYI6XWfu9d0EoRkKiqi52DbcZuGhAEU=
# AllowedIPs = 10.0.0.2/32
# " >> /etc/wireguard/wg0.conf

# # firewalldのインストール,設定
# # 参考 (https://qiita.com/suzutsuki0220/items/4a62cc0e676a80ed79f1)
# dnf -y install firewalld
# systemctl enable firewalld && systemctl start firewalld
# # firewalldで設定wireguardは20200702現在。firewall-cmd --get-servicesに
# # 登録されていないので、定義も作成する。
# echo "
# <?xml version='1.0' encoding='utf-8'?>
# <service>
#   <short>wireguard</short>
#   <description>wireguard is a virtual private network (VPN) solution. It is used to create encrypted point-to-point tunnels between computers. If you plan to provide a VPN service, enable this option.</description>
#   <port protocol='udp' port='51280'></port>
# </service>
# " >> /etc/firewalld/services/wireguard.xml
# # firewallの設定を反映させる。
# firewall-cmd --reload
# firewall-cmd -add-service=wireguard --permanent


## [Optional]
## you want to install desktop uncomment this code
## puppeteerはデスクトップ環境が必要なためインストール。
## ログイン自体はcuiでもいいのでmulti-userにしておく。
# dnf -y group install GNOME
## althougn,you want to use cui, uncomment below code
# systemctl set-default multi-user

# ごみを削除
dnf -y autoremove
