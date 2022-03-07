#
# Date created: 2022-03-06
# Author: aradclif
#
#
############################################################################################
using Polyester
using LoopVectorization
import LoopVectorization.length_one_axis


#### Clean working draft
# function vargmax(A; dims=nothing)
#     dims === nothing && return _vargmax(A)
#     isone(ndims(A)) && return [_vargmax(A)]
#     @assert length(dims) == 1
#     axes_arg = axes(A)
#     axes_out = Base.setindex(axes_arg, length_one_axis(axes_arg[dims]), dims)
#     out = similar(A, CartesianIndex{ndims(A)}, axes_out)
#     Base.Cartesian.@nif 5 d -> (d ≤ ndims(A) && dims == d) d -> begin
#         Rpre = CartesianIndices(ntuple(i -> axes_arg[i], d - 1))
#         Rpost = CartesianIndices(ntuple(i -> axes_arg[i + d], ndims(A) - d))
#     end d -> begin
#         Rpre = CartesianIndices(axes_arg[1:dims-1])
#         Rpost = CartesianIndices(axes_arg[dims+1:end])
#     end
#     _vargmax_dims!(out, Rpre, 1:size(A, dims), Rpost, A)
# end

# function _vargmax_dims!(out, Rpre, is, Rpost, A)
#     s = typemin(eltype(A))
#     for Ipost ∈ Rpost, Ipre ∈ Rpre
#         indmax = 0
#         maxval = s
#         @turbo for i ∈ is
#             newmax = A[Ipre, i, Ipost] > maxval
#             maxval = newmax ? A[Ipre, i, Ipost] : maxval
#             indmax = newmax ? i : indmax
#         end
#         out[Ipre, 1, Ipost] = CartesianIndex(Ipre, indmax, Ipost)
#     end
#     return out
# end

# function _vargmax_dims_post!(out, is, Rpost, A)
#     s = typemin(eltype(A))
#     for j ∈ eachindex(Rpost) #Ipost ∈ Rpost
#         indm = 0
#         mval = s
#         Ipost = Rpost[j]
#         for i ∈ is
#             newm = >(A[i, Ipost], mval)
#             mval = newm ? A[i, Ipost] : mval
#             indm = newm ? i : indm
#         end
#         out[1, Ipost] = CartesianIndex(indm, Ipost)
#     end
#     out
# end

# function _vargmax_dims_ipost!(out, Rpre, is, Ipost, A)
#     s = typemin(eltype(A))
#     for Ipre ∈ Rpre
#         indm = 0
#         mval = s
#         @turbo for i ∈ is
#             newm = >(A[Ipre, i, Ipost], mval) #A[Ipre, i, Ipost] > maxval
#             mval = newm ? A[Ipre, i, Ipost] : mval
#             indm = newm ? i : indm
#         end
#         out[Ipre, 1, Ipost] = CartesianIndex(Ipre, indm, Ipost)
#     end
#     return out
# end

# function _vargmax_prepost!(out, Ipre, is, Ipost, A)
#     indm = 0
#     mval = typemin(eltype(A))
#     @turbo for i ∈ is
#         newm = >(A[Ipre, i, Ipost], mval) #A[Ipre, i, Ipost] > maxval
#         mval = newm ? A[Ipre, i, Ipost] : mval
#         indm = newm ? i : indm
#     end
#     out[Ipre, 1, Ipost] = CartesianIndex(Ipre, indm, Ipost)
# end

# function _vargmax(A::AbstractArray{T, N}) where {T, N}
#     indmax = 0
#     maxval = typemin(T)
#     @turbo for i ∈ eachindex(A)
#         newmax = A[i] > maxval
#         maxval = newmax ? A[i] : maxval
#         indmax = newmax ? i : indmax
#     end
#     CartesianIndices(A)[indmax]
# end

# # Not ideal, but makes return type stable
# function _vargmax(A::AbstractVector{T}) where {T}
#     indmax = 0
#     maxval = typemin(T)
#     @turbo for i ∈ eachindex(A)
#         newmax = >(A[i], maxval) #A[i] $op maxval
#         maxval = newmax ? A[i] : maxval
#         indmax = newmax ? i : indmax
#     end
#     indmax
# end

# # needs customization analogous to vmap, vmapreduce
# function vargmax(f, A::AbstractArray{T, N}) where {T, N}
#     indmax = 0
#     maxval = typemin(T)
#     @turbo for i ∈ eachindex(A)
#         φ = f(A[i])
#         newmax = >(ϕ, maxval)
#         maxval = newmax ? φ : maxval
#         indmax = newmax ? i : indmax
#     end
#     maxval, CartesianIndices(A)[indmax]
# end
# function vargmax(f, A::AbstractVector{T}) where {T}
#     indmax = 0
#     maxval = typemin(T)
#     @turbo for i ∈ eachindex(A)
#         φ = f(A[i])
#         newmax = >(ϕ, maxval)
#         maxval = newmax ? φ : maxval
#         indmax = newmax ? i : indmax
#     end
#     maxval, indmax
# end

# # # In fact, this is more than the Base findmax provides. It simply returns:
# # (A[argmax(A, dims)], argmax(A, dims))
# function vfindmax(A; dims=nothing)
#     dims === nothing && return _vfindmax(A)
#     isone(ndims(A)) && (begin vout, iout = _vfindmax(A) end; return [vout], [iout])
#     @assert length(dims) == 1
#     axes_arg = axes(A)
#     axes_out = Base.setindex(axes_arg, length_one_axis(axes_arg[dims]), dims)
#     Iout = similar(A, CartesianIndex{ndims(A)}, axes_out)
#     Vout = similar(A, axes_out)
#     Base.Cartesian.@nif 5 d -> (d ≤ ndims(A) && dims == d) d -> begin
#         Rpre = CartesianIndices(ntuple(i -> axes_arg[i], d - 1))
#         Rpost = CartesianIndices(ntuple(i -> axes_arg[i + d], ndims(A) - d))
#     end d -> begin
#         Rpre = CartesianIndices(axes_arg[1:dims-1])
#         Rpost = CartesianIndices(axes_arg[dims+1:end])
#     end
#     _vfindmax_dims!(Vout, Iout, Rpre, 1:size(A, dims), Rpost, A)
# end

# function _vfindmax_dims!(Vout, Iout, Rpre, is, Rpost, A)
#     s = typemin(eltype(A))
#     for Ipost ∈ Rpost, Ipre ∈ Rpre
#         indmax = 0
#         maxval = s
#         @turbo for i ∈ is
#             newmax = >(A[Ipre, i, Ipost], maxval)
#             maxval = newmax ? A[Ipre, i, Ipost] : maxval
#             indmax = newmax ? i : indmax
#         end
#         Vout[Ipre, 1, Ipost] = maxval
#         Iout[Ipre, 1, Ipost] = CartesianIndex(Ipre, indmax, Ipost)
#     end
#     return Vout, Iout
# end

# function _vfindmax(A::AbstractArray{T, N}) where {T, N}
#     indmax = 0
#     maxval = typemin(T)
#     @turbo for i ∈ eachindex(A)
#         newmax = >(A[i], maxval)
#         maxval = newmax ? A[i] : maxval
#         indmax = newmax ? i : indmax
#     end
#     maxval, CartesianIndices(A)[indmax]
# end
# function _vfindmax(A::AbstractVector{T}) where {T}
#     indmax = 0
#     maxval = typemin(T)
#     @turbo for i ∈ eachindex(A)
#         newmax = >(A[i], maxval)
#         maxval = newmax ? A[i] : maxval
#         indmax = newmax ? i : indmax
#     end
#     maxval, indmax
# end

# # Simpler, but not as efficient
# function vfindmax(A; dims=nothing)
#     dims === nothing && return _vfindmax(A)
#     @assert length(dims) == 1
#     Imax = vargmax(A, dims)
#     A[Imax], Imax
# end
# function _vfindmax(A::AbstractArray)
#     Imax = vargmax(A)
#     A[Imax], Imax
# end


#### vargmax, vargmin

for (name, f1, fdims) ∈ zip((:vargmax, :vargmin), (:_vargmax, :_vargmin), (:_vargmax_dims!, :_vargmin_dims!))
    @eval function $name(A; dims=nothing)
        dims === nothing && return $f1(A)
        isone(ndims(A)) && return [$f1(A)]
        @assert length(dims) == 1
        axes_arg = axes(A)
        axes_out = Base.setindex(axes_arg, length_one_axis(axes_arg[dims]), dims)
        out = similar(A, CartesianIndex{ndims(A)}, axes_out)
        Base.Cartesian.@nif 5 d -> (d ≤ ndims(A) && dims == d) d -> begin
            Rpre = CartesianIndices(ntuple(i -> axes_arg[i], d - 1))
            Rpost = CartesianIndices(ntuple(i -> axes_arg[i + d], ndims(A) - d))
        end d -> begin
            Rpre = CartesianIndices(axes_arg[1:dims-1])
            Rpost = CartesianIndices(axes_arg[dims+1:end])
        end
        $fdims(out, Rpre, 1:size(A, dims), Rpost, A)
    end
    @eval $name(A, ::Colon) = $name(A)
    # @eval $name(A; dims::Colon) = $name(A)
    # A neat idea, but poor performance due to much memory allocation
    # @eval function $name(A::AbstractArray, region::NTuple{N, Int}) where {N}
    #     if N == 1
    #         return $name(A, dims=region[1])
    #     elseif N == 2
    #         Iout1 = $name(A, dims=region[1])
    #         Iout2 = $name(A[Iout1], dims=region[2])
    #         return Iout1[Iout2]
    #     else
    #         I = $name(A, dims=region[1])
    #         for d = 2:N
    #             Ĩ = $name(A[I], dims=region[d])
    #             I = I[Ĩ]
    #         end
    #         return I
    #     end
    # end
end
for (op, name, init) ∈ zip((:>, :<), (:_vargmax_dims!, :_vargmin_dims!), (:typemin, :typemax))
    @eval function $name(out, Rpre, is, Rpost, A)
        s = $init(eltype(A))
        @inbounds for Ipost ∈ Rpost, Ipre ∈ Rpre
            indm = 0
            mval = s
            @turbo for i ∈ is
                newm = $op(A[Ipre, i, Ipost], mval)
                mval = newm ? A[Ipre, i, Ipost] : mval
                indm = newm ? i : indm
            end
            out[Ipre, 1, Ipost] = CartesianIndex(Ipre, indm, Ipost)
        end
        return out
    end
end
for (op, name, init) ∈ zip((:>, :<), (:_vargmax, :_vargmin), (:typemin, :typemax))
    @eval function $name(A::AbstractArray{T, N}) where {T, N}
        indm = 0
        mval = $init(T)
        @turbo for i ∈ eachindex(A)
            newm = $op(A[i], mval)
            mval = newm ? A[i] : mval
            indm = newm ? i : indm
        end
        # just the linear indm is nice, but one actually wants:
        CartesianIndices(A)[indm]
    end
    # Not ideal, but makes return type stable
    @eval function $name(A::AbstractVector{T}) where {T}
        indm = 0
        mval = $init(T)
        @turbo for i ∈ eachindex(A)
            newm = $op(A[i], mval) #A[i] $op maxval
            mval = newm ? A[i] : mval
            indm = newm ? i : indm
        end
        indm
    end
end

#### vtargmax, vtargmin : threaded version
for (name, f1, fdims) ∈ zip((:vtargmax, :vtargmin), (:_vtargmax, :_vtargmin), (:_vtargmax_dims!, :_vtargmin_dims!))
    @eval function $name(A; dims=nothing)
        dims === nothing && return $f1(A)
        isone(ndims(A)) && return [$f1(A)]
        @assert length(dims) == 1
        axes_arg = axes(A)
        axes_out = Base.setindex(axes_arg, length_one_axis(axes_arg[dims]), dims)
        out = similar(A, CartesianIndex{ndims(A)}, axes_out)
        Base.Cartesian.@nif 5 d -> (d ≤ ndims(A) && dims == d) d -> begin
            Rpre = CartesianIndices(ntuple(i -> axes_arg[i], d - 1))
            Rpost = CartesianIndices(ntuple(i -> axes_arg[i + d], ndims(A) - d))
        end d -> begin
            Rpre = CartesianIndices(axes_arg[1:dims-1])
            Rpost = CartesianIndices(axes_arg[dims+1:end])
        end
        $fdims(out, Rpre, 1:size(A, dims), Rpost, A)
    end
    @eval $name(A, ::Colon) = $name(A)
end
for (op, name, init) ∈ zip((:>, :<), (:_vargmax_prepost!, :_vargmin_prepost!), (:typemin, :typemax))
    @eval function $name(out, Ipre, is, Ipost, A)
        indm = 0
        mval = $init(eltype(A))
        @turbo for i ∈ is
            newm = $op(A[Ipre, i, Ipost], mval)
            mval = newm ? A[Ipre, i, Ipost] : mval
            indm = newm ? i : indm
        end
        out[Ipre, 1, Ipost] = CartesianIndex(Ipre, indm, Ipost)
        return out
    end
end
for (f, name) ∈ zip((:_vargmax_prepost!, :_vargmin_prepost!), (:_vtargmax_dims!, :_vtargmin_dims!))
    @eval function $name(out, Rpre, is, Rpost, A)
        if length(Rpre) > length(Rpost)
            @batch for Ipre ∈ Rpre, Ipost ∈ Rpost
                $f(out, Ipre, is, Ipost, A)
            end
        else
            @batch for Ipost ∈ Rpost, Ipre ∈ Rpre
                $f(out, Ipre, is, Ipost, A)
            end
        end
        return out
    end
end
for (op, name, init) ∈ zip((:>, :<), (:_vtargmax, :_vtargmin), (:typemin, :typemax))
    @eval function $name(A::AbstractArray{T, N}) where {T, N}
        indm = 0
        mval = $init(T)
        @tturbo for i ∈ eachindex(A)
            newm = $op(A[i], mval)
            mval = newm ? A[i] : mval
            indm = newm ? i : indm
        end
        CartesianIndices(A)[indm]
    end
    @eval function $name(A::AbstractVector{T}) where {T}
        indm = 0
        mval = $init(T)
        @tturbo for i ∈ eachindex(A)
            newm = $op(A[i], mval)
            mval = newm ? A[i] : mval
            indm = newm ? i : indm
        end
        indm
    end
end

n = 100
A = collect(reshape(1:24, 4, 3, 2))
A = rand(n, n, n);
A = rand(n, n, n, n, n, n);
n = 10
A = rand(n^3, n^2, n);

argmax(A) == vargmax(A)
argmax(A, dims=1) == vargmax(A, dims=1)
argmax(A, dims=2) == vargmax(A, dims=2)
argmax(A, dims=3) == vargmax(A, dims=3)
# @code_warntype vargmax(A, 2)
# @code_warntype _vargmax_dims!(out, Rpre, 1:size(A, dims), Rpost, A)
@benchmark argmax(A)
@benchmark vargmax(A)
@benchmark vtargmax(A)
@benchmark argmax(A, dims=1)
@benchmark vargmax(A, dims=1)
@benchmark argmax(A, dims=2)
@benchmark vargmax(A, dims=2)
@benchmark argmax(A, dims=3)
@benchmark vargmax(A, dims=3)
@benchmark vtargmax(A, dims=3)

# @benchmark _vargmax_dims!(out, Rpre, 1:size(A, dims), Rpost, A)
# @benchmark _vargmax_dims2!(out, Rpre, 1:size(A, dims), Rpost, A)
# @benchmark _tvargmax_dims!(out, Rpre, 1:size(A, dims), Rpost, A)

findmax(A) == vfindmax(A)
findmax(A, dims=1) == vfindmax(A, dims=1)
findmax(A, dims=2) == vfindmax(A, dims=2)

@benchmark findmax(A)
@benchmark vfindmax(A)
@benchmark findmax(A, dims=1)
@benchmark vfindmax(A, dims=1)
@benchmark findmax(A, dims=2)
@benchmark vfindmax(A, dims=2)
@benchmark findmax(A, dims=3)
@benchmark vfindmax(A, dims=3)
@benchmark vfindmaxt(A, dims=3)
