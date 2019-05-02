#!/bin/bash

# Created by Adam Wiethuechter
# Date: 03-27-2019
# Critical Technologies Inc. (CTI)

# Args: full path to OpenHIP directory

HIP_DIR=$1
PATCH_DIR=$(pwd)

echo "OpenHIP Directory: "$HIP_DIR
echo "OpenHIP Patch Directory: "$PATCH_DIR

# save relevant files by renaming them
mv $HIP_DIR"/src/util/hip_util.c" $HIP_DIR"/src/util/hip_util.c.orig"
mv $HIP_DIR"/src/util/hip_xml.c" $HIP_DIR"/src/util/hip_xml.c.orig"
mv $HIP_DIR"/src/util/hitgen.c" $HIP_DIR"/src/util/hitgen.c.orig"

mv $HIP_DIR"/src/protocol/hip_cache.c" $HIP_DIR"/src/protocol/hip_cache.c.orig"
mv $HIP_DIR"/src/protocol/hip_dht.c" $HIP_DIR"/src/protocol/hip_dht.c.orig"
mv $HIP_DIR"/src/protocol/hip_input.c" $HIP_DIR"/src/protocol/hip_input.c.orig"
mv $HIP_DIR"/src/protocol/hip_output.c" $HIP_DIR"/src/protocol/hip_output.c.orig"

mv $HIP_DIR"/src/include/hip/hip_sadb.h" $HIP_DIR"/src/include/hip/hip_sadb.h.orig"

mv $HIP_DIR"/src/usermode/hip_esp.c" $HIP_DIR"/src/usermode/hip_esp.c.orig"
mv $HIP_DIR"/src/usermode/hip_sadb.c" $HIP_DIR"/src/usermode/hip_sadb.c.orig"

# copy in new patched files
cp $PATCH_DIR"/src-util/"* $HIP_DIR"/src/util/"
cp $PATCH_DIR"/src-protocol/"* $HIP_DIR"/src/protocol/"
cp $PATCH_DIR"/src-include-hip/"* $HIP_DIR"/src/include/hip/"
cp $PATCH_DIR"/src-usermode/"* $HIP_DIR"/src/usermode/"

echo "Next run './bootstrap' then 'configure' in OpenHIP directory."
echo "After 'configure' is done edit the src/Makefile removing from CFLAGS the '-Werror' flag."
echo "Finally run 'make' then 'sudo make install' to complete build."