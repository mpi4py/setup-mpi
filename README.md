# setup-mpi

Set up your GitHub Actions workflow to use [MPI](https://www.mpi-forum.org/).

# Usage

See [action.yml](action.yml)

Basic:

```yaml
steps:
  - uses: actions/checkout@v2
  - uses: mpi4py/setup-mpi@v1
  - run: mpicc helloworld.c -o helloworld
  - run: mpiexec -n 2 ./helloworld
```

Matrix Testing:

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        mpi: [ 'mpich', 'openmpi' ]
    name: ${{ matrix.mpi }} example
    steps:
      - name: Checkout
      - uses: actions/checkout@v2
      - name: Setup MPI
        uses: mpi4py/setup-mpi@v1
        with:
          mpi: ${{ matrix.mpi }}
      - run: mpicc helloworld.c -o helloworld
      - run: mpiexec -n 2 ./helloworld
```

# Available MPI implementations

* Linux: [MPICH](https://www.mpich.org/) and [Open MPI](https://www.open-mpi.org/) (`apt` install).
* macOS: [MPICH](https://www.mpich.org/) and [Open MPI](https://www.open-mpi.org/) (`brew` install).
* Windows: [Microsoft MPI](https://docs.microsoft.com/en-us/message-passing-interface/microsoft-mpi).
