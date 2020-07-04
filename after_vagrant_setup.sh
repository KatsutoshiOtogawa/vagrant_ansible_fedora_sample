##
## Dont change this file,if you dont understand
##

## すべてローカル環境側の設定

ssh_config_host="vagrant"

loginuser="vagrant"

secret_key="ansible_ecdsa"

password_file="ansible_password.yml"

server_ip="192.168.33.11"

# アプリケーション名をここに書く
# アプリケーション名_USER という形で仕様
APP=APP

# you want to use ssh directory.
# ex) ./.ssh #-> inside of project
# ex) $HOME/.ssh #-> you using user .ssh
ssh_directory=./.ssh

secret_key_path=$ssh_directory/$secret_key

# sshでログイン用のプロジェクト配下に作成
mkdir -m 700 $ssh_directory

# vagrantの場合はconfigファイルを書いておく。
if [ $ssh_config_host == 'vagrant' ]; then
    # vagrant(server)側の設定をクライアント側のPCに書く。
    vagrant ssh-config  --host $ssh_config_host >> $ssh_directory/config
fi

# 指定されたssh/configが無い場合はエラーにして設定を求める
cat $ssh_directory/config | grep -E ^Host | grep $ssh_config_host >> /dev/null
if [ $? == 1 ]; then
    echo you config $ssh_directory/config!
    exit 1;
fi

# scpは非推奨になったためsftpで実装
sftp -F $ssh_directory/config $ssh_config_host  <<END
lcd ./.ssh/
get /home/$loginuser/$secret_key
END

# scpは非推奨になったためsftpで実装
sftp -F ./.ssh/config $ssh_config_host  <<END
get /home/$loginuser/$password_file
END

# 秘密鍵をダウンロードしたので、安全のためサーバー側の秘密鍵を削除
ssh -F $ssh_directory/config $ssh_config_host rm /home/$loginuser/$secret_key

# パスワードファイルをダウンロードしたので、安全のためサーバー側のパスワードファイルを削除
ssh -F $ssh_directory/config $ssh_config_host rm /home/$loginuser/$password_file

# 秘密鍵を使うためにパーミッション変更
chmod 600 $ssh_directory/$secret_key

# User,IdentityFileをansibleの物に変更
vagrant ssh-config  --host ${ssh_config_host}_ansible | 
    sed "s/User $loginuser/User ansible/" |
    sed -E "s|IdentityFile .*$|IdentityFile $ssh_directory/$secret_key|" >> $ssh_directory/config

# ansibleが秘密鍵を使うためのユーザーを作成
ansible-vault encrypt $password_file

# セキュリティ上、rootユーザーの環境変数を引き継ぐ、もしくは指定される形で実行する。
# アプリケーションのユーザー名
read -p "input ${APP} username>" ${APP}_USERNAME
ssh -F $ssh_directory/config $ssh_config_host "echo export PUPPETEER_USERNAME=$PUPPETEER_USERNAME >> /home/$loginuser/.profile"

# アプリケーションのパスワード名
read -sp "input ${APP} password>" ${APP}_PASSWORD
ssh -F $ssh_directory/config $ssh_config_host "echo export PUPPETEER_PASSWORD=$PUPPETEER_PASSWORD >> /home/$loginuser/.profile"
echo ""


# ansibleで解決できないか確認。
# アプリケーションサーバーの外部から参照するためのホスト名
# これがないとALLOWED_HOSTなどを開発時と環境時でがちゃがちゃ触る必要があるので、
# 非効率。
server_hostname=$(ssh -F .ssh/config vagrant hostname)
echo "added recored to /etc/hosts"
sudo su <<END
    echo "# below record is develop server record." >> /etc/hosts
    echo "$server_ip $server_hostname $server_hostname" >> /etc/hosts
END
