#!/usr/bin/bash

new_name=$(sed -ne '/^Subject: /{
        s/^Subject: *\[PATCH[^]]*\] *//;
        s/[^[:alnum:]]/-/g;
        s/--*/-/g;
        s/^-//;
        s/$/\.patch/;
        p;
        q;
}' $1)

echo "${1} => ${new_name}"

mv $1 ${new_name}
