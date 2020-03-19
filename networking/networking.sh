#!/bin/bash
# Generate the filename we'll be using.
# I'm attempting to make the filename as search-able as possible.
# netstats to define that it is a log from this script, then a date and time arranged like YYYY-MM-DD-HHMMSS - from the number that changes the least to the one that changes the most.
FILENAME="netstats-$(date +%F-%H%M%S)"
# I'm also going to throw a very long regex string here that we will need for later, when we read the hosts file (and possibly the DNS servers):
V4_REGGIE='(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)'
V6_REGGIE='(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))'
# So I figured I could do one of two things, both involving tee (prints output and logs to a file):
# 1. I could wrap the entire script in a giant function, and then pipe that function through tee.
# 2. I could just append tee to the end of everything, everything after the first call to tee appending the file.
# I bet you can tell which idea won.

### ~vibe~ root check
# First, need to do a basic check if running as root, since some of these commands need to run with root permissions.
# If not, we'll exit with an error code.
if [[ $EUID != 0 ]]; then
	echo "Must be run under sudo or as root, exiting..."
	exit 1
fi

### Header
# A lot of these echo statements are for the * a e s t h e t i c s *. This bloc's one of them.
echo " "
echo "       **** CIS245 -  Network Information Script ****" | tee ./$FILENAME
echo " " | tee -a ./$FILENAME
echo "------------------------------------------------------------" | tee -a ./$FILENAME
echo " " | tee -a ./$FILENAME

### Network IP Addresses
# This part's dead simple.
# We list everything with ip addr, and use grep and awk to grab just the IP addresses.
# Grep isolates the lines, awk isolates the IP address (2nd column).
# The process is essentially the same for both IPv4 and IPv6.
echo "                  **** IPv4 Addresses ****" | tee -a ./$FILENAME
echo " " | tee -a ./$FILENAME
ip addr | grep 'inet ' | awk '{print $2}' | tee -a ./$FILENAME
echo " " | tee -a ./$FILENAME
echo "------------------------------------------------------------" | tee -a ./$FILENAME
echo " " | tee -a ./$FILENAME
echo "                  **** IPv6 Addresses ****" | tee -a ./$FILENAME
echo " " | tee -a ./$FILENAME
ip addr | grep 'inet6 ' | awk '{print $2}' | tee -a ./$FILENAME
echo " " | tee -a ./$FILENAME
echo "------------------------------------------------------------" | tee -a ./$FILENAME
echo " " | tee -a ./$FILENAME

### DNS Servers
# This part is _fun_, thanks entirely to systemd-resolve. I don't get why they needed to add another layer of complexity to DNS lookups, but whatever.
# We create a variable that checks the first nameserver value in resolv.conf. systemd-resolve uses an internal DNS server at 127.0.0.53 and writes it here.
# If we find that, we'll assume the server is running under systemd-resolve for DNS queries, else we will assume that just referring to resolv.conf will work.
USE_SYSD=$(cat /etc/resolv.conf | grep '^nameserver' | head -n 1 | awk '{print $2}')
if [[ $USE_SYSD = '127.0.0.53' ]]; then
	echo "               **** DNS Servers (systemd) ****       " | tee -a ./$FILENAME
	echo " " | tee -a ./$FILENAME

	#############################
	#  NOTE:  Here be dragons!  #
	#############################
	# Honestly, systemd-resolve has been a pain in my behind with this script. It seems to prioritize human readability.
	# Which is great... if I weren't trying to pull information from it via an automated process.
	# After looking at the servers I have that use systemd-resolve, I've determined the best way to pull all the DNS servers reliably
	# is to run systemd-resolve --status and return every IP address.
	# This is an assumption - namely, that all DNS servers will be referenced by an IP address, and nothing else in the output will.
	# It is an assumption that works on the servers I've tried it on, though.

	# The grep command runs extended regex, and only returns the matches. Note that it can return invalid IP addresses.
	# For example, it would accept 999.999.999.999 as a valid IP address. The regex to get valid IPs only is... a fair bit longer.
	#systemd-resolve --status | grep -E -o '([0-9]{1,3}[\.]){3}[0-9]{1,3}' | tee -a ./$FILENAME

	# Now, what's the regex to return valid IPs? Well, we defined it earlier, in the variable IP_REGGIE !
	# Let's take this moment to dissect it, though.
	# The meat and potatoes of it all can be seen in one of the parentheses: (25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)
	# If 25 are the first two numbers, the third has to be between 0-5.
	# The logic can be explained thusly:
	# If 2 is the first number and 0-4 is the second, the third can be any number.
	# Else, if the first number starts with 0 or 1, it can be up to three digits long, else it can only be up to 2 digits long.
	# Add a period afterwards and repeat that bloc three more times.
	# (Also I have to admit, the regex came from a blog post: https://www.shellhacks.com/regex-find-ip-addresses-file-grep/ I'm not a regex god, I just know how to use web search! ^^")

	# The IPv6 regex works in a rather similar way, although there's a lot going on with accounting for compressed entries (i.e. ::1 or fe80::1 or dead:beef:cafe::1337:1 or something like that)
	# I also should note that that specific regex came from a StackOverflow question, as I didn't want to pull my hair out figuring out how to write a good regex for that:
	# https://stackoverflow.com/questions/53497/regular-expression-that-matches-valid-ipv6-addresses

	# Anyways, now that my regex is ready, plugging it into the previous command would look something like... this:
	systemd-resolve --status | grep -E -o $V4_REGGIE | tee -a ./$FILENAME
	systemd-resolve --status | grep -E -o $V6_REGGIE | tee -a ./$FILENAME
	# We run it twice, one for IPv4 and one for IPv6. Just in case there are IPv6 nameserver entries.
	# My prior attempt at this was returning up to 5 lines, starting from when the line "DNS Servers:" shows up, and stopping once a blank line appears.
	# This worked OK for this server, but broke when I tried it on another Debian server I run that uses systemd-resolve and has, like, nine different DNS servers it refers to. x.x
else
	# Read from /etc/resolv.conf to return nameservers.
	echo "            **** DNS Servers (resolv.conf) ****" | tee -a ./$FILENAME
	echo " " | tee -a ./$FILENAME
	# This one is far less of a headache. Simply, return every line that starts with "nameserver" and print the second column.
	cat /etc/resolv.conf | grep '^nameserver' | awk '{print $2}' | tee -a ./$FILENAME
fi
echo " " | tee -a ./$FILENAME
echo "------------------------------------------------------------" | tee -a ./$FILENAME
echo " " | tee -a ./$FILENAME

### Hosts File
# I think it's good to know what you have in the hosts file.
# Heck, I recall a time where I had a friend that couldn't access one of their favourite games because of a rogue hosts file entry.
# Anyways, it's a simple file, it just has lines that start with an IP address, followed by hostnames that should point to that IP.
# I wrote this function after the Open Ports section, and I explained why I'm using functions for this there ---v
function returnHosts {
	echo "IP_Address Hostname(s)"
	# Return all lines starting with a valid IPv4 address, sorted.
	cat /etc/hosts | grep -E "^${V4_REGGIE}" | sort -n
	# Return all lines starting with a valid IPv6 address, sorted.
	cat /etc/hosts | grep -E "^${V6_REGGIE}" | sort -n
}
echo "                **** Hosts File Entries ****" | tee -a ./$FILENAME
echo " " | tee -a ./$FILENAME
# Run the function and align the columns.
returnHosts | column -t | tee -a ./$FILENAME
echo " " | tee -a ./$FILENAME
echo "------------------------------------------------------------" | tee -a ./$FILENAME
echo " " | tee -a ./$FILENAME


### Open Ports
# This will be about as complicated as I make it.
# I could literally just do "netstat -tulpn" and call it a day. That is what I've always done.
# But, I want to get fancy with it. I want it to be more human readable :)

# "Now Holly", you may ask, "Why are you making this a function?"
# To which I respond, I want to process the chart header using column as well. This is the best solution I can come up with.
function ports4 {
	echo "Proto IP Port Application"
	# Lemme break what I'm about to do down for you here.
	# netstat -tulpn is one of my favorite commands to run. I use it to get all the ports that are being listened to by the server.
	# The things I honestly care about the most from this is the IP address (am I listening to localhost (127.0.0.1) or all interfaces (0.0.0.0)?), the port, and the application.
	# The first grep statement separates IPv4 from IPv6, and the second ensures only ports being listened to are returned.
	# Then we run it through some awk. We print the protocol as-is. We then separate the IP from the port and print them separately. We then separate the PID from the application and print them in a nicer format.
	# We then finally run sort on the second column, then the third column, so we get a nice, organized listing of ports being listened to on what interfaces.
	netstat -tulpn | grep -E '^tcp |^udp ' | grep 'LISTEN' | gawk '{printf $1 "\t"; split($4,a,":"); printf a[1] "\t" a[2] "\t"; split($7,b,"/"); print b[2] " (PID:" b[1] ")"}' | sort -k2,3 -n
}
function ports6 {
	echo "Proto IP:Port Application"
	# This one functions in a very similar manner to the previous command, with one difference: We don't split the IP from the port.
	# The reason why, to be frankly honest, is I feel like I'd get a headache trying to come up with the regex necessary, and honestly, as I said, I could have just ran netstat -tulpn and called it a day lol
	netstat -tulpn | grep -E '^tcp6 |^udp6 ' | grep 'LISTEN' | gawk '{printf $1 "\t" $4 "\t"; split($7,b,"/"); print b[2] " (PID:" b[1] ")"}' | sort -k2 -n
}

# Here is where we actually use the functions we defined. We run the output through column -t, which will neatly organize the columns so they don't run into each other.
echo "          **** Ports In Use/Listening  (IPv4) ****" | tee -a ./$FILENAME
echo " " | tee -a ./$FILENAME
ports4 | column -t | tee -a ./$FILENAME
echo " " | tee -a ./$FILENAME
echo "------------------------------------------------------------" | tee -a ./$FILENAME
echo " " | tee -a ./$FILENAME
echo "          **** Ports In Use/Listening  (IPv6) ****" | tee -a ./$FILENAME
echo " " | tee -a ./$FILENAME
ports6 | column -t | tee -a ./$FILENAME
echo " " | tee -a ./$FILENAME
echo "------------------------------------------------------------" | tee -a ./$FILENAME
echo " " | tee -a ./$FILENAME

### IPTables Rules
# Honestly, I can't think of a way to organize the IPTables rules that makes it all that much easier to understand than how it is laid out by default.
# So I'll just return the output of the commands and call it a day here.
echo "              **** IPTables Rules (IPv4) ****" | tee -a ./$FILENAME
echo " " | tee -a ./$FILENAME
iptables -L | tee -a ./$FILENAME
echo " " | tee -a ./$FILENAME
echo "------------------------------------------------------------" | tee -a ./$FILENAME
echo " " | tee -a ./$FILENAME
echo "              **** IPTables Rules (IPv6) ****       " | tee -a ./$FILENAME
echo " " | tee -a ./$FILENAME
ip6tables -L | tee -a ./$FILENAME
echo " " | tee -a ./$FILENAME
echo "------------------------------------------------------------" | tee -a ./$FILENAME


# Set the read permissions for the output to 644, print the filename, and call it a wrap.
chmod 0644 ./$FILENAME
echo " "
echo "Saved to $FILENAME"
echo " "
