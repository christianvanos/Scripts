#!/bin/bash

##############################
## made by Christian van Os ##
##############################

######### Programs ########

SHA1SUM="/usr/bin/sha1sum";
SORT="/usr/bin/sort";
AWK="/usr/bin/awk";
MV="/bin/mv";

######## Arguments ########

backup_path="${1}"

######### Functions  ########

pre() {
        echo "Start...";
        cd ${backup_path};
}

unique() {
        local previous_file_hash="";
        local current_file_hash="";

        for file_path in $(${SHA1SUM} ${backup_path}/* | ${SORT} -r | ${AWK} '{print $2}'); do
                current_file_hash=$(${SHA1SUM} ${file_path} | ${AWK} '{print $1}');

                if [[ ${current_file_hash} == ${previous_file_hash} ]]; then
                        echo "move to /tmp => ${file_path} ${current_file_hash}";
                        ${MV} ${file_path} /tmp/;
                fi

                previous_file_hash=${current_file_hash};
        done
}

post() {
        echo "End...";
}

######### Script ########
pre;
unique;
post;