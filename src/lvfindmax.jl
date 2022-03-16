#
# Date created: 2022-03-16
# Author: aradclif
#
#
############################################################################################
function findmax_quote2(N::Int, D)
    b1 = sizeblock(N)
    b2 = Expr(:block, ntuple(d -> offsetk(d + 2), N - 2)...)
    b3 = Expr(:block, totaloffsetraw(N), Expr(:(=), :Dstar, Expr(:call, :-, :Dstar)))
    b4 = preexpr2(:typemin)
    inner = innerloop(N, D)
    push!(inner.args, maxblock2(N, D))
    push!(b4.args, inner)
    push!(b4.args, postexpr(N, D).args...)
    outer = outerloop(N, D)
    push!(outer.args, b4)
    return quote
        $b1
        $b2
        $b3
        $outer
    end
end
function findmax_quote3(N::Int, D)
    b1 = sizeblock(N)
    b2 = Expr(:block, ntuple(d -> offsetk(d + 2), N - 2)...)
    b3 = Expr(:block, totaloffsetraw(N), Expr(:(=), :Dstar, Expr(:call, :-, :Dstar)))
    b4 = preexpr2(:typemin)
    inner = innerloop(N, D)
    push!(inner.args, maxblock3(N, D))
    push!(b4.args, inner)
    push!(b4.args, postexpr3(N, D).args...)
    outer = outerloop(N, D)
    push!(outer.args, b4)
    return quote
        $b1
        $b2
        $b3
        $outer
    end
end
function findmax_quote3b(N::Int, D)
    b1 = sizeblock(N)
    b2 = Expr(:block, ntuple(d -> offsetk(d + 2), N - 2)...)
    b3 = Expr(:block, totaloffsetraw(N), Expr(:(=), :Dstar, Expr(:call, :-, :Dstar)))
    b4 = preexpr2(:typemin)
    inner = innerloop(N, D)
    push!(inner.args, maxblock3(N, D))
    push!(b4.args, Expr(:macrocall, Symbol("@turbo"), (), inner))
    push!(b4.args, postexpr3(N, D).args...)
    outer = outerloop(N, D)
    push!(outer.args, b4)
    return quote
        $b1
        $b2
        $b3
        $outer
    end
end

function vfindmax_quote2(N::Int, D)
    b1 = sizeblock(N)
    b2 = Expr(:block, ntuple(d -> offsetk(d + 2), N - 2)...)
    b3 = Expr(:block, totaloffsetraw(N), Expr(:(=), :Dstar, Expr(:call, :-, :Dstar)))
    b4 = preexpr2(:typemin)
    inner = innerloop(N, D)
    push!(inner.args, maxblock2(N, D))
    push!(b4.args, inner)
    push!(b4.args, postexpr(N, D).args...)
    outer = outerloop(N, D)
    push!(outer.args, b4)
    return quote
        $b1
        $b2
        $b3
        @turbo $outer
    end
end
function vfindmax_quote3(N::Int, D)
    b1 = sizeblock(N)
    b2 = Expr(:block, ntuple(d -> offsetk(d + 2), N - 2)...)
    b3 = Expr(:block, totaloffsetraw(N), Expr(:(=), :Dstar, Expr(:call, :-, :Dstar)))
    b4 = preexpr2(:typemin)
    inner = innerloop(N, D)
    push!(inner.args, maxblock3(N, D))
    push!(b4.args, inner)
    push!(b4.args, postexpr3(N, D).args...)
    outer = outerloop(N, D)
    push!(outer.args, b4)
    return quote
        $b1
        $b2
        $b3
        @turbo $outer
    end
end

function vtfindmax_quote2(N::Int, D)
    b1 = sizeblock(N)
    b2 = Expr(:block, ntuple(d -> offsetk(d + 2), N - 2)...)
    b3 = Expr(:block, totaloffsetraw(N), Expr(:(=), :Dstar, Expr(:call, :-, :Dstar)))
    b4 = preexpr2(:typemin)
    inner = innerloop(N, D)
    push!(inner.args, maxblock2(N, D))
    push!(b4.args, inner)
    push!(b4.args, postexpr(N, D).args...)
    outer = outerloop(N, D)
    push!(outer.args, b4)
    return quote
        $b1
        $b2
        $b3
        @tturbo $outer
    end
end
function vtfindmax_quote3(N::Int, D)
    b1 = sizeblock(N)
    b2 = Expr(:block, ntuple(d -> offsetk(d + 2), N - 2)...)
    b3 = Expr(:block, totaloffsetraw(N), Expr(:(=), :Dstar, Expr(:call, :-, :Dstar)))
    b4 = preexpr2(:typemin)
    inner = innerloop(N, D)
    push!(inner.args, maxblock3(N, D))
    push!(b4.args, inner)
    push!(b4.args, postexpr3(N, D).args...)
    outer = outerloop(N, D)
    push!(outer.args, b4)
    return quote
        $b1
        $b2
        $b3
        @tturbo $outer
    end
end

@generated _findmax2!(B::AbstractArray{T, N}, C::AbstractArray{Tₒ, N},
                       A::AbstractArray{T, N}, dims::D) where {T, Tₒ, N, D} = findmax_quote2(N, D)
function findmax2(A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
    Dᴮ = ntuple(d -> d ∈ dims ? 1 : size(A, d), N)
    Dᴮ′ = ntuple(d -> d ∈ dims ? Val(1) : size(A, d), N)
    B = similar(A, Dᴮ)
    C = similar(A, Int, Dᴮ)
    _findmax2!(B, C, A, Dᴮ′)
    B, CartesianIndices(A)[C]
end

@generated _findmax3!(B::AbstractArray{T, N}, C::AbstractArray{Tₒ, N},
                      A::AbstractArray{T, N}, dims::D) where {T, Tₒ, N, D} = findmax_quote3(N, D)
function findmax3(A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
    Dᴮ = ntuple(d -> d ∈ dims ? 1 : size(A, d), N)
    Dᴮ′ = ntuple(d -> d ∈ dims ? Val(1) : size(A, d), N)
    B = similar(A, Dᴮ)
    C = similar(A, Int, Dᴮ)
    _findmax3!(B, C, A, Dᴮ′)
    B, CartesianIndices(A)[C]
end

@generated _vfindmax2!(B::AbstractArray{T, N}, C::AbstractArray{Tₒ, N},
                      A::AbstractArray{T, N}, dims::D) where {T, Tₒ, N, D} = vfindmax_quote2(N, D)
function vfindmax2(A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
    if 1 ∈ dims
        return findmax2(A, dims)
    else
        Dᴮ = ntuple(d -> d ∈ dims ? 1 : size(A, d), N)
        Dᴮ′ = ntuple(d -> d ∈ dims ? Val(1) : size(A, d), N)
        B = similar(A, Dᴮ)
        C = similar(A, Int, Dᴮ)
        _vfindmax2!(B, C, A, Dᴮ′)
        return B, CartesianIndices(A)[C]
    end
end

@generated _vfindmax3!(B::AbstractArray{T, N}, C::AbstractArray{Tₒ, N},
                      A::AbstractArray{T, N}, dims::D) where {T, Tₒ, N, D} = vfindmax_quote3(N, D)
function vfindmax3(A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
    if 1 ∈ dims
        return findmax3(A, dims)
    else
        Dᴮ = ntuple(d -> d ∈ dims ? 1 : size(A, d), N)
        Dᴮ′ = ntuple(d -> d ∈ dims ? Val(1) : size(A, d), N)
        B = similar(A, Dᴮ)
        C = similar(A, Int, Dᴮ)
        _vfindmax3!(B, C, A, Dᴮ′)
        return B, CartesianIndices(A)[C]
    end
end

@generated _vtfindmax2!(B::AbstractArray{T, N}, C::AbstractArray{Tₒ, N},
                       A::AbstractArray{T, N}, dims::D) where {T, Tₒ, N, D} = vtfindmax_quote2(N, D)
function vtfindmax2(A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
    Dᴮ = ntuple(d -> d ∈ dims ? 1 : size(A, d), N)
    Dᴮ′ = ntuple(d -> d ∈ dims ? Val(1) : size(A, d), N)
    B = similar(A, Dᴮ)
    C = similar(A, Int, Dᴮ)
    _vtfindmax2!(B, C, A, Dᴮ′)
    B, CartesianIndices(A)[C]
end

@generated _vbfindmax3!(B::AbstractArray{T, N}, C::AbstractArray{Tₒ, N},
                        A::AbstractArray{T, N}, dims::D) where {T, Tₒ, N, D} = findmax_quote3b(N, D)
function vbfindmax3(A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
    Dᴮ = ntuple(d -> d ∈ dims ? 1 : size(A, d), N)
    Dᴮ′ = ntuple(d -> d ∈ dims ? Val(1) : size(A, d), N)
    B = similar(A, Dᴮ)
    C = similar(A, Int, Dᴮ)
    _vbfindmax3!(B, C, A, Dᴮ′)
    B, CartesianIndices(A)[C]
end

@generated _vtfindmax3!(B::AbstractArray{T, N}, C::AbstractArray{Tₒ, N},
                       A::AbstractArray{T, N}, dims::D) where {T, Tₒ, N, D} = vtfindmax_quote3(N, D)
function vtfindmax3(A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
    Dᴮ = ntuple(d -> d ∈ dims ? 1 : size(A, d), N)
    Dᴮ′ = ntuple(d -> d ∈ dims ? Val(1) : size(A, d), N)
    B = similar(A, Dᴮ)
    C = similar(A, Int, Dᴮ)
    _vtfindmax3!(B, C, A, Dᴮ′)
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

@timev vfindmax1(A)
@timev vtfindmax1(A)
@timev vfindmax2(A, (2,));
@timev vfindmax3(A, (2,));
@timev vtfindmax2(A, (2,));
@timev vtfindmax3(A, (2,));
