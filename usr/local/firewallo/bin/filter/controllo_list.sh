lista=$(ls)
for i in $lista ; do printf $i ; cat $i | grep $i | wc -l ; done
for i in $lista ; do printf $i ; cat $i | grep tcp | wc -l ; done
for i in $lista ; do printf $i ; cat $i | grep udp | wc -l ; done
