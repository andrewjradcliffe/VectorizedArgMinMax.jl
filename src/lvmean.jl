#
# Date created: 2022-03-09
# Author: aradclif
#
#
############################################################################################
# Building on lvreduce.jl

# function smul_inplacebody(N::Int)
#     body = Expr(:block)
#     a = Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...)
#     e = Expr(:(=), a, Expr(:call, :*, a, :x))
#     push!(body.args, e)
#     body
# end

function transform_inplacebody(f, N::Int)
    body = Expr(:block)
    a = Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...)
    e = Expr(:(=), a, Expr(:call, Symbol(f), a))
    push!(body.args, e)
    body
end

# function smul_inplace_quote(N::Int)
#     ls = loopgen(N)
#     body = smul_inplacebody(N)
#     push!(ls.args, body)
#     return quote
#         @turbo $ls
#         return A
#     end
# end
# @generated function smul!(A::AbstractArray{T, N}, x::T) where {T, N}
#     smul_inplace_quote(N)
# end

function smul!(A::AbstractArray{T, N}, x::T) where {T, N}
    @turbo for i ∈ eachindex(A)
        A[i] *= x
    end
    A
end

function lvmean(A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
    B = lvsum(A, dims=dims)
    Dᴬ = size(A)
    denom = one(eltype(B))
    for d ∈ eachindex(Dᴬ)
        denom = d ∈ dims ? denom * Dᴬ[d] : denom
    end
    x = inv(denom)
    smul!(B, x)
    B
end
lvmean(A::AbstractArray{T, N}, dims::Int) where {T, N} = lvmean(A, (dims,))
lvmean(A::AbstractArray{T, N}; dims=:) where {T, N} = lvmean(A, dims)
lvmean(A::AbstractArray{T, N}) where {T, N} = lvmean1(A)
lvmean(A::AbstractArray{T, N}, ::Colon) where {T, N} = lvmean1(A)

function lvmean1(A::AbstractArray{T, N}) where {T, N}
    s = zero(Base.promote_op(+, T, Int))
    @turbo for i ∈ eachindex(A)
        s += A[i]
    end
    s / length(A)
end

################
function lvmean(f, A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
    B = lvsum(f, A, dims=dims)
    Dᴬ = size(A)
    denom = one(eltype(B))
    for d ∈ eachindex(Dᴬ)
        denom = d ∈ dims ? denom * Dᴬ[d] : denom
    end
    x = inv(denom)
    smul!(B, x)
    B
end
lvmean(f, A::AbstractArray{T, N}, dims::Int) where {T, N} = lvmean(f, A, (dims,))
lvmean(f, A::AbstractArray{T, N}; dims=:) where {T, N} = lvmean(f, A, dims)
lvmean(f, A::AbstractArray{T, N}) where {T, N} = lvmean1(f, A)
lvmean(f, A::AbstractArray{T, N}, ::Colon) where {T, N} = lvmean1(f, A)

@generated function lvmean1(f::F, A::AbstractArray{T, N}) where {F, T, N}
    f = F.instance
    Tₒ = Base.promote_op(+, Base.promote_op(f, T), Int)
    quote
        s = zero($Tₒ)
        @turbo for i ∈ eachindex(A)
            s += $f(A[i])
        end
        s / length(A)
    end
end
