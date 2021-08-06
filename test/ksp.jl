using Test
using MPI
MPI.Initialized() || MPI.Init()
using PETSc
using LinearAlgebra: mul!
using SparseArrays: spdiagm

@testset "KSP" begin
    comm = MPI.COMM_WORLD
    mpisize = MPI.Comm_size(comm)
    mpirank = MPI.Comm_rank(comm)

    for petsclib in PETSc.petsclibs
        PETSc.initialize(petsclib)
        PetscScalar = petsclib.PetscScalar
        PetscInt = petsclib.PetscInt

        loc_num_rows = 10
        loc_num_cols = 10
        diag_nonzeros = 3
        off_diag_non_zeros = 3

        A = PETSc.MatAIJ(
            petsclib,
            comm,
            loc_num_rows,
            loc_num_cols,
            diag_nonzeros,
            off_diag_non_zeros,
        )

        # Get compatible vectors
        (x, b) = PETSc.createvecs(A)

        row_rng = PETSc.ownershiprange(A, false)
        for i in row_rng
            if i == 0
                vals = [-2, 1]
                row0idxs = [i]
                col0idxs = [i, i + 1]
            elseif i == mpisize * loc_num_rows - 1
                vals = [-2, 1]
                row0idxs = [i]
                col0idxs = [i, i - 1]
            else
                vals = [1, -2, 1]
                row0idxs = [i]
                col0idxs = [i - 1, i, i + 1]
            end
            PETSc.setvalues!(
                A,
                PetscInt.(row0idxs),
                PetscInt.(col0idxs),
                PetscScalar.(vals),
            )
            x[i + 1] = (i + 1)^3
        end
        PETSc.assemble!(A)
        PETSc.assemble!(x)

        mul!(b, A, x)
        y = similar(x)

        ksp = PETSc.KSP(A; ksp_rtol = 1e-16, pc_type = "jacobi")
        PETSc.solve!(y, ksp, b)
        PETSc.withlocalarray!(x, y) do x, y
            @test x ≈ y
        end
        PETSc.destroy(x)

        x = ksp \ b
        PETSc.withlocalarray!(x, y) do x, y
            @test x ≈ y
        end
        PETSc.destroy(x)

        # PETSc.destroy(ksp)
        PETSc.destroy(A)
        PETSc.destroy(y)
        PETSc.destroy(b)
        PETSc.finalize(petsclib)
    end
end

if MPI.Comm_rank(MPI.COMM_WORLD) == 0
    @testset "KSP with SparseMatrixCSC" begin
        comm = MPI.COMM_SELF
        n = 10

        for petsclib in PETSc.petsclibs
            PETSc.initialize(petsclib)
            PetscScalar = petsclib.PetscScalar
            PetscInt = petsclib.PetscInt

            A = spdiagm(
                -1 => ones(PetscScalar, n - 1),
                0 => -2ones(PetscScalar, n),
                1 => ones(PetscScalar, n - 1),
            )

            ksp = PETSc.KSP(petsclib, A)
            b = rand(PetscScalar, 10)
            @test ksp \ b ≈ Matrix(A) \ b
            PETSc.destroy(ksp)

            if PetscInt == Int64
                ksp = PETSc.KSP(A)
                @test ksp \ b ≈ Matrix(A) \ b
                PETSc.destroy(ksp)
            end
            PETSc.finalize(petsclib)
        end
    end
else
    # Even though only rank 0 is running the test all ranks need to initialize
    # PETSc
    for petsclib in PETSc.petsclibs
        PETSc.initialize(petsclib)
        PETSc.finalize(petsclib)
    end
end
