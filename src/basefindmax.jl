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

function bouterloopgen(N::Int, D)
    block = Expr(:block)
    params = D.parameters
    for d = N:-1:1
        if params[d] !== Val{1}
            ex = Expr(:(=), Symbol(:i_, d), Expr(:call, :axes, :A, d))
            push!(block.args, ex)
        end
    end
    Expr(:for, block)
end
function binnerloopgen(N::Int, D)
    block = Expr(:block)
    params = D.parameters
    for d = N:-1:1
        if params[d] === Val{1}
            ex = Expr(:(=), Symbol(:i_, d), Expr(:call, :axes, :A, d))
            push!(block.args, ex)
        end
    end
    Expr(:for, block)
end

function binnerpost(N::Int, D)
    params = D.parameters
    b = Expr(:ref, :B, ntuple(d -> params[d] === Val{1} ? 1 : Symbol(:i_, d), N)...)
    c = Expr(:ref, :C, ntuple(d -> params[d] === Val{1} ? 1 : Symbol(:i_, d), N)...)
    Expr(:block, Expr(:(=), b, :m), Expr(:(=), c, :j))
end

function compareblock(f, N::Int)
    a = Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...)
    d = sumprodprecomputed2(N)
    push!(d.args, :D_sp)
    y??? = Expr(:(=), :y, Expr(:call, Symbol(f), a, :m)) # f should only be > or <
    # m??? = Expr(:(=), :m, Expr(:if, :y, a, :m))
    # j??? = Expr(:(=), :j, Expr(:if, :y, d, :j))
    m??? = Expr(:(=), :m, Expr(:call, :ifelse, :y, a, :m))
    j??? = Expr(:(=), :j, Expr(:call, :ifelse, :y, d, :j))
    Expr(:block, y???, m???, j???)
end

function compareblock0(f, N::Int, D)
    params = D.parameters
    a = Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...)
    b = Expr(:ref, :B, ntuple(d -> params[d] === Val{1} ? 1 : Symbol(:i_, d), N)...)
    c = Expr(:ref, :C, ntuple(d -> params[d] === Val{1} ? 1 : Symbol(:i_, d), N)...)
    d = sumprodprecomputed2(N)
    push!(d.args, :D_sp)
    y??? = Expr(:(=), :y, Expr(:call, Symbol(f), a, b)) # f should only be > or <
    b??? = Expr(:(=), b, Expr(:call, :ifelse, :y, a, b))
    c??? = Expr(:(=), c, Expr(:call, :ifelse, :y, d, c))
    Expr(:block, y???, b???, c???)
end

function findmax_quote0(N::Int, D)
    loops = loopgen(N)
    b1 = sizeblock(N)
    b2 = sizeproductsblock(N)
    b3 = Expr(:block, sumprodconstant(N), Expr(:(=), :D_sp, Expr(:call, :-, :D_sp)))
    b4 = compareblock0(>, N, D)
    push!(loops.args, b4)
    return quote
        $b1
        $b2
        $b3
        $loops
    end
end
@generated function _bfindmax0!(B::AbstractArray{T, N}, C::AbstractArray{T???, N},
                                A::AbstractArray{T, N}, dims::D) where {T, T???, N, D}
    findmax_quote0(N, D)
end
function bfindmax0(A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
    D??? = ntuple(d -> d ??? dims ? 1 : size(A, d), N)
    D?????? = ntuple(d -> d ??? dims ? Val(1) : size(A, d), N)
    B = fill(typemin(T), D???)
    C = similar(B, Int)
    _bfindmax0!(B, C, A, D??????)
    B, CartesianIndices(A)[C]
end

function findmax_quote(N::Int, D)
    block1 = sizeblock(N)
    block2 = sizeproductsblock(N)
    block3 = Expr(:block, sumprodconstant(N), Expr(:(=), :D_sp, Expr(:call, :-, :D_sp)))
    outerloops = bouterloopgen(N, D)
    block4 = Expr(:block, Expr(:(=), :j, 1), Expr(:(=), :m, Expr(:call, :typemin, :T)))
    innerloops = binnerloopgen(N, D)
    block5 = compareblock(>, N)
    push!(innerloops.args, block5)
    push!(block4.args, innerloops)
    block6 = binnerpost(N, D)
    push!(block4.args, block6.args...)
    push!(outerloops.args, block4)
    return quote
        $block1
        $block2
        $block3
        $outerloops
    end
end
@generated function _bfindmax!(B::AbstractArray{T, N}, C::AbstractArray{T???, N},
                               A::AbstractArray{T, N}, dims::D) where {T, T???, N, D}
    findmax_quote(N, D)
end
function bfindmax(A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
    D??? = ntuple(d -> d ??? dims ? 1 : size(A, d), N)
    D?????? = ntuple(d -> d ??? dims ? Val(1) : size(A, d), N)
    B = similar(A, D???)
    C = similar(B, Int)
    _bfindmax!(B, C, A, D??????)
    B, CartesianIndices(A)[C]
end

A = rand(4, 3, 5);
dims = (2,3)
using BenchmarkTools
@benchmark findmax(A, dims=dims)
@benchmark bfindmax(A, dims)
@benchmark bfindmax0(A, dims)
bfindmax0(A, dims) == findmax(A, dims=dims) == bfindmax(A, dims)

for d??? = 1:ndims(A), d??? = 1:ndims(A)
    dims = (d???, d???)
    @assert bfindmax(A, dims) == findmax(A, dims=dims)
end
DD = typeof(ntuple(d -> d ??? dims ? Val(1) : size(A, d), ndims(A)))
findmax_quote0(ndims(A), DD)
findmax_quote(ndims(A), DD)
compareblock0(>, ndims(A), DD)
