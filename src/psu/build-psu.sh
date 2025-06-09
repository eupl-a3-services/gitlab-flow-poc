#!/bin/bash 

set -ex

PSU_RELEASE='1.3.1'

if [ -d "psu_${PSU_RELEASE}" ]; then
    rm -rf "psu_${PSU_RELEASE}"
fi

git clone https://gitlab.com/psuapp/psu.git --branch v${PSU_RELEASE} --single-branch psu-${PSU_RELEASE}
pushd psu-${PSU_RELEASE}
git apply ../enhance_psu_${PSU_RELEASE}.patch
popd