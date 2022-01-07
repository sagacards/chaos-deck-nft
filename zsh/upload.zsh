#!/bin/zsh

file=${1}
filename=${2}
fileextension=$(echo $file | sed -E "s/.+\.//")
name=${3}
tags=("${(@s/ /)4}")
description=${5}
mime=${6:-image/$fileextension}
network=${7:-local}
threshold=${8:-100000}


echo "$network Emptying buffer..."
dfx canister --network $network call nft-example uploadClear

i=0
byteSize=${#$(od -An -v -tuC $file)[@]}
echo "$network Uploading asset \"$filename\", size: $byteSize"
while [ $i -le $byteSize ]; do
    echo "chunk #$(($i/$threshold+1))..."
    dfx canister --network $network call nft-example upload "( vec {\
        vec { $(for byte in ${(j:;:)$(od -An -v -tuC $file)[@]:$i:$threshold}; echo "$byte;") };\
    })"
    i=$(($i+$threshold))
done
echo "$network Finalizing asset \"$filename\""
dfx canister --network $network call nft-example uploadFinalize "(\
    \"\",\
    record {\
        \"name\" = \"$name\";\
        \"filename\" = \"$filename\";\
        \"tags\" = vec { $(for tag in $tags; echo \"$tag\"\;) };\
        \"description\" = \"$description\";\
    }\
)"