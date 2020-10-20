#!/bin/bash

prefix_to_bit_netmask() {
        prefix=$1;
        shift=$(( 32 - prefix ));

        bitmask=""

        for (( i=0; i < 32; i++ )); do
                num=0
                if [ $i -lt $prefix ]; then
                        num=1
                fi

                space=
                if [ $(( i % 8 )) -eq 0 ]; then
                        space=" ";
                fi

                bitmask="${bitmask}${space}${num}"
        done

        echo $bitmask
}

bit_netmask_to_wildcard_netmask() {
        bitmask=$1;
        wildcard_mask=

        for octet in $bitmask; do
                wildcard_mask="${wildcard_mask} $(( 255 - 2#$octet ))"
        done

        echo $wildcard_mask;
}

check_net_boundary() {
        net=$1;
        wildcard_mask=$2;
        is_correct=1;

        for (( i = 1; i <= 4; i++ )); do
                net_octet=$(echo $net | cut -d '.' -f $i)
                mask_octet=$(echo $wildcard_mask | cut -d ' ' -f $i)

                if [ $mask_octet -gt 0 ]; then
                        if [ $(( $net_octet&$mask_octet )) -ne 0 ]; then
                                is_correct=0;
                        fi
                fi
        done

        echo $is_correct;
}

check-equality() {
        ip=${1}
        ptr_domain=$(dig -x ${ip} +short)
        domain_ip=$(dig ${ptr_domain} +short)

        if [[ ${domain_ip}  == ${ip} ]]; then
                echo "${ip} ${ptr_domain}"
        fi
}

lines=$@

for ip in ${lines[@]}; do
        net=$(echo $ip | cut -d '/' -f 1);
        prefix=$(echo $ip | cut -d '/' -f 2);
        bit_netmask=$(prefix_to_bit_netmask $prefix);
        wildcard_mask=$(bit_netmask_to_wildcard_netmask "$bit_netmask");
        is_net_boundary=$(check_net_boundary $net "$wildcard_mask");
        str=

        for (( i = 1; i <= 4; i++ )); do
                range=$(echo $net | cut -d '.' -f $i)
                mask_octet=$(echo $wildcard_mask | cut -d ' ' -f $i)
                if [ $mask_octet -gt 0 ]; then
                        range="{$range..$(( $range | $mask_octet ))}";
                fi
                str="${str} $range"
        done
        ips=$(echo $str | sed "s, ,\\.,g"); ## replace spaces with periods, a join...

        for ip in $(eval echo $ips | tr ' ' '\n'); do
                check-equality ${ip}
        done
done