#!/usr/bin/env python3

import namelist
import sys,os

nmlgrp = namelist.decode_namelist_file(sys.argv[1])

for key in nmlgrp["namsfc"].keys():
    value = getattr(nmlgrp["namsfc"],key)
    if key.startswith("fn") and len(value) > 10:
        if not os.path.lexists(value):
            print(f"{key} = {value}, Not exist")
        else:
            print(f"{key} = Good")
           
