#!/bin/bash
set -eu

MPI=$(echo "${1:-}" | tr '[:upper:]' '[:lower:]')

case $(uname) in

    Linux)
        MPI="${MPI:-mpich}"
        echo "Installing $MPI with apt"
        case $MPI in
            mpich)
                sudo apt install -y -q mpich libmpich-dev
                ;;
            openmpi)
                sudo apt install -y -q openmpi-bin libopenmpi-dev
                ;;
            *)
                echo "Unknown MPI implementation:" $MPI
                exit 1
                ;;
        esac
        ;;

    Darwin)
        MPI="${MPI:-mpich}"
        echo "Installing $MPI with brew"
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
        ;;

    Windows* | MINGW* | MSYS*)
        MPI="${MPI:-msmpi}"
        echo "Installing $MPI"
        case $MPI in
            msmpi)
                sdir=$(dirname "${BASH_SOURCE[0]}")
                pwsh "${sdir}\\setup-${MPI}.ps1"
                ;;
            *)
                echo "Unknown MPI implementation:" $MPI
                exit 1
                ;;
        esac
        ;;

    *)
        echo "Unknown OS kernel:" $(uname)
        exit 1
        ;;
esac

echo "::set-output name=mpi::${MPI}"
