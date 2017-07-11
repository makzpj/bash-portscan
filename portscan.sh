#!/bin/bash

host=$1
min_port=$2
max_port=$3

#Delete files from past runs
rm -f /tmp/portscan.*

if [ "$host" == "" ] || [ "$min_port" == "" ] || [ "$max_port" == "" ]
then
  echo "Usage: $0 host initialport finalport"
  echo -e "Ejemplo: $0 127.0.0.1 80 443"
fi

if [ $max_port -gt 65535 ]
then
 echo "The max port number is 65535"
 exit 1
fi

# Make pending ports list and test each port
for port in $(seq $min_port $max_port)
do
 #Run on background, beware of nproc limit
 #This is the actual test. Save result on file
 (echo > /dev/tcp/"$host"/"$port"; echo $? > /tmp/portscan.$port) &
 #Add port to pending ports list
 pending_ports[$i]=$port
 let i=$i+1
done

let last_index=${#pending_ports[@]}-1

echo -n "Scanning ports..."

# Let's poll the results. We'll know all tests have finished when
# the size of the pending_ports array is 0
i=0
while [ ${#pending_ports[@]} -ne 0 ]
do
  #We poll the results every second, to prevent high cpu usage
  sleep 1

  #if we checked all the ports on the list, return to the beginning of the list
  if [ $i -gt $last_index ]
  then
    i=0
  fi

  #This is the port number we are testing
  port=${pending_ports[$i]}

  # When we unset a value from the ports list (below) the reported size of the array shrinks
  # but the values are still there as empty. If we find an empty value in the ports list
  # it means it was unset below because we got the result of the test and we can skip to the next one.
  if [ "$port" == "" ]
  then
    let i=$i+1
    continue
  fi

  # If this file exists, we know the test for this particular port has finished
  if [ -f /tmp/portscan.$port ]
  then
    # We unset this port from the pending ports list. This shrinks the reported size of the array, but values are
    # not shifted, empty values are being put in the place of the old values.
    unset pending_ports[$i]
    # We get the value of $? from the redirection test which was saved to this file
    res="$(cat /tmp/portscan.$port)"
    if [ "$res" == "0" ]
    then
      open_ports="${open_ports}${port}\n"
    fi
  fi

  #Let's go to the next port on the list
  let i=$i+1
done

echo -e "Open ports on $host from $min_port to $max_port:\n"
echo -e "$open_ports"

# We delete our garbage
rm -f /tmp/portscan.*
