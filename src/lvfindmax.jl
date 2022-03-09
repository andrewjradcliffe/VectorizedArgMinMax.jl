#
# Date created: 2022-03-08
# Author: aradclif
#
#
############################################################################################
# Re-work of vfindmax.jl

function findmaxbody(N, D)
    body = Expr(:block)
    a = Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...)
    i = ntuple(d -> Symbol(:i_, d), N)
    b = Expr(:ref, :B, ntuple(d -> D[d] == 1 ? 1 : Symbol(:i_, d), N)...)
    c = Expr(:ref, :C, ntuple(d -> D[d] == 1 ? 1 : Symbol(:i_, d), N)...)
    n = Expr(:(=), :n, Expr(:call, :<, b, a))
    m = Expr(:(=), b, Expr(:if, :n, a, b))
    cₐ = Expr(:(=), c, Expr(:if, :n, Expr(:tuple, i...), c))
    push!(body.args, n)
    push!(body.args, m)
    push!(body.args, cₐ)
    body
end
function lvfindmaxbody(N, D)
    body = Expr(:block)
    a = Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...)
    i = ntuple(d -> Symbol(:i_, d), N)
    b = Expr(:ref, :B, ntuple(d -> D[d] == 1 ? 1 : Symbol(:i_, d), N)...)
    c = Expr(:ref, :C, ntuple(d -> D[d] == 1 ? 1 : Symbol(:i_, d), N)...)
    j = Expr(:(=), :j, c)
    v = Expr(:(=), :v, b)
    n = Expr(:(=), :n, Expr(:call, :<, :v, a))
    # m = Expr(:(=), b, Expr(:if, :n, a, b))
    m = Expr(:(=), b, Expr(:call, :ifelse, :n, a, :v))
    sym = i[N]
    l = :($sym - 1)
    for d = (N - 1):-1:1
        sym = i[d]
        l = :($sym - 1 + dims[$d] * $l)
    end
    l = :($l + 1)
    # cₐ = Expr(:(=), c, Expr(:if, :n, l, c))
    cₐ = Expr(:(=), c, Expr(:call, :ifelse, :n, l, :j))
    push!(body.args, j)
    push!(body.args, v)
    push!(body.args, n)
    push!(body.args, m)
    push!(body.args, cₐ)
    body
    # #### A different approach
    # body = Expr(:block)
end
Meta.@dump(rand(Bool) ? 5 : 10)
Meta.@dump((1,2,3))
findmaxbody(N, Dᴮ)
lvfindmaxbody(N, Dᴮ)

# ex = :(j_2 - 1)
# for i = (N - 1):-1:1
#     sym = Symbol(:j_, i)
#     ex = :($sym - 1 + D[$i] * $ex)
# end
# ex = :($ex + 1)

function findmax_quote(A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
    Dᴬ = size(A)
    Dᴮ = ntuple(d -> d ∈ dims ? 1 : Dᴬ[d], N)
    B = fill(typemin(eltype(A)), Dᴮ)
    C = fill(ntuple(d -> 0, N), Dᴮ)
    ls = loopgen(A)
    body = findmaxbody(N, Dᴮ)
    push!(ls.args, body)
    ls
end

A = [1 2 3; 4 5 6]
N = ndims(A)
dims = (1,)
Dᴬ = size(A)
Dᴮ = ntuple(d -> d ∈ dims ? 1 : Dᴬ[d], N)
B = fill(typemin(eltype(A)), Dᴮ)
C = fill(ntuple(d -> 0, N), Dᴮ)

ls = findmax_quote(A, dims)
eval(ls)
findmax(A, dims=dims)

function findmax_quote(N::Int, D)
    ls = loopgen(N)
    body = Expr(:block)
    params = D.parameters
    a = Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...)
    i = ntuple(d -> Symbol(:i_, d), N)
    b = Expr(:ref, :B, ntuple(d -> params[d] == Static.One ? 1 : Symbol(:i_, d), N)...)
    c = Expr(:ref, :C, ntuple(d -> params[d] == Static.One ? 1 : Symbol(:i_, d), N)...)
    n = Expr(:(=), :n, Expr(:call, :<, b, a))
    m = Expr(:(=), b, Expr(:if, :n, a, b))
    cₐ = Expr(:(=), c, Expr(:if, :n, Expr(:tuple, i...), c))
    push!(body.args, n)
    push!(body.args, m)
    push!(body.args, cₐ)
    push!(ls.args, body)
    ls
end

function lvfindmax(A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
    Dᴬ = size(A)
    Dᴮ = ntuple(d -> d ∈ dims ? 1 : Dᴬ[d], N)
    B = fill(typemin(T), Dᴮ)
    C = fill(ntuple(d -> 0, N), Dᴮ)
    Dᴮ′ = ntuple(d -> StaticInt(Dᴮ[d]), N)
    _lvfindmax!(B, C, A, Dᴮ′)
    B, CartesianIndex.(C)
end

@generated function _lvfindmax!(B::AbstractArray{T, N}, C::AbstractArray{S, N},
                                A::AbstractArray{T, N}, dims::D) where {T, N, S, D}
    findmax_quote(N, D)
end

@timev lvfindmax(A, dims)

function findmax_quote2(N::Int, D)
    ls = loopgen(N)
    body = Expr(:block)
    params = D.parameters
    a = Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...)
    i = ntuple(d -> Symbol(:i_, d), N)
    b = Expr(:ref, :B, ntuple(d -> params[d] == Static.One ? 1 : Symbol(:i_, d), N)...)
    c = Expr(:ref, :C, ntuple(d -> params[d] == Static.One ? 1 : Symbol(:i_, d), N)...)
    # n = Expr(:(=), :n, Expr(:call, :<, b, a))
    # m = Expr(:(=), b, Expr(:call, :ifelse, :n, a, b))
    # sym = i[N]
    # l = :($sym - 1)
    # for d = (N - 1):-1:1
    #     sym = i[d]
    #     l = :($sym - 1 + dims[$d] * $l)
    # end
    # l = :($l + 1)
    # cₐ = Expr(:(=), c, Expr(:call, :ifelse, :n, l, c))
    # push!(body.args, n)
    # push!(body.args, m)
    # push!(body.args, cₐ)
    # push!(ls.args, body)
    j = Expr(:(=), :j, c)
    v = Expr(:(=), :v, b)
    n = Expr(:(=), :n, Expr(:call, :<, :v, a))
    # m = Expr(:(=), b, Expr(:if, :n, a, b))
    m = Expr(:(=), b, Expr(:call, :ifelse, :n, a, :v))
    sym = i[N]
    l = :($sym - 1)
    for d = (N - 1):-1:1
        sym = i[d]
        l = :($sym - 1 + static_dims[$d] * $l)
    end
    l = :($l + 1)
    # cₐ = Expr(:(=), c, Expr(:if, :n, l, c))
    cₐ = Expr(:(=), c, Expr(:call, :ifelse, :n, l, :j))
    push!(body.args, j)
    push!(body.args, v)
    push!(body.args, n)
    push!(body.args, m)
    push!(body.args, cₐ)
    push!(ls.args, body)
    return quote
        static_dims::Vector{Int} = collect(size(A))
        @turbo $ls
        return B, C
    end
end

function lvfindmax2(A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
    Dᴬ = size(A)
    Dᴮ = ntuple(d -> d ∈ dims ? 1 : Dᴬ[d], N)
    B = fill(typemin(T), Dᴮ)
    C = zeros(Int, Dᴮ)
    Dᴮ′ = ntuple(d -> StaticInt(Dᴮ[d]), N)
    _lvfindmax2!(B, C, A, Dᴮ′)
    B, CartesianIndices(A)[C]
end

@generated function _lvfindmax2!(B::AbstractArray{T, N}, C::AbstractArray{S, N},
                                 A::AbstractArray{T, N}, dims::D) where {T, N, S, D}
    findmax_quote2(N, D)
end

AA = rand(100, 10, 10);

@timev lvfindmax2(A, dims)
Meta.parse("true ? 5 : 10")

A = rand(10,10);
dims = (1,)

lvfindmax2(A, dims) == lvfindmax(A, dims) == findmax(A, dims=dims)
ls = findmax_quote2(N, typeof(Dᴮ′))
Meta.@dump(ifelse(x > 0, log(x), inv(x)))

function findmaxturbo!(B, C, A::AbstractMatrix{T}, static_dims) where {T}
    v = zero(T)
    j = 0
    l = ((1 - 1) + static_dims[1] * (1 - 1)) + 1
    ii = 1
    @turbo for i_2 = axes(A, 2), i_1 = axes(A, 1)
        v = B[ii, i_2]
        j = C[ii, i_2]
        # l = ((i_1 - 1) + static_dims[1] * (i_2 - 1)) + 1
        l = i_1 - 1 + static_dims[1] * (i_2 - 1) + 1
        newm = A[i_1, i_2] > B[ii, i_2]
        B[ii, i_2] = newm ? A[i_1, i_2] : v
        C[ii, i_2] = newm ? l : j
    end
    B, C
end
function findmaxturbo(A::AbstractMatrix{T}) where {T}
    B = fill(typemin(eltype(A)), Base.setindex(size(A), 1, 1))
    C = ones(Int, Base.setindex(size(A), 1, 1))
    static_dims = collect(size(A))
    findmaxturbo!(B, C, A, static_dims)
    B, CartesianIndices(A)[C]
end
A = rand(2, 3)
static_dims = size(A)
@timev findmaxturbo6!(B, C, A, collect(size(A)))
findmaxturbo(A)
using LoopVectorization
LoopVectorization.check_args(B, C, A)
