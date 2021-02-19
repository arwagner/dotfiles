#!/bin/bash

mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" > /dev/null && pwd )"

source $mydir/git-completion.bash
source $mydir/git-prompt.sh

PS1='[\u@\h \W$(__git_ps1 " (%s)")]\$ '
