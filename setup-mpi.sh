#!/bin/bash
set -eu

MPI=$(echo "${1:-}" | tr '[:upper:]' '[:lower:]')

setup-apt-intel-oneapi () {
    apt_repo_url=https://apt.repos.intel.com/
    gpg_key_url=$apt_repo_url/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB
    keyring=/usr/share/keyrings/oneapi-archive-keyring.gpg
    # download the key to system keyring
    curl -s $gpg_key_url | gpg --dearmor | sudo tee $keyring > /dev/null
    # add signed entry to apt sources
    echo "deb [signed-by=${keyring}] ${apt_repo_url}/oneapi all main" | \
    sudo tee /etc/apt/sources.list.d/oneAPI.list
    # update list of available packages
    sudo apt update
}

setup-env-intel-oneapi () {
    set +u
    source /opt/intel/oneapi/setvars.sh
    set -u
    echo "${I_MPI_ROOT}/bin" >> $GITHUB_PATH
    echo "ONEAPI_ROOT=${ONEAPI_ROOT}" >> $GITHUB_ENV
    echo "I_MPI_ROOT=${I_MPI_ROOT}" >> $GITHUB_ENV
    echo "FI_PROVIDER_PATH=${FI_PROVIDER_PATH}" >> $GITHUB_ENV
    echo "LD_LIBRARY_PATH=${LD_LIBRARY_PATH}" >> $GITHUB_ENV
    echo "PKG_CONFIG_PATH=${PKG_CONFIG_PATH}" >> $GITHUB_ENV
}

setup-win-intel-oneapi-mpi () {
    baseurl=https://registrationcenter-download.intel.com
    subpath=akdlm/irc_nas/19160
    version=2021.8.0 build=25543
    package=w_mpi_oneapi_p_${version}.${build}_offline.exe
    set -x
    curl -sO $baseurl/$subpath/$package
    ./$package -s -a --silent --eula accept
    set +x
}

setup-win-intel-oneapi-mpi-env () {
    ONEAPI_ROOT="C:\Program Files (x86)\Intel\oneAPI"
    I_MPI_ROOT="${ONEAPI_ROOT}\mpi\latest"
    library_kind="release"
    I_MPI_OFI_LIBRARY_INTERNAL="1"

    echo "ONEAPI_ROOT=${ONEAPI_ROOT}" >> $GITHUB_ENV
    echo "I_MPI_ROOT=${I_MPI_ROOT}" >> $GITHUB_ENV
    echo "library_kind=${library_kind}" >> $GITHUB_ENV
    echo "I_MPI_OFI_LIBRARY_INTERNAL=${I_MPI_OFI_LIBRARY_INTERNAL}" >> $GITHUB_ENV

    echo "${I_MPI_ROOT}\\bin" >> $GITHUB_PATH
    echo "${I_MPI_ROOT}\\bin\\$library_kind" >> $GITHUB_PATH
    echo "${I_MPI_ROOT}\\libfabric\\bin" >> $GITHUB_PATH
    echo "${I_MPI_ROOT}\\libfabric\\bin\\utils" >> $GITHUB_PATH

    ONEAPI_ROOT="/c/Program Files (x86)/Intel/oneAPI"
    I_MPI_ROOT="${ONEAPI_ROOT}/mpi/latest"
    export PATH="${I_MPI_ROOT}/bin:$PATH"
    export PATH="${I_MPI_ROOT}/bin/$library_kind:$PATH"
    export PATH="${I_MPI_ROOT}/libfabric/bin:$PATH"
    export PATH="${I_MPI_ROOT}/libfabric/bin/utils:$PATH"
    impi_info=impi_info.exe
}

case $(uname) in

    Linux)
        MPI="${MPI:-mpich}"
        echo "::group::Installing $MPI with apt"
        sudo apt update
        case $MPI in
            mpich)
                sudo apt install -y -q mpich libmpich-dev
                ;;
            openmpi)
                sudo apt install -y -q openmpi-bin libopenmpi-dev
                ;;
            intelmpi)
                setup-apt-intel-oneapi
                sudo apt install -y -q intel-oneapi-mpi-devel
                setup-env-intel-oneapi
                ;;
            *)
                echo "Unknown MPI implementation:" $MPI
                exit 1
                ;;
        esac
        echo "::endgroup::"
        ;;

    Darwin)
        MPI="${MPI:-mpich}"
        echo "::group::Installing $MPI with brew"
        case $MPI in
            mpich)
                brew install mpich
                ;;
            openmpi)
                brew install openmpi
                ;;
            *)
                echo "Unknown MPI implementation:" $MPI
                exit 1
                ;;
        esac
        echo "::endgroup::"
        ;;

    Windows* | MINGW* | MSYS*)
        MPI="${MPI:-msmpi}"
        echo "::group::Installing $MPI"
        case $MPI in
            msmpi)
                sdir=$(dirname "${BASH_SOURCE[0]}")
                pwsh "${sdir}\\setup-${MPI}.ps1"
                ;;
            intelmpi)
                setup-win-intel-oneapi-mpi
                setup-win-intel-oneapi-mpi-env
                hydra_service.exe -install
                ;;
            *)
                echo "Unknown MPI implementation:" $MPI
                exit 1
                ;;
        esac
        echo "::endgroup::"
        ;;

    *)
        echo "Unknown OS kernel:" $(uname)
        exit 1
        ;;
esac

echo "mpi=${MPI}" >> $GITHUB_OUTPUT

case $MPI in
    mpich)
        echo "::group::Run mpichversion"
        mpichversion
        echo "::endgroup::"
        ;;
    openmpi)
        echo "::group::Run ompi_info --all"
        ompi_info --all
        echo "::endgroup::"
        ;;
    intelmpi)
        echo "::group::Run impi_info -all"
        ${impi_info:-impi_info} -all
        echo "::endgroup::"
        ;;
esac

if [ $MPI == openmpi ]; then
    openmpi_mca_params=$HOME/.openmpi/mca-params.conf
    mkdir -p $(dirname $openmpi_mca_params)
    echo plm=isolated >> $openmpi_mca_params
    echo rmaps_base_oversubscribe=true >> $openmpi_mca_params
    echo btl_base_warn_component_unused=false >> $openmpi_mca_params
    echo btl_vader_single_copy_mechanism=none >> $openmpi_mca_params
    if [[ $(uname) == Darwin ]]; then
        # open-mpi/ompi#7516
        echo gds=hash >> $openmpi_mca_params
        # open-mpi/ompi#5798
        echo btl_vader_backing_directory=/tmp >> $openmpi_mca_params
    fi
    echo "::group::Configure ${openmpi_mca_params}"
    cat $openmpi_mca_params
    echo "::endgroup::"
fi
