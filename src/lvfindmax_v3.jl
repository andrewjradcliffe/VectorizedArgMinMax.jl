#
# Date created: 2022-03-14
# Author: aradclif
#
#
############################################################################################
function sizeblock(N::Int)
    block = Expr(:block)
    for d = 1:N
        ex = Expr(:(=), Symbol(:D_, d), Expr(:call, :size, :A, d))
        push!(block.args, ex)
    end
    block
end

function sizeproductsblock(N::Int)
    block = Expr(:block)
    for k = 3:N
        ex = Expr(:(=), Symbol(:D_, ntuple(identity, k - 1)...),
                  Expr(:call, :*, ntuple(d -> Symbol(:D_, d), k - 1)...))
        push!(block.args, ex)
    end
    block
end

function sumprodprecomputed2(N::Int)
    e = Expr(:call, :+, Symbol(:i_, 1))
    for k = 2:N
        if k == 2
            ex = Expr(:call, :*, Symbol(:D_, 1), Symbol(:i_, 2))
            push!(e.args, ex)
        else
            ex = Expr(:call, :*, Symbol(:D_, ntuple(identity, k - 1)...), Symbol(:i_, k))
            push!(e.args, ex)
        end
    end
    e
end

function sumprodconstant(N::Int)
    Expr(:(=), :D_sp,
         Expr(:call, :+, ntuple(d -> Expr(:call, :*, ntuple(i -> Symbol(:D_, i), d)...), N - 1)...))
end

function outerloopgen(N::Int, D)
    block = Expr(:block)
    params = D.parameters
    for d = N:-1:1
        if params[d] !== Static.One
            ex = Expr(:(=), Symbol(:i_, d), Expr(:call, :axes, :A, d))
            push!(block.args, ex)
        end
    end
    Expr(:for, block)
end
function innerloopgen(N::Int, D)
    block = Expr(:block)
    params = D.parameters
    for d = N:-1:1
        if params[d] === Static.One
            ex = Expr(:(=), Symbol(:i_, d), Expr(:call, :axes, :A, d))
            push!(block.args, ex)
        end
    end
    Expr(:for, block)
end

function innerpost(N::Int, D)
    params = D.parameters
    b = Expr(:ref, :B, ntuple(d -> params[d] === Static.One ? 1 : Symbol(:i_, d), N)...)
    c = Expr(:ref, :C, ntuple(d -> params[d] === Static.One ? 1 : Symbol(:i_, d), N)...)
    Expr(:block, Expr(:(=), b, :m), Expr(:(=), c, :j))
end

function maxcompareblock(N::Int)
    a = Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...)
    d = sumprodprecomputed2(N)
    push!(d.args, :D_sp)
    yₑ = Expr(:(=), :y, Expr(:call, :(>), a, :m)) # f should only be > or <
    # mₑ = Expr(:(=), :m, Expr(:if, :y, a, :m))
    # jₑ = Expr(:(=), :j, Expr(:if, :y, d, :j))
    mₑ = Expr(:(=), :m, Expr(:call, :ifelse, :y, a, :m))
    jₑ = Expr(:(=), :j, Expr(:call, :ifelse, :y, d, :j))
    Expr(:block, yₑ, mₑ, jₑ)
end

function lvfindmax_quote(N::Int, D)
    b1 = sizeblock(N)
    b2 = sizeproductsblock(N)
    b3 = Expr(:block, sumprodconstant(N), Expr(:(=), :D_sp, Expr(:call, :-, :D_sp)))
    outer = outerloopgen(N, D)
    b4 = Expr(:block, Expr(:(=), :j, 1), Expr(:(=), :m, Expr(:call, :typemin, :T)))
    inner = innerloopgen(N, D)
    b5 = maxcompareblock(N)
    push!(inner.args, b5)
    push!(b4.args, inner)
    b6 = innerpost(N, D)
    push!(b4.args, b6.args...)
    push!(outer.args, b4)
    return quote
        $b1
        $b2
        $b3
        @turbo $outer
    end
end
@generated function _lvfindmax!(C::AbstractArray{Tₒ, N}, A::AbstractArray{T, N},
                             B::AbstractArray{T, N}, dims::D) where {Tₒ, T, N, D}
    lvfindmax_quote(N, D)
end
function lvfindmax(A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
    if 1 ∈ dims
        return bfindmax(A, dims)
    else
        Dᴮ′ = ntuple(d -> d ∈ dims ? StaticInt(1) : size(A, d), N)
        B = similar(A, Dᴮ′)
        C = similar(B, Int)
        _lvfindmax!(C, A, B, Dᴮ′)
        return B, CartesianIndices(A)[C]
    end
end

A = rand(4, 3, 5);
N = ndims(A)
dims = (2,)
DD = typeof(ntuple(d -> d ∈ dims ? StaticInt(1) : size(A, d), N))
lvfindmax_quote(N, DD)
for d₂ = 1:ndims(A), d₁ = 1:ndims(A)
    dims = (d₁, d₂)
    @assert lvfindmax(A, dims) == findmax(A, dims=dims)
end
@benchmark findmax(A, dims=dims)
@benchmark lvfindmax(A, dims)
