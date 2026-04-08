case "$1" in
    -e|--edit)
        # wird ausgeführt wenn $1 "-e" oder "--edit" ist
	echo "opening known hosts file with nano..."
        ;;         # <-- das ist wie "break" in Python
    -u|--uninstall)
        # wird ausgeführt bei "-u" oder "--uninstall"
	echo "uninstalling sshmgr..."
        ;;
    "")
	echo "opening known host selection..."
        ;;
    *)
        # der "default" Fall — unbekanntes Argument
        echo "Unbekannte Option: $1"
        ;;
esac   # <-- "case" rückwärts geschrieben, so endet der Block
