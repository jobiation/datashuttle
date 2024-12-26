##############SETTING UP THIS SCRIPT##################


###### You might need to type the following command one time:
# git config --global credential.helper '!f() { sleep 1; echo "username=jobiation token=[YOUR_PERSONAL_ACCESS_TOKEN]"; }; f'

##### You might need the following command:
# git config --global --add safe.directory /var/local/externaldisk/remotebackup

###### Generate an SSH key and copy the public key to Settings - SSH and GPG Keys
# ssh-keygen -t ed25519 -C "jobiationautomation@gmail.com"

git config --global user.email "jobiationautomation@gmail.com"
git config --global user.name "jobiation"

eval "$(ssh-agent -s)"
ssh-add ../git.key

git add . && git commit -m "Just another push"
git push git@github.com:jobiation/ubuntuhelper.git
