#!/usr/bin/bash

mv $1 $(sed -ne '/^Subject: /{
        s/^Subject: *\[PATCH[^]]*\] *//;
        s/[^[:alnum:]]/-/g;
        s/--*/-/g;
        s/^-//;
        s/$/\.patch/;
        p;
        q;
}' $1)
