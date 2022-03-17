#
# Date created: 2022-03-16
# Author: aradclif
#
#
############################################################################################
function findmax_loops(N::Int, D)
    b4 = preexpr2(:typemin)
    inner = innerloop(N, D)
    push!(inner.args, maxblock3(N, D))
    push!(b4.args, inner)
    push!(b4.args, postexpr3(N, D).args...)
    outer = outerloop(N, D)
    push!(outer.args, b4)
    outer
end
function findmax_loops_innerturbo(N::Int, D, multithreaded::Bool)
    b4 = preexpr2(:typemin)
    inner = innerloop(N, D)
    push!(inner.args, maxblock3(N, D))
    push!(b4.args, Expr(:macrocall, multithreaded ? Symbol("@tturbo") : Symbol("@turbo"), (), inner))
    push!(b4.args, postexpr3(N, D).args...)
    outer = outerloop(N, D)
    push!(outer.args, b4)
    outer
end

function findmax_quote(N::Int, D)
    b1 = sizeblock(N)
    b2 = Expr(:block, ntuple(d -> offsetk(d + 2), N - 2)...)
    b3 = Expr(:block, totaloffsetraw(N), Expr(:(=), :Dstar, Expr(:call, :-, :Dstar)))
    outer = findmax_loops(N, D)
    return quote
        $b1
        $b2
        $b3
        $outer
    end
end
function ivfindmax_quote(N::Int, D)
    b1 = sizeblock(N)
    b2 = Expr(:block, ntuple(d -> offsetk(d + 2), N - 2)...)
    b3 = Expr(:block, totaloffsetraw(N), Expr(:(=), :Dstar, Expr(:call, :-, :Dstar)))
    outer = findmax_loops_innerturbo(N, D, false)
    return quote
        $b1
        $b2
        $b3
        $outer
    end
end
function ivtfindmax_quote(N::Int, D)
    b1 = sizeblock(N)
    b2 = Expr(:block, ntuple(d -> offsetk(d + 2), N - 2)...)
    b3 = Expr(:block, totaloffsetraw(N), Expr(:(=), :Dstar, Expr(:call, :-, :Dstar)))
    outer = findmax_loops_innerturbo(N, D, true)
    return quote
        $b1
        $b2
        $b3
        $outer
    end
end

function vfindmax_quote(N::Int, D)
    b1 = sizeblock(N)
    b2 = Expr(:block, ntuple(d -> offsetk(d + 2), N - 2)...)
    b3 = Expr(:block, totaloffsetraw(N), Expr(:(=), :Dstar, Expr(:call, :-, :Dstar)))
    outer = findmax_loops(N, D)
    return quote
        $b1
        $b2
        $b3
        @turbo $outer
    end
end

function vtfindmax_quote(N::Int, D)
    b1 = sizeblock(N)
    b2 = Expr(:block, ntuple(d -> offsetk(d + 2), N - 2)...)
    b3 = Expr(:block, totaloffsetraw(N), Expr(:(=), :Dstar, Expr(:call, :-, :Dstar)))
    outer = findmax_loops(N, D)
    return quote
        $b1
        $b2
        $b3
        @tturbo $outer
    end
end

@generated _bfindmax!(B::AbstractArray{T, N}, C::AbstractArray{Tₒ, N},
                      A::AbstractArray{T, N}, dims::D) where {T, Tₒ, N, D} = findmax_quote(N, D)
function bfindmax(A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
    Dᴮ = ntuple(d -> d ∈ dims ? 1 : size(A, d), N)
    Dᴮ′ = ntuple(d -> d ∈ dims ? Val(1) : size(A, d), N)
    B = similar(A, Dᴮ)
    C = similar(A, Int, Dᴮ)
    _bfindmax!(B, C, A, Dᴮ′)
    B, CartesianIndices(A)[C]
end

@generated _vfindmax!(B::AbstractArray{T, N}, C::AbstractArray{Tₒ, N},
                      A::AbstractArray{T, N}, dims::D) where {T, Tₒ, N, D} = vfindmax_quote(N, D)
function vfindmax(A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
    if ntuple(identity, Val(N)) ⊆ dims
        return vfindmax1(A)
    elseif 1 ∈ dims
        return ivfindmax(A, dims)
    else
        Dᴮ = ntuple(d -> d ∈ dims ? 1 : size(A, d), N)
        Dᴮ′ = ntuple(d -> d ∈ dims ? Val(1) : size(A, d), N)
        B = similar(A, Dᴮ)
        C = similar(A, Int, Dᴮ)
        _vfindmax2!(B, C, A, Dᴮ′)
        return B, CartesianIndices(A)[C]
    end
end

@generated _vtfindmax!(B::AbstractArray{T, N}, C::AbstractArray{Tₒ, N},
                       A::AbstractArray{T, N}, dims::D) where {T, Tₒ, N, D} = vtfindmax_quote(N, D)
function vtfindmax(A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
    if ntuple(identity, Val(N)) ⊆ dims
        return vtfindmax1(A)
    elseif 1 ∈ dims
        return ivtfindmax(A, dims)
    else
        Dᴮ = ntuple(d -> d ∈ dims ? 1 : size(A, d), N)
        Dᴮ′ = ntuple(d -> d ∈ dims ? Val(1) : size(A, d), N)
        B = similar(A, Dᴮ)
        C = similar(A, Int, Dᴮ)
        _vtfindmax!(B, C, A, Dᴮ′)
        return B, CartesianIndices(A)[C]
    end
end

# For handling cases where the first dimension is being reduced. Alas, still fails
# for some cases, e.g. A ∈ ℝᴵˣᴶˣᴷˣᴸ, dims=(1,2,3)
@generated _ivfindmax!(B::AbstractArray{T, N}, C::AbstractArray{Tₒ, N},
                       A::AbstractArray{T, N}, dims::D) where {T, Tₒ, N, D} = ivfindmax_quote(N, D)
function ivfindmax(A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
    Dᴮ = ntuple(d -> d ∈ dims ? 1 : size(A, d), N)
    Dᴮ′ = ntuple(d -> d ∈ dims ? Val(1) : size(A, d), N)
    B = similar(A, Dᴮ)
    C = similar(A, Int, Dᴮ)
    _ivfindmax!(B, C, A, Dᴮ′)
    B, CartesianIndices(A)[C]
end
@generated _ivtfindmax!(B::AbstractArray{T, N}, C::AbstractArray{Tₒ, N},
                        A::AbstractArray{T, N}, dims::D) where {T, Tₒ, N, D} = ivtfindmax_quote(N, D)
function ivtfindmax(A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
    Dᴮ = ntuple(d -> d ∈ dims ? 1 : size(A, d), N)
    Dᴮ′ = ntuple(d -> d ∈ dims ? Val(1) : size(A, d), N)
    B = similar(A, Dᴮ)
    C = similar(A, Int, Dᴮ)
    _ivtfindmax!(B, C, A, Dᴮ′)
    B, CartesianIndices(A)[C]
end

function vfindmax1(A::AbstractArray{T, N}) where {T, N}
    m = typemin(T)
    j = 0
    @turbo for i ∈ eachindex(A)
        y = A[i] > m
        m = y ? A[i] : m
        j = y ? i : j
    end
    m, CartesianIndices(A)[j]
end
function vtfindmax1(A::AbstractArray{T, N}) where {T, N}
    m = typemin(T)
    j = 0
    @tturbo for i ∈ eachindex(A)
        y = A[i] > m
        m = y ? A[i] : m
        j = y ? i : j
    end
    m, CartesianIndices(A)[j]
end

################
# Handle scalar dims by wrapping in Tuple
vfindmax(A::AbstractArray{T, N}, dims::Int) where {T, N} = vfindmax(A, (dims,))
# Convenience dispatches to match JuliaBase
vfindmax(A::AbstractArray{T, N}; dims=:) where {T, N} = vfindmax(A, dims)
vfindmax(A::AbstractArray{T, N}) where {T, N} = vfindmax1(A)
vfindmax(A::AbstractArray{T, N}, ::Colon) where {T, N} = vfindmax1(A)
vtfindmax(A::AbstractArray{T, N}, dims::Int) where {T, N} = vtfindmax(A, (dims,))
# Convenience dispatches to match JuliaBase
vtfindmax(A::AbstractArray{T, N}; dims=:) where {T, N} = vtfindmax(A, dims)
vtfindmax(A::AbstractArray{T, N}) where {T, N} = vtfindmax1(A)
vtfindmax(A::AbstractArray{T, N}, ::Colon) where {T, N} = vtfindmax1(A)

# @timev vfindmax1(A)
# @timev vtfindmax1(A)
# @timev vfindmax2(A, (2,));
# @timev vfindmax3(A, (2,));
# @timev vtfindmax2(A, (2,));
# @timev vtfindmax3(A, (2,));
