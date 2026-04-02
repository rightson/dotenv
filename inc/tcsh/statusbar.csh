# Statusbar / Prompt configuration for tcsh
# One-time init guarded by __prompt_initialized; precmd only updates dynamic parts

if ( ! $?__prompt_initialized ) then
    set __prompt_initialized = 1
    set txtred = "%{\e[0;30;31m%}"
    set txtgrn = "%{\e[0;30;32m%}"
    set txtylw = "%{\e[0;30;33m%}"
    set txtblu = "%{\e[0;30;34m%}"
    set txtpur = "%{\e[0;30;35m%}"
    set txtcyn = "%{\e[0;30;36m%}"
    set txtwht = "%{\e[0;30;37m%}"
    set txtrst = "%{\e[0m%}"
    # Use tcsh built-in %n instead of forking `whoami`
    set who    = "${txtred}%n${txtrst}"
    set host   = "${txtylw}%M${txtrst}"
    set apwd   = "${txtgrn}%~${txtrst}"
    set datetime = "${txtpur}%P %Y/%W/%D${txtrst}"
    set at     = "${txtwht}@${txtrst}"
    set sh_in_use = "${txtblu}(`echo $0 | sed 's/-//'`)${txtrst}"
    alias precmd 'source $ENV_ROOT/inc/tcsh/statusbar.csh >& /dev/null'
endif

# Dynamic parts: venv and git branch (runs on every precmd)
set venv = ""
if ( $?VIRTUAL_ENV ) then
    set venv = "[`basename ${VIRTUAL_ENV}`] "
endif

# Use git rev-parse (single process) instead of git branch | grep | sed (3 processes)
set gitrev = `git rev-parse --abbrev-ref HEAD`
if ( "${gitrev}" != "" ) then
    set branch = "${txtcyn}${gitrev}${txtrst}"
    set prompt = "${venv}${who}${at}${host}:${apwd} ($branch) [${datetime}] ${sh_in_use} \n%L%# "
else
    set prompt = "${venv}${who}${at}${host}:${apwd} [${datetime}] ${sh_in_use} \n%L%# "
endif
