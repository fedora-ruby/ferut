#!/usr/bin/bash

mv $1 $(sed -ne '/^Subject: /{
        s/^Subject: *\[PATCH[^]]*\] *//;
        s/[^a-zA-Z0-9]/-/g;
        s/--*/-/g;
        s/$/\.patch/;
        p;
        q;
}' $1)
