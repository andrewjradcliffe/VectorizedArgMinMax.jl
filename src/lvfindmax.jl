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
    loops = Expr(:for)
    block = Expr(:block)
    params = D.parameters
    for d = N:-1:1
        if params[d] !== Static.One
            ex = Expr(:(=), Symbol(:i_, d), Expr(:call, :axes, :A, d))
            push!(block.args, ex)
        end
    end
    push!(loops.args, block)
    loops
end
function innerloopgen(N::Int, D)
    loops = Expr(:for)
    block = Expr(:block)
    params = D.parameters
    for d = N:-1:1
        if params[d] === Static.One
            ex = Expr(:(=), Symbol(:i_, d), Expr(:call, :axes, :A, d))
            push!(block.args, ex)
        end
    end
    push!(loops.args, block)
    loops
end

function innerpost(N::Int, D)
    params = D.parameters
    block = Expr(:block)
    b = Expr(:ref, :B, ntuple(d -> params[d] === Static.One ? 1 : Symbol(:i_, d), N)...)
    c = Expr(:ref, :C, ntuple(d -> params[d] === Static.One ? 1 : Symbol(:i_, d), N)...)
    e1 = Expr(:(=), b, :m)
    e2 = Expr(:(=), c, :j)
    push!(block.args, e1)
    push!(block.args, e2)
    block
end
function innerpost2(N::Int, D)
    params = D.parameters
    block = Expr(:block)
    b = Expr(:ref, :B, (Symbol(:i_, d) for d = 1:N if params[d] !== Static.One)...)
    c = Expr(:ref, :C, (Symbol(:i_, d) for d = 1:N if params[d] !== Static.One)...)
    e1 = Expr(:(=), b, :m)
    e2 = Expr(:(=), c, :j)
    push!(block.args, e1)
    push!(block.args, e2)
    block
end

function innerpost2_leading1(N::Int, D)
    params = D.parameters
    block = Expr(:block)
    b = Expr(:ref, :B, ntuple(d -> params[d] === Static.One ? 1 : Symbol(:i_, d), N)[2:N]...)
    c = Expr(:ref, :C, ntuple(d -> params[d] === Static.One ? 1 : Symbol(:i_, d), N)[2:N]...)
    e1 = Expr(:(=), b, :m)
    e2 = Expr(:(=), c, :j)
    push!(block.args, e1)
    push!(block.args, e2)
    block
end

function maxcompareblock(N::Int)
    block = Expr(:block)
    a = Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...)
    d = sumprodprecomputed2(N)
    push!(d.args, :D_sp)
    yₑ = Expr(:(=), :y, Expr(:call, :(>), a, :m)) # f should only be > or <
    mₑ = Expr(:(=), :m, Expr(:if, :y, a, :m))
    jₑ = Expr(:(=), :j, Expr(:if, :y, d, :j))
    push!(block.args, yₑ)
    push!(block.args, mₑ)
    push!(block.args, jₑ)
    block
end

function maxcompareblock2(N::Int)
    block = Expr(:block)
    a = Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...)
    d = sumprodprecomputed2(N)
    push!(d.args, :D_sp)
    yₑ = Expr(:(=), :y, Expr(:call, :(>), a, :m)) # f should only be > or <
    mₑ = Expr(:(=), :m, Expr(:call, :ifelse, :y, a, :m))
    jₑ = Expr(:(=), :j, Expr(:call, :ifelse, :y, d, :j))
    push!(block.args, yₑ)
    push!(block.args, mₑ)
    push!(block.args, jₑ)
    block
end

# function maxcompareblock3(N::Int, D)
#     block = Expr(:block)
#     params = D.parameters
#     a = Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...)
#     # b = Expr(:ref, :B, ntuple(d -> params[d] === Static.One ? 1 : Symbol(:i_, d), N)...)
#     d = sumprodprecomputed2(N)
#     push!(d.args, :D_sp)
#     jₑ = Expr(:(=), :j, Expr(:call, :ifelse, Expr(:call, :(>=), a, :m), d, :j))
#     push!(block.args, jₑ)
#     block
# end

function lvfindmax_quote(N::Int, D)
    block1 = sizeblock(N)
    block2 = sizeproductsblock(N)
    block3 = Expr(:block, sumprodconstant(N), Expr(:(=), :D_sp, Expr(:call, :-, :D_sp)))
    outerloops = outerloopgen(N, D)
    block4 = Expr(:block, Expr(:(=), :j, 1), Expr(:(=), :m, Expr(:call, :typemin, :T)))
    innerloops = innerloopgen(N, D)
    block5 = maxcompareblock(N)
    push!(innerloops.args, block5)
    push!(block4.args, innerloops)
    block6 = innerpost(N, D)
    push!(block4.args, block6.args...)
    push!(outerloops.args, block4)
    return quote
        $block1
        $block2
        $block3
        @turbo $outerloops
    end
end
@generated function _lvfindmax!(C::AbstractArray{Tₒ, N}, A::AbstractArray{T, N},
                             B::AbstractArray{T, N}, dims::D) where {Tₒ, T, N, D}
    lvfindmax_quote(N, D)
end
function lvfindmax(A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
    Dᴮ′ = ntuple(d -> d ∈ dims ? StaticInt(1) : size(A, d), N)
    B = similar(A, Dᴮ′)
    C = similar(B, Int)
    _lvfindmax!(C, A, B, Dᴮ′)
    B, CartesianIndices(A)[C]
end
function lvfindmax_quote2(N::Int, D)
    block1 = sizeblock(N)
    block2 = sizeproductsblock(N)
    block3 = Expr(:block, sumprodconstant(N), Expr(:(=), :D_sp, Expr(:call, :-, :D_sp)))
    outerloops = outerloopgen(N, D)
    block4 = Expr(:block, Expr(:(=), :j, 1), Expr(:(=), :m, Expr(:call, :typemin, :T)))
    innerloops = innerloopgen(N, D)
    block5 = maxcompareblock2(N)
    push!(innerloops.args, block5)
    push!(block4.args, innerloops)
    block6 = innerpost(N, D)
    push!(block4.args, block6.args...)
    push!(outerloops.args, block4)
    return quote
        $block1
        $block2
        $block3
        @turbo $outerloops
    end
end
@generated function _lvfindmax2!(C::AbstractArray{Tₒ, N}, A::AbstractArray{T, N},
                             B::AbstractArray{T, N}, dims::D) where {Tₒ, T, N, D}
    lvfindmax_quote2(N, D)
end
function lvfindmax2(A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
    Dᴮ′ = ntuple(d -> d ∈ dims ? StaticInt(1) : size(A, d), N)
    B = similar(A, Dᴮ′)
    C = similar(B, Int)
    _lvfindmax2!(C, A, B, Dᴮ′)
    B, CartesianIndices(A)[C]
end

function lvfindmax_quote3(N::Int, D)
    block1 = sizeblock(N)
    block2 = sizeproductsblock(N)
    block3 = Expr(:block, sumprodconstant(N), Expr(:(=), :D_sp, Expr(:call, :-, :D_sp)))
    outerloops = outerloopgen(N, D)
    block4 = Expr(:block, Expr(:(=), :j, 1), Expr(:(=), :m, Expr(:call, :typemin, :T)))
    innerloops = innerloopgen(N, D)
    block5 = maxcompareblock2(N)
    push!(innerloops.args, block5)
    push!(block4.args, innerloops)
    block6 = D.parameters[1] === StaticInt{1} ? innerpost2_leading1(N, D) : innerpost(N, D)
    push!(block4.args, block6.args...)
    push!(outerloops.args, block4)
    return quote
        $block1
        $block2
        $block3
        @turbo $outerloops
    end
end
@generated function _lvfindmax3!(C::AbstractArray{Tₒ, M}, A::AbstractArray{T, N},
                                 B::AbstractArray{T, M}, dims::D) where {Tₒ, M, T, N, D}
    lvfindmax_quote3(N, D)
end
function lvfindmax3(A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
    if 1 ∈ dims
        Dᴮ′ = ntuple(d -> d ∈ dims ? StaticInt(1) : size(A, d), N)
        Dᴮ = ntuple(d -> d + 1 ∈ dims ? StaticInt(1) : size(A, d), N - 1)
        B = similar(A, Dᴮ)
        C = similar(B, Int)
        _lvfindmax3!(C, A, B, Dᴮ′)
        return reshape(B, Dᴮ′), CartesianIndices(A)[reshape(C, Dᴮ′)]
    else
        Dᴮ′ = ntuple(d -> d ∈ dims ? StaticInt(1) : size(A, d), N)
        B = similar(A, Dᴮ′)
        C = similar(B, Int)
        _lvfindmax2!(C, A, B, Dᴮ′)
        return B, CartesianIndices(A)[C]
    end
end

A = rand(4, 3, 5);

@benchmark findmax(A, dims=dims)

@benchmark bfindmax(A, dims)

@benchmark lvfindmax(A, dims)
@benchmark lvfindmax2(A, dims)
@benchmark lvfindmax3(A, dims)

N = ndims(A)
DD = typeof(ntuple(d -> d ∈ dims ? StaticInt(1) : size(A, d), N))
lvfindmax_quote(N, DD)
lvfindmax_quote2(N, DD)
lvfindmax_quote3(N, DD)
lvfindmax3(A, dims) == findmax(A, dims=dims)

lvfindmax(A, (1,))
findmax(A, dims=dims)

dims=(2,)
dims=(1,)
dims=(2,3)
dims=(2,3,4,5)

for d₂ = 2:ndims(A), d₁ = 2:ndims(A)
    dims = (d₁, d₂)
    @assert lvfindmax2(A, dims) == findmax(A, dims=dims)
    @assert lvfindmax3(A, dims) == findmax(A, dims=dims)
end

@benchmark bfindmax(A, dims)
@benchmark findmax(A, dims=dims)
A = rand(10, 100, 1000);
dims = (1,)
