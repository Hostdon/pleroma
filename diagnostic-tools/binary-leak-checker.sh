if [ "$#" -ne 2 ]; then
	echo "Usage: binary-leak-checker.sh <nodename> <erlang cookie>"
	exit 1
fi

echo "The command you want to run is:
:recon.bin_leak(10)
"

iex --sname debug --remsh $1 --erl "-setcookie $2" 
