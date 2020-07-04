dnf -y update

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

## you want to install desktop uncomment this code
## puppeteerはデスクトップ環境が必要なためインストール。
## ログイン自体はcuiでもいいのでmulti-userにしておく。
# dnf -y group install GNOME
## althougn,you want to use cui, uncomment below code
# systemctl set-default multi-user

# ごみを削除
dnf -y autoremove
