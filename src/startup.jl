# Functions needed to find libraries
function getlibs()
    libs = ()
    petsc_libs = ENV["JULIA_PETSC_LIBRARY"]

    flags = Libdl.RTLD_LAZY | Libdl.RTLD_DEEPBIND | Libdl.RTLD_GLOBAL

    for petsc_lib in Base.parse_load_path(petsc_libs)
        libs = (libs..., (petsc_lib, flags))
    end
    return libs
end

const libs = getlibs()

function DataTypeFromString(libhdl::Ptr{Cvoid}, name::AbstractString)
    PetscDataTypeFromString_ptr = dlsym(libhdl, :PetscDataTypeFromString)
    dtype_ref = Ref{PetscDataType}()
    found_ref = Ref{PetscBool}()
    @chk ccall(
        PetscDataTypeFromString_ptr,
        PetscErrorCode,
        (Cstring, Ptr{PetscDataType}, Ptr{PetscBool}),
        name,
        dtype_ref,
        found_ref,
    )
    @assert found_ref[] == PETSC_TRUE
    return dtype_ref[]
end
function PetscDataTypeGetSize(libhdl::Ptr{Cvoid}, dtype::PetscDataType)
    PetscDataTypeGetSize_ptr = dlsym(libhdl, :PetscDataTypeGetSize)
    datasize_ref = Ref{Csize_t}()
    @chk ccall(
        PetscDataTypeGetSize_ptr,
        PetscErrorCode,
        (PetscDataType, Ptr{Csize_t}),
        dtype,
        datasize_ref,
    )
    return datasize_ref[]
end

