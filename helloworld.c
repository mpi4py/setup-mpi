#include <mpi.h>
#include <stdio.h>

int main(int argc, char *argv[])
{
  int size, rank, len;
  char name[MPI_MAX_PROCESSOR_NAME];

  MPI_Init(&argc, &argv);
  MPI_Comm_size(MPI_COMM_WORLD, &size);
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);
  MPI_Get_processor_name(name, &len);

  if (rank != 0)
    MPI_Recv(name, 0 , MPI_BYTE, rank-1, 0, MPI_COMM_WORLD, MPI_STATUS_IGNORE);

  printf("Hello, World! I am process %d of %d on %s.\n", rank, size, name);

  if (rank != size - 1)
    MPI_Send(name, 0 , MPI_BYTE, rank+1, 0, MPI_COMM_WORLD);

  MPI_Finalize();
  return 0;
}
