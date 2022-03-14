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
function sumprodprecomputed2(N::Int, D)
    params = D.parameters
    e = params[1] !== Static.One ? Expr(:call, :+, Symbol(:i_, 1)) : Expr(:call, :+, Symbol(:j_, 1))
    for k = 2:N
        if k == 2
            sym = params[2] !== Static.One ? :i_ : :j_
            ex = Expr(:call, :*, Symbol(:D_, 1), Symbol(sym, 2))
            push!(e.args, ex)
        else
            sym = params[k] !== Static.One ? :i_ : :j_
            ex = Expr(:call, :*, Symbol(:D_, ntuple(identity, k - 1)...), Symbol(sym, k))
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
    # loops = Expr(:for)
    block = Expr(:block)
    params = D.parameters
    for d = N:-1:1
        if params[d] !== Static.One
            ex = Expr(:(=), Symbol(:i_, d), Expr(:call, :axes, :A, d))
            push!(block.args, ex)
        end
    end
    # push!(loops.args, block)
    Expr(:for, block)
end
function innerloopgen(N::Int, D)
    # loops = Expr(:for)
    block = Expr(:block)
    params = D.parameters
    for d = N:-1:1
        if params[d] === Static.One
            ex = Expr(:(=), Symbol(:i_, d), Expr(:call, :axes, :A, d))
            push!(block.args, ex)
        end
    end
    # push!(loops.args, block)
    # loops
    Expr(:for, block)
end

function innerpost(N::Int, D)
    params = D.parameters
    # block = Expr(:block)
    b = Expr(:ref, :B, ntuple(d -> params[d] === Static.One ? 1 : Symbol(:i_, d), N)...)
    c = Expr(:ref, :C, ntuple(d -> params[d] === Static.One ? 1 : Symbol(:i_, d), N)...)
    # e1 = Expr(:(=), b, :m)
    # e2 = Expr(:(=), c, :j)
    # push!(block.args, e1)
    # push!(block.args, e2)
    # block
    Expr(:block, Expr(:(=), b, :m), Expr(:(=), c, :j))
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
    a = Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...)
    d = sumprodprecomputed2(N)
    push!(d.args, :D_sp)
    yₑ = Expr(:(=), :y, Expr(:call, :(>), a, :m)) # f should only be > or <
    mₑ = Expr(:(=), :m, Expr(:if, :y, a, :m))
    jₑ = Expr(:(=), :j, Expr(:if, :y, d, :j))
    Expr(:block, yₑ, mₑ, jₑ)
end

function maxcompareblock2(N::Int)
    a = Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...)
    d = sumprodprecomputed2(N)
    push!(d.args, :D_sp)
    yₑ = Expr(:(=), :y, Expr(:call, :(>), a, :m)) # f should only be > or <
    mₑ = Expr(:(=), :m, Expr(:call, :ifelse, :y, a, :m))
    jₑ = Expr(:(=), :j, Expr(:call, :ifelse, :y, d, :j))
    # jₑ = Expr(:(=), :j, Expr(:call, :+, Expr(:call, :zero, :Tₒ), Expr(:call, :ifelse, :y, d, :j)))
    Expr(:block, yₑ, mₑ, jₑ)
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

function maxcompareblock4(N::Int)
    a = Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...)
    d = sumprodprecomputed2(N)
    push!(d.args, :D_sp)
    jₑ = Expr(:(+=), :j, Expr(:call, :ifelse, Expr(:call, :(>), a, :m), d, 0))
    mₑ = Expr(:(=), :m, Expr(:call, :max, a, :m))
    Expr(:block, jₑ, mₑ)
end
function lvfindmax_quote4(N::Int, D)
    b1 = sizeblock(N)
    b2 = sizeproductsblock(N)
    b3 = Expr(:block, sumprodconstant(N), Expr(:(=), :D_sp, Expr(:call, :-, :D_sp)))
    outer = outerloopgen(N, D)
    b4 = Expr(:block, Expr(:(=), :j, Expr(:call, :zero, :Tₒ)),
              Expr(:(=), :m, Expr(:call, :typemin, :T)))
    inner = innerloopgen(N, D)
    b5 = maxcompareblock4(N)
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

# function maxcompareblock5(N::Int, D)
#     a = Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...)
#     yₑ = Expr(:(=), :y, Expr(:call, :(>), a, :m)) # f should only be > or <
#     mₑ = Expr(:(=), :m, Expr(:call, :ifelse, :y, a, :m))
#     # jₑ = Expr(:(=), Symbol(:j_, d), Expr(:call, :ifelse, Expr(:y), Symbol(:i_, d), Symbol(:j_, d)))
#     js = Any[]
#     for d = 1:N
#         if params[d] === Static.One
#             ex = Expr(:(=), Symbol(:j_, d),
#                       Expr(:call, :ifelse, Expr(:y), Symbol(:i_, d), Symbol(:j_, d)))
#             push!(js, ex)
#         end
#     end
#     Expr(:block, yₑ, mₑ, js...)
# end

# function innerpost5(N::Int, D)
#     params = D.parameters
#     d = sumprodprecomputed2(N, D)
#     push!(d.args, :D_sp)
#     b = Expr(:ref, :B, ntuple(d -> params[d] === Static.One ? 1 : Symbol(:i_, d), N)...)
#     c = Expr(:ref, :C, ntuple(d -> params[d] === Static.One ? 1 : Symbol(:i_, d), N)...)
#     Expr(:block, Expr(:(=), b, :m), Expr(:(=), c, d))
# end

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
    Dᴮ′ = ntuple(d -> d ∈ dims ? StaticInt(1) : size(A, d), N)
    B = similar(A, Dᴮ′)
    C = similar(B, Int)
    _lvfindmax!(C, A, B, Dᴮ′)
    B, CartesianIndices(A)[C]
end
function lvfindmax_quote2(N::Int, D)
    b1 = sizeblock(N)
    b2 = sizeproductsblock(N)
    b3 = Expr(:block, sumprodconstant(N), Expr(:(=), :D_sp, Expr(:call, :-, :D_sp)))
    outer = outerloopgen(N, D)
    # b4 = Expr(:block, Expr(:(=), :j, Expr(:call, :zero, :Tₒ)),
    #           Expr(:(=), :m, Expr(:call, :typemin, :T)))
    b4 = Expr(:block, Expr(:(=), :j, Expr(:call, :zero, :Tₒ)),
              Expr(:(=), :m, Expr(:call, :typemin, :T)))
    inner = innerloopgen(N, D)
    b5 = maxcompareblock2(N)
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

# function lvfindmax_quote3(N::Int, D)
#     b1 = sizeblock(N)
#     b2 = sizeproductsblock(N)
#     b3 = Expr(:block, sumprodconstant(N), Expr(:(=), :D_sp, Expr(:call, :-, :D_sp)))
#     outer = outerloopgen(N, D)
#     b4 = Expr(:block, Expr(:(=), :j, 1), Expr(:(=), :m, Expr(:call, :typemin, :T)))
#     inner = innerloopgen(N, D)
#     b5 = maxcompareblock2(N)
#     push!(inner.args, b5)
#     push!(b4.args, inner)
#     b6 = D.parameters[1] === StaticInt{1} ? innerpost2_leading1(N, D) : innerpost(N, D)
#     push!(b4.args, b6.args...)
#     push!(outer.args, b4)
#     return quote
#         $b1
#         $b2
#         $b3
#         @turbo $outer
#     end
# end
# @generated function _lvfindmax3!(C::AbstractArray{Tₒ, M}, A::AbstractArray{T, N},
#                                  B::AbstractArray{T, M}, dims::D) where {Tₒ, M, T, N, D}
#     lvfindmax_quote3(N, D)
# end
# function lvfindmax3(A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
#     if 1 ∈ dims
#         Dᴮ′ = ntuple(d -> d ∈ dims ? StaticInt(1) : size(A, d), N)
#         Dᴮ = ntuple(d -> d + 1 ∈ dims ? StaticInt(1) : size(A, d), N - 1)
#         B = similar(A, Dᴮ)
#         C = similar(B, Int)
#         _lvfindmax3!(C, A, B, Dᴮ′)
#         return reshape(B, Dᴮ′), CartesianIndices(A)[reshape(C, Dᴮ′)]
#     else
#         Dᴮ′ = ntuple(d -> d ∈ dims ? StaticInt(1) : size(A, d), N)
#         B = similar(A, Dᴮ′)
#         C = similar(B, Int)
#         _lvfindmax2!(C, A, B, Dᴮ′)
#         return B, CartesianIndices(A)[C]
#     end
# end

function lvfindmax_quote5(N::Int, D)
    b1 = sizeblock(N)
    b2 = sizeproductsblock(N)
    b3 = Expr(:block, sumprodconstant(N), Expr(:(=), :D_sp, Expr(:call, :-, :D_sp)))
    outer = outerloopgen(N, D)
    params = D.parameters
    js = Any[]
    for d = 1:N
        if params[d] === Static.One
            ex = Expr(:(=), Symbol(:j_, d), Expr(:call, :zero, :Tₒ))
            push!(js, ex)
        end
    end
    b4 = Expr(:block, js..., Expr(:(=), :m, Expr(:call, :typemin, :T)))
    inner = innerloopgen(N, D)
    b5 = maxcompareblock5(N, D)
    push!(inner.args, b5)
    push!(b4.args, inner)
    b6 = innerpost5(N, D)
    push!(b4.args, b6.args...)
    push!(outer.args, b4)
    return quote
        $b1
        $b2
        $b3
        @turbo $outer
    end
end

function maxcompareblock5(N::Int, D)
    a = Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...)
    yₑ = Expr(:(=), :y, Expr(:call, :(>), a, :m)) # f should only be > or <
    mₑ = Expr(:(=), :m, Expr(:call, :ifelse, :y, a, :m))
    # jₑ = Expr(:(=), Symbol(:j_, d), Expr(:call, :ifelse, Expr(:y), Symbol(:i_, d), Symbol(:j_, d)))
    params = D.parameters
    js = Any[]
    for d = 1:N
        if params[d] === Static.One
            ex = Expr(:(=), Symbol(:j_, d),
                      Expr(:call, :ifelse, :y, Symbol(:i_, d), Symbol(:j_, d)))
            push!(js, ex)
        end
    end
    Expr(:block, yₑ, mₑ, js...)
end

function innerpost5(N::Int, D)
    params = D.parameters
    d = sumprodprecomputed2(N, D)
    push!(d.args, :D_sp)
    b = Expr(:ref, :B, ntuple(d -> params[d] === Static.One ? 1 : Symbol(:i_, d), N)...)
    c = Expr(:ref, :C, ntuple(d -> params[d] === Static.One ? 1 : Symbol(:i_, d), N)...)
    Expr(:block, Expr(:(=), b, :m), Expr(:(=), c, d))
end

@generated function _lvfindmax5!(C::AbstractArray{Tₒ, N}, A::AbstractArray{T, N},
                                 B::AbstractArray{T, N}, dims::D) where {Tₒ, T, N, D}
    lvfindmax_quote5(N, D)
end
function lvfindmax5(A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
    Dᴮ′ = ntuple(d -> d ∈ dims ? StaticInt(1) : size(A, d), N)
    B = similar(A, Dᴮ′)
    C = similar(B, Int)
    _lvfindmax5!(C, A, B, Dᴮ′)
    B, CartesianIndices(A)[C]
end



A = rand(4, 3, 5);

@benchmark findmax(A, dims=dims)

@benchmark bfindmax(A, dims)

@benchmark lvfindmax(A, dims)
@benchmark lvfindmax2(A, dims)
@benchmark lvfindmax3(A, dims)
@benchmark lvfindmax5(A, dims)

N = ndims(A)
DD = typeof(ntuple(d -> d ∈ dims ? StaticInt(1) : size(A, d), N))
lvfindmax_quote(N, DD)
lvfindmax_quote2(N, DD)
lvfindmax_quote3(N, DD)
lvfindmax_quote4(N, DD)
lvfindmax_quote5(N, DD)
lvfindmax2(A, dims) == findmax(A, dims=dims)
lvfindmax5(A, dims) == findmax(A, dims=dims)
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
