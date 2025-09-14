#!/bin/bash
set -eu

MPI=$(echo "${1:-}" | tr '[:upper:]' '[:lower:]' | tr -d '-')

case $MPI in
    mpich)
        MPI=mpich
        ;;
    ompi | openmpi)
        MPI=openmpi
        ;;
    impi | intelmpi | intel)
        MPI=intelmpi
        ;;
    msmpi | microsoftmpi | microsoft)
        MPI=msmpi
        ;;
esac

sudo () {
    [ $(id -u) -eq 0 ] || set -- command sudo "$@"
    "$@"
}

hotfix-apt-ubuntu-noble-mpich() {
    grep -q 'ID=ubuntu' /etc/os-release || return 0
    grep -q 'VERSION_CODENAME=noble' /etc/os-release || return 0
    command -v curl > /dev/null || apt install -y -q curl
    echo "Hotfix broken MPICH package in Ubuntu 24.04 LTS"
    echo "https://bugs.launchpad.net/ubuntu/+source/mpich/+bug/2072338"
    case "$(arch)" in
        aarch64) arch=arm64 repo=https://ports.ubuntu.com/ubuntu-ports;;
        x86_64)  arch=amd64 repo=https://archive.ubuntu.com/ubuntu;;
    esac
    libucx0=libucx0_1.18.1+ds-2_$arch.deb
    libmpich12=libmpich12_4.2.1-5_$arch.deb
    curl -sSO $repo/pool/universe/u/ucx/$libucx0
    curl -sSO $repo/pool/universe/m/mpich/$libmpich12
    tmpdir=$(mktemp -d)
    dpkg-deb -x $libucx0 $tmpdir
    dpkg-deb -x $libmpich12 $tmpdir
    libdir=/usr/lib/$(arch)-linux-gnu
    sudo cp -a $tmpdir$libdir/ucx $libdir
    sudo cp -a $tmpdir$libdir/libuc[mpst]*.so.0.*.* $libdir
    sudo cp -a $tmpdir$libdir/libuc[mpst]*.so.0 $libdir
    sudo cp -a $tmpdir$libdir/libmpi*.so.12.*.* $libdir
    sudo cp -a $tmpdir$libdir/libmpi*.so.12 $libdir
    sudo ldconfig
    rm -rf $tmpdir $libucx0 $libmpich12
}

setup-apt-intel-oneapi () {
    # ensure the required packages are installed
    sudo apt update
    sudo apt install -y -q ca-certificates curl gnupg procps
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
    hash=18932                                version=2021.7.0  build=9549
    hash=19011                                version=2021.7.1  build=15761
    hash=19160                                version=2021.8.0  build=25543
    hash=c11b9bf0-2527-4925-950d-186dba31fb40 version=2021.9.0  build=43421
    hash=4f7f4251-7781-446f-89ac-c777dacb766f version=2021.10.0 build=49373
    hash=b7596581-64db-4820-bcfe-74ad9f5ec657 version=2021.11.0 build=49512
    hash=fab706bb-ca1e-4cc9-b76a-a12df3cc984e version=2021.12.0 build=539
    hash=a3a49de8-dc40-4387-9784-5227fccb6caa version=2021.12.1 build=7
    hash=e20e3226-9264-41a0-bc18-6026d297e10d version=2021.13.0 build=717
    hash=ea625b1d-8a8a-4bd5-b31d-7ed55af45994 version=2021.13.1 build=768
    hash=44400f77-51cb-4f15-8424-0e11eeb41832 version=2021.14.0 build=785
    hash=e9f49ab3-babd-4753-a155-ceeb87e36674 version=2021.14.1 build=8
    hash=29e1f37b-f7c7-4cd6-988c-6ddf80aadf6a version=2021.14.2 build=901
    hash=edf463a6-a6ad-43d2-a588-daa2e30f8735 version=2021.15.0 build=496
    hash=c7b82926-172a-4943-8612-fcbc4625b17a version=2021.16.0 build=441
    hash=ab55e200-0293-4537-af1f-a96b309bec1a version=2021.16.1 build=805
    baseurl=https://registrationcenter-download.intel.com
    subpath=akdlm/IRC_NAS/$hash
    if test $version \< 2021.14.0; then
        package=w_mpi_oneapi_p_${version}.${build}_offline.exe
    else
        package=intel-mpi-${version}.${build}_offline.exe
    fi
    set -x
    curl -sO $baseurl/$subpath/$package
    ./$package -s -a --silent --eula accept
    set +x
}

setup-win-intel-oneapi-mpi-env () {
    ONEAPI_ROOT="C:\Program Files (x86)\Intel\oneAPI"
    I_MPI_ROOT="${ONEAPI_ROOT}\mpi\latest"
    I_MPI_OFI_LIBRARY_INTERNAL="1"
    mpibindir="${I_MPI_ROOT}\bin"
    ofibindir="${I_MPI_ROOT}\opt\mpi\libfabric\bin"

    echo "ONEAPI_ROOT=${ONEAPI_ROOT}" >> $GITHUB_ENV
    echo "I_MPI_ROOT=${I_MPI_ROOT}" >> $GITHUB_ENV
    echo "I_MPI_OFI_LIBRARY_INTERNAL=${I_MPI_OFI_LIBRARY_INTERNAL}" >> $GITHUB_ENV
    echo "${mpibindir}" >> $GITHUB_PATH
    echo "${ofibindir}" >> $GITHUB_PATH

    export PATH="$(cygpath -u "${mpibindir}"):$PATH"
    export PATH="$(cygpath -u "${ofibindir}"):$PATH"
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
                hotfix-apt-ubuntu-noble-mpich
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
        brew unlink mpich   > /dev/null 2>&1 || true
        brew unlink openmpi > /dev/null 2>&1 || true
        case $MPI in
            mpich|openmpi)
                if brew list $MPI > /dev/null 2>&1; then
                    brew link $MPI
                else
                    brew install $MPI
                fi
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
    rm -f $openmpi_mca_params
    echo btl=tcp,self >> $openmpi_mca_params
    echo mpi_yield_when_idle=true >> $openmpi_mca_params
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
    prte_mca_params=$HOME/.prte/mca-params.conf
    mkdir -p $(dirname $prte_mca_params)
    rm -f $prte_mca_params
    echo rmaps_default_mapping_policy = :oversubscribe >> $prte_mca_params
    echo "::group::Configure ${prte_mca_params}"
    cat $prte_mca_params
    echo "::endgroup::"
fi
