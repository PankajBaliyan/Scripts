# To check file folder exist

cd ~/bin

# If not exist, create new one

mkdir -p ~/bin

# copy from other place or create new one

cp pipenv_temp_env.sh ~/bin

# give executable permission

chmod +x ~/bin/create-venv-here.sh

# Create Alias

-- For Zsh
echo 'alias create-venv-here="/Users/pankajkumar/bin/create-venv-here.sh"' >> ~/.zshrc
source ~/.zshrc

# Usage

create-venv-here
