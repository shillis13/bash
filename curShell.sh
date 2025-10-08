
echo "script shell:  $(ps -p $$   -o comm=)"
echo "parent shell:  $(ps -p $PPID -o comm=)"
echo "login shell:   $(dscl . -read /Users/$USER UserShell | awk '{print $2}')"


