#
# Date created: 2022-03-06
# Author: aradclif
#
#
############################################################################################
#### vfindmax, vfindmin

for (name, f1, fdims) ∈ zip((:vfindmax, :vfindmin), (:_vfindmax, :_vfindmin), (:_vfindmax_dims!, :_vfindmin_dims!))
    @eval function $name(A; dims=nothing)
        dims === nothing && return $f1(A)
        isone(ndims(A)) && (begin vout, iout = $f1(A) end; return [vout], [iout])
        @assert length(dims) == 1
        axes_arg = axes(A)
        axes_out = Base.setindex(axes_arg, length_one_axis(axes_arg[dims]), dims)
        Iout = similar(A, CartesianIndex{ndims(A)}, axes_out)
        Vout = similar(A, axes_out)
        Base.Cartesian.@nif 5 d -> (d ≤ ndims(A) && dims == d) d -> begin
            Rpre = CartesianIndices(ntuple(i -> axes_arg[i], d - 1))
            Rpost = CartesianIndices(ntuple(i -> axes_arg[i + d], ndims(A) - d))
        end d -> begin
            Rpre = CartesianIndices(axes_arg[1:dims-1])
            Rpost = CartesianIndices(axes_arg[dims+1:end])
        end
        $fdims(Vout, Iout, Rpre, 1:size(A, dims), Rpost, A)
    end
    @eval $name(A, ::Colon) = $name(A)
end
for (op, name, init) ∈ zip((:>, :<), (:_vfindmax_dims!, :_vfindmin_dims!), (:typemin, :typemax))
    @eval function $name(Vout, Iout, Rpre, is, Rpost, A)
        s = $init(eltype(A))
        @inbounds for Ipost ∈ Rpost, Ipre ∈ Rpre
            indm = 0
            mval = s
            @turbo for i ∈ is
                newm = $op(A[Ipre, i, Ipost], mval)
                mval = newm ? A[Ipre, i, Ipost] : mval
                indm = newm ? i : indm
            end
            Vout[Ipre, 1, Ipost] = mval
            Iout[Ipre, 1, Ipost] = CartesianIndex(Ipre, indm, Ipost)
        end
        return Vout, Iout
    end
end
for (op, name, init) ∈ zip((:>, :<), (:_vfindmax, :_vfindmin), (:typemin, :typemax))
    @eval function $name(A::AbstractArray{T, N}) where {T, N}
        indm = 0
        mval = $init(T)
        @turbo for i ∈ eachindex(A)
            newm = $op(A[i], mval)
            mval = newm ? A[i] : mval
            indm = newm ? i : indm
        end
        mval, CartesianIndices(A)[indm]
    end
    @eval function $name(A::AbstractVector{T}) where {T}
        indm = 0
        mval = $init(T)
        @turbo for i ∈ eachindex(A)
            newm = $op(A[i], mval)
            mval = newm ? A[i] : mval
            indm = newm ? i : indm
        end
        mval, indm
    end
end


#### vtfindmax, vtfindmin : threaded version
for (name, f1, fdims) ∈ zip((:vtfindmax, :vtfindmin), (:_vtfindmax, :_vtfindmin), (:_vtfindmax_dims!, :_vtfindmin_dims!))
    @eval function $name(A; dims=nothing)
        dims === nothing && return $f1(A)
        isone(ndims(A)) && (begin vout, iout = $f1(A) end; return [vout], [iout])
        @assert length(dims) == 1
        axes_arg = axes(A)
        axes_out = Base.setindex(axes_arg, length_one_axis(axes_arg[dims]), dims)
        Iout = similar(A, CartesianIndex{ndims(A)}, axes_out)
        Vout = similar(A, axes_out)
        Base.Cartesian.@nif 5 d -> (d ≤ ndims(A) && dims == d) d -> begin
            Rpre = CartesianIndices(ntuple(i -> axes_arg[i], d - 1))
            Rpost = CartesianIndices(ntuple(i -> axes_arg[i + d], ndims(A) - d))
        end d -> begin
            Rpre = CartesianIndices(axes_arg[1:dims-1])
            Rpost = CartesianIndices(axes_arg[dims+1:end])
        end
        $fdims(Vout, Iout, Rpre, 1:size(A, dims), Rpost, A)
    end
    @eval $name(A, ::Colon) = $name(A)
end
for (op, name, init) ∈ zip((:>, :<), (:_vfindmax_prepost!, :_vfindmin_prepost!), (:typemin, :typemax))
    @eval function $name(Vout, Iout, Ipre, is, Ipost, A)
        indm = 0
        mval = $init(eltype(A))
        @turbo for i ∈ is
            newm = $op(A[Ipre, i, Ipost], mval)
            mval = newm ? A[Ipre, i, Ipost] : mval
            indm = newm ? i : indm
        end
        Vout[Ipre, 1, Ipost] = mval
        Iout[Ipre, 1, Ipost] = CartesianIndex(Ipre, indm, Ipost)
        return Vout, Iout
    end
end
for (f, name) ∈ zip((:_vfindmax_prepost!, :_vfindmin_prepost!), (:_vtfindmax_dims!, :_vtfindmin_dims!))
    @eval function $name(Vout, Iout, Rpre, is, Rpost, A)
        if length(Rpre) > length(Rpost)
            @batch for Ipre ∈ Rpre, Ipost ∈ Rpost
                $f(Vout, Iout, Ipre, is, Ipost, A)
            end
        else
            @batch for Ipost ∈ Rpost, Ipre ∈ Rpre
                $f(Vout, Iout, Ipre, is, Ipost, A)
            end
        end
        return Vout, Iout
    end
end
for (op, name, init) ∈ zip((:>, :<), (:_vtfindmax, :_vtfindmin), (:typemin, :typemax))
    @eval function $name(A::AbstractArray{T, N}) where {T, N}
        indm = 0
        mval = $init(T)
        @tturbo for i ∈ eachindex(A)
            newm = $op(A[i], mval)
            mval = newm ? A[i] : mval
            indm = newm ? i : indm
        end
        mval, CartesianIndices(A)[indm]
    end
    @eval function $name(A::AbstractVector{T}) where {T}
        indm = 0
        mval = $init(T)
        @tturbo for i ∈ eachindex(A)
            newm = $op(A[i], mval)
            mval = newm ? A[i] : mval
            indm = newm ? i : indm
        end
        mval, indm
    end
end
