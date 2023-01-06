#!/bin/bash
NODE_VER=19.4.0
PROMPT='n'

DNF_CMD=$(which dnf)
YUM_CMD=$(which yum)
APT_GET_CMD=$(which apt-get)
APT_CMD=$(which apt)
PACMAN_CMD=$(which pacman)

#Install nvim
printf "  This script will install nvim for LINUX with the default
  package manager, install nodejs via fnm (used by vimplugins),
  clone the dotfiles from github.com/corigne/dotnvim, and execute 
  the dotfile install script, which installs and runs vimplug.\n"
read -p "Do you wish to install nvim using this script? (Y/n): " PROMPT

if [ $PROMPT == 'Y' ]
then
  clear
  printf "Discovering package manager...\n\n"

  if [[ ! -z $DNF_CMD ]] ;then
    printf "Using dnf...\n"
    sudo $DNF_CMD install neovim
  elif [[ ! -z $YUM_CMD ]] ;then
    printf "Using yum...\n"
    sudo $YUM_CMD install neovim
  elif [[ ! -z $APT_GET_CMD ]] ;then
    printf "Using apt-get...\n"
    sudo $APT_GET_CMD install neovim
  elif [[ ! -z $APT_CMD ]] ;then
    printf "Using apt...\n"
    sudo $APT_CMD install neovim
  elif [[ ! -z $PACMAN_CMD ]] ;then
    printf "Using pacman...\n" 
    sudo $PACMAN_CMD -S neovim
  else
    echo "error can't install NVIM"
    exit 1
  fi

  printf "#################################\n\n"
  #Install nodejs
  printf "Installing fnm for management of nodejs $NODE_VER..."
  curl -fsSL https://fnm.vercel.app/install | bash
  fnm install $NODE_VER
  fnm default $NODE_VER
  printf "#################################\n\n"

  #clone into dotfiles repo
  printf "Installing dotfiles from github.com/corigne/dotnvim.git ...\n"
  cd $HOME
  [ -d .config ] || mkdir .config
  cd .config
  [ -d nvim ] && rm -rf nvim && mkdir nvim
  cd nvim
  pwd
  git clone https://github.com/corigne/dotnvim.git .
  printf "#################################\n\n"

  #run dotfile installer
  bash ./dot_setup.sh
  printf "nvim installscript completed... probably...\n\n"
else
  printf "Installation cancelled by user, goodbye!\n\n"
fi
