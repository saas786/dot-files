# Useful Functions

cheatsheet() {
    # Cheatsheets https://github.com/chubin/cheat.sh
    if [ "$1" == "" ]; then
        recho "Usage $0 {filename}"
        recho "eg: ${FUNCNAME[0]} ls"
        exit 1
    fi
    curl -L "https://cheat.sh/$1"
}

create-venv() {
    if [ "$1" == "" ]; then
        recho "Usage $0 {Python version}"
        recho "eg: ${FUNCNAME[0]} 3"
    else command -v virtualenv > /dev/null;
        virtdir=".$(basename $(pwd))_Py${1}"
        virtualenv --python="python${1}" "${virtdir}" --no-site-packages
        source "${virtdir}/bin/activate"

        "${virtdir}/bin/pip" install flake8 \
                                     isort \
                                     autopep8 \
                                     future \
                                     six \
                                     future-fstrings

        if [ $(echo " $@ >= 3" | bc) -eq 1 ]; then
            "${virtdir}/bin/pip" install black ipython['all']
        else
            "${virtdir}/bin/pip" install ipython==5.8.0
        fi
    fi
}

up() {
    cd $(printf "%0.s../" $(seq 1 $1 ));
}

killbg(){
    kill -9 $(jobs -p)
}

# Calculator
calc() {
 # $ calc 1+2 == 3
    echo "$*" | bc -l
}

search_replace() {
    # Search and replace strings recursively in a given dir
    if [ -n "$2" ]; then
        if [ -n "$3" ]; then
            local path="$3";
        else
            local path=".";
        fi
        ag -l "$1" "$path" | xargs -I {} -- sed -i "" -e "s%${1//\\/}%$2%g" {}
    else
        echo "== Usage: gsed search_string replace_string [path = .]"
    fi
}

add_alias() {
    if [ -n "$2" ]; then
        echo "alias $1=\"$2\"" >> ~/.bash_aliases
        source ~/.bashrc
    else
        echo "Usage: add_alias <alias> <command>"
    fi
}

getbib_from_ieee() {
    # Download BibTex from IEEEExplore by ID or URL
    INFO="$@"
    if [[ "${INFO}" == http* ]]; then
        ID=$(echo "${INFO}" | cut -f5 -d '/')
    else
        ID="${INFO}"
    fi
    curl -s --data "recordIds=${ID}&download-format=download-bibtex&citations-format=citation-abstract" https://ieeexplore.ieee.org/xpl/downloadCitations > "${ID}_reference".bib
    sed -i "s/<br>//g" "${ID}_reference".bib
}

getbib(){

    if [ -f "$1" ]; then
        # Try to get DOI from pdfinfo or pdftotext output.
        doi=$(pdfinfo "$1" | grep -io "doi:.*") ||
        doi=$(pdftotext "$1" 2>/dev/null - | grep -io "doi:.*" -m 1) ||
        exit 1
    else
        doi="$1"
    fi

    # Check crossref.org for the bib citation.
    curl -s "http://api.crossref.org/works/${doi}/transform/application/x-bibtex" -w "\\n"
    # Check doi2bib.org for the bib citation.
    curl -s "https://doi2bib.org/doi2bib?id=${doi}" -w "\\n"
}

sciget() {
    # sci-hub.tw
    # The first pirate website in the world to provide mass and public access to tens of millions of research papers
    curl -O $(curl -s http://sci-hub.tw/"$@" | grep location.href | grep -o "http.*pdf")
    if [[ "$@" == "https://ieeexplore.ieee.org/"* ]]; then getbibtex "$@"; fi
}

mkcd() {
    # Create a new directory and enter it
    mkdir -p "$@" && echo "You are in: $@" && builtin cd "$@" || exit 1
}

rename-to-lowercase() {
    # Renames all items in a directory to lower case.
    for i in *; do
        echo "Renaming $i to ${i,,}"
        mv "$i" "${i,,}";
    done
}

git-pull-all() {
    CUR_DIR=$(pwd)
    find -type d -execdir test -d {}/.git \; -print -prune | while read -r DIR;
        do builtin cd $DIR &>/dev/null;
        git pull &>/dev/null &

        STATUS=$(git status 2>/dev/null |
        awk -v r=${RED} -v y=${YELLOW} -v g=${GREEN} -v b=${BLUE} -v n=${NC} '
        /^On branch / {printf(y$3n)}
        /^Changes not staged / {printf(g"|?Changes unstaged!"n)}
        /^Changes to be committed/ {printf(b"|*Uncommitted changes!"n)}
        /^Your branch is ahead of/ {printf(r"|^Push changes!"n)}
        ')

        printf "Repo: ${DIR} | ${STATUS}\n";
        builtin cd - &>/dev/null;
    done
    builtin cd $CUR_DIR &>/dev/null;
}

get-git-repos() {
    # Get a list of all your Git repos in the current directory
    CUR_DIR=$(pwd);
    find -type d -execdir test -d {}/.git \; -print -prune | while read -r DIR; do
        builtin cd $DIR &> /dev/null;
        git config --get remote.origin.url >> ~/My-Git-Repos.txt
        builtin cd - &> /dev/null;
    done;
    builtin cd "${CUR_DIR}" &> /dev/null
}

clone-my-repos() {
    # Clone all my repos from file
    CLONEDIR=~/GitHub
    if [ "$1" == "" ]; then
        recho "Usage $0 {filename}"
        recho "eg: ${FUNCNAME[0]} My-Git-Repos.txt"
    else
        while IFS='' read -r repo || [[ -n "$repo" ]]; do
            [ ! -d "${CLONEDIR}" ] && mkdir -p "${CLONEDIR}"
            echo "Cloning Repo: $repo"
            git -C "${CLONEDIR}" clone --depth 5 "$repo"
        done < "$1"
    fi
}

committer() {
    # Add file(s), commit and push
    FILE=$(git status | grep "modified:" | cut -f2 -d ":" | xargs)
    for file in $FILE; do git add -f "$file"; done
    if [ "$1" == "" ]; then
        # SignOff by username & email, SignOff with PGP and ignore hooks
        git commit -s -S -n -m"Updated $FILE";
    else
        git commit -s -S -n -m"$2";
    fi;
    read -t 5 -p "Hit ENTER if you want to push else wait 5 seconds"
    [ $? -eq 0 ] && bash -c "git push --no-verify -q &"
}

createpr() {
    # Push changes and create Pull Request on GitHub
    REMOTE="devel";
    if ! git show-ref --quiet refs/heads/devel; then REMOTE="master"; fi
    BRANCH="$(git rev-parse --abbrev-ref HEAD)"
    git push -u origin "${BRANCH}" || true;
    if command -v hub > /dev/null; then
        hub pull-request -b "${REMOTE}" -h "${BRANCH}" --no-edit || true
    else
        recho "Failed to create PR, create it Manually"
        recho "If you would like to continue install hub: https://github.com/github/hub/"
    fi
}

git-url-shortener(){
    # GitHub URL shortener
    if [ "$1" == "" ]; then
        recho "Usage $0 {Custom URL Name} {URL}"
        recho "eg: ${FUNCNAME[0]} runme https://raw.githubusercontent.com/blablabla "
    else
        curl https://git.io/ -i -F "url=${2}" -F "code=${1}"
    fi
}

filefinder() {
    for FILE in $(find . -type f -name "*$1"); do
        echo ${FILE};
    done
}

ssh() {
    # Always ssh with -X
    command ssh -X "$@"
}

wrapper() {
    # Desktop notification when long running commands complete
    start=$(date +%s)
    "$@"
    [ $(($(date +%s) - start)) -le 15 ] || notify-send "Notification" \
        "Long running command \"$(echo $@)\" took $(($(date +%s) - start)) seconds to finish"
}

extract() {
     if [ -f $1 ] ; then
         case $1 in
             *.tar.xz)    tar -xJf $1   ;;
             *.tar.bz2)   tar xjf $1    ;;
             *.tar.gz)    tar xzf $1    ;;
             *.bz2)       bunzip2 $1    ;;
             *.rar)       rar x $1      ;;
             *.gz)        gunzip $1     ;;
             *.tar)       tar xf $1     ;;
             *.tbz2)      tar xjf $1    ;;
             *.tgz)       tar xzf $1    ;;
             *.zip)       unzip $1      ;;
             *.Z)         uncompress $1 ;;
             *.7z)        7z x $1       ;;
             *)           echo "'$1' cannot be extracted via ${FUNCNAME[0]}" ;;
         esac
     else
         recho "'$1' is not a valid file"
     fi
}

open() {
     if [ -f $1 ] ; then
         case $1 in
            # List should be expanded.
             *.pdf)                 zathura $1 &               ;;
             *.md)                  pandoc $1 | lynx -stdin    ;;
             *.mp3|*.mp4|*.mkv)     vlc $1 & ;;
             *)        recho "'$1' cannot opened via ${FUNCNAME[0]}" ;;
         esac
     else
         recho "'$1' is not a valid file"
     fi
}

compile() {
     if [ -f $1 ] ; then
         case $1 in
            # List should be expanded.
             *.c)      gcc -Wall "$1" -o "main" -lm  ;;
             *.go)     go run "$1"                   ;;
             *.py)     pycompile -v "$1"             ;;
             *.tex)    latexmk -pdf "$1"             ;;
             *)        recho "'$1' cannot opened via ${FUNCNAME[0]}" ;;
         esac
     else
         recho "'$1' is not a valid file"
     fi
}

psgrep() {
	if [ ! -z $1 ] ; then
		echo "Grepping for processes matching $1..."
		ps aux | grep $1 | grep -v grep
	else
		recho "!! Need name to grep for"
	fi
}

cd() {
    # The 'builtin' keyword allows you to redefine a Bash builtin without
    # creating a recursion. Quoting the parameter makes it work in case there are spaces in
    # directory names.
    builtin cd "$@" && ls -thor;
}

pip() {
    if [[ "$1" == "install" ]]; then
        shift 1
        command pip install --no-cache-dir -U "$@"
    else
        command pip "$@"
    fi
}

install-pkg() {
    echo "Installing package: $1";
    if command -v gdebi >/dev/null;then
        sudo gdebi $1;
    else
        sudo dpkg --install $1;
    fi
}

gpg_delete_all_keys() {
    for KEY in $(gpg --with-colons --fingerprint | grep "^fpr" | cut -d: -f10); do
        gpg --batch --delete-secret-keys "${KEY}";
    done
}

disconnect() {
    # Disconnect all mounted disks
    while IFS= read -r -d '' file;
	do fusermount -qzu $file >/dev/null;
    done < <(find "${HOME}/mnt" -maxdepth 1 -type d -print0);
}

cammount() {
    IP="10.8.67.160"
    if timeout 2 ping -c 1 -W 2 "${IP}" &> /dev/null; then
        sshfs -o reconnect,ServerAliveInterval=5,ServerAliveCountMax=5 \
        kat@"${IP}":/ /home/"${USER}"/mnt/cam
    else
        fusermount -quz /home/"${USER}"/mnt/cam;
    fi
}


create_project () {
# Easily create a project x in current dir
    PROJECT_NAME=$1

    [ -d "${PROJECT_NAME}" ] || mkdir -p "${PROJECT_NAME}"
    cd "${PROJECT_NAME}"

    if ! pip freeze | grep -i pygithub >/dev/null ;then
        pip install -q --user pygithub;
    fi

    read -p "What is the language you using for the project? " LANG
    if [[ "${LANG}" =~ ^([pP])$thon ]]; then
        read -p "Is your project a Python Package? " response
        if [[ "${response}" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            wget -q https://github.com/mmphego/setup.py/archive/master.zip
            unzip -q master.zip -d .
            mv setup.py-master/* .
            CUR_DIR="${PWD##*/}"
            mv mypackage "${CUR_DIR~}"
            rm -rf setup.py-master master.zip LICENSE
        fi

        tee .travis.yml << EOF
language: python

# sudo false implies containerized builds
sudo: false

python:
  - 2.7
  - 3.6

before_install:
    - echo "Setup goes here"
install:
    - echo "Install goes here"
script:
    - echo "Tests go here"

EOF

    else
        curl -s "https://www.gitignore.io/api/${LANG}" > .gitignore
        touch .travis.yml
    fi

###
    git init -q
    tee README.md << EOF
# "${PROJECT_NAME}"

[![Build Status](https://travis-ci.com/{{USERNAME}}/${PROJECT_NAME}.svg?branch=master)](https://travis-ci.com/{{USERNAME}}/${PROJECT_NAME})
![GitHub](https://img.shields.io/github/license/{{USERNAME}}/${PROJECT_NAME}.svg)

## {{ STORY GOES HERE}}


## {{ INSTALLATION }}


## {{ USAGE }}


## Oh, Thanks!

By the way... Click if you'd like to [say thanks](https://saythanks.io/to/{{USERNAME}})... :) else *Star* it.

✨🍰✨

## Feedback

Feel free to fork it or send me PR to improve it.

EOF
    python3 -c """
from configparser import ConfigParser
from github import Github
from pathlib import Path
from subprocess import check_output

try:
    token = check_output(['git', 'config', 'user.token'])
    token = token.strip().decode() if type(token) == bytes else token.strip()
except Exception:
    p = pathlib.Path('.gitconfig.private')
    config.read(p.absolute())
    token = config['user']['token']

proj_name = Path.cwd().name
g = Github(token)
user = g.get_user()
user.create_repo(
    proj_name,
    has_wiki=False,
    has_issues=False,
    license_template='MIT',
    auto_init=False)
print('Successfully created repository %s' % proj_name)
"""

    git add .
    git commit -nm "Automated commit"
    git remote add origin "git@github.com:$(git config user.username)/${PROJECT_NAME}.git"
    git fetch --all -q
    git merge master origin/master -q --allow-unrelated-histories --commit -m"Merge branch 'master' of github.com:$(git config user.username)/automated_proj"
    git branch -q --set-upstream-to=origin/master master
    git push -q -u origin master
}