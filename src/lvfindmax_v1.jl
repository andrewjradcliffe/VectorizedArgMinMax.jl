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

function sumprodliteral(N::Int)
    e = Expr(:call, :+, Symbol(:i_, 1))
    for k = 2:N
        if k == 2
            ex = Expr(:call, :-, Expr(:call, :*, Symbol(:D_, 1), Symbol(:i_, 2)), Symbol(:D_, 1))
            push!(e.args, ex)
        else
            ex = Expr(:call, :-,
                      Expr(:call, :*, ntuple(d -> Symbol(:D_, d), k - 1)..., Symbol(:i_, k)),
                      Expr(:call, :*, ntuple(d -> Symbol(:D_, d), k - 1)...))
            push!(e.args, ex)
        end
    end
    e
end

function sumprodprecomputed(N::Int)
    e = Expr(:call, :+, Symbol(:i_, 1))
    for k = 2:N
        if k == 2
            ex = Expr(:call, :-, Expr(:call, :*, Symbol(:D_, 1), Symbol(:i_, 2)), Symbol(:D_, 1))
            push!(e.args, ex)
        else
            ex = Expr(:call, :-,
                      Expr(:call, :*, Symbol(:D_, ntuple(identity, k - 1)...), Symbol(:i_, k)),
                      Symbol(:D_, ntuple(identity, k - 1)...))
            push!(e.args, ex)
        end
    end
    e
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
    # # # Equivalent, but perhaps more clear
    # e = Expr(:(=), :D_sp)
    # r = Expr(:call, :+)
    # for k = 1:(N - 1)
    #     ex = Expr(:call, :*, ntuple(d -> Symbol(:D_, d), k)...)
    #     push!(r.args, ex)
    # end
    # push!(e.args, r)
    # e
end

function sumprodconstant2(N::Int)
    Expr(:(=), :D_sp, Expr(:call, :+, ntuple(d -> Symbol(:D_, ntuple(identity, d)...), N - 1)...))
end

prog = "a == b ? 5 : 10"
ex = Meta.parse(prog)
Meta.show_sexpr(ex)
# Expr(:?, Expr(:call, :(==), :a, :b), 5, 10)
prog2 = "if a == b
    5
    else
    10
    end"
ex2 = Meta.parse(prog2)
Meta.show_sexpr(ex2)
prog3 = "ifelse(a == b, 5, 10)"
ex3 = Meta.parse(prog3)
Meta.show_sexpr(ex3)
prog4 = "a = -a"
ex4 = Meta.parse(prog4)
Meta.show_sexpr(ex4)

function compareblock(N::Int, D)
    block = Expr(:block)
    params = D.parameters
    a = Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...)
    b = Expr(:ref, :B, ntuple(d -> params[d] == Static.One ? 1 : Symbol(:i_, d), N)...)
    c = Expr(:ref, :C, ntuple(d -> params[d] == Static.One ? 1 : Symbol(:i_, d), N)...)
    # y = Expr(:(=), :yes, Expr(:call, :(==), a, b))
    # e = Expr(:(=), c, Expr(:if, y, sumprodliteral(N), c))
    # push!(block.args, y)
    e = Expr(:(=), c, Expr(:if, Expr(:call, :(==), a, b), sumprodliteral(N), c))
    push!(block.args, e)
    block
end

function compareblock2(N::Int, D)
    block = Expr(:block)
    params = D.parameters
    a = Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...)
    b = Expr(:ref, :B, ntuple(d -> params[d] == Static.One ? 1 : Symbol(:i_, d), N)...)
    c = Expr(:ref, :C, ntuple(d -> params[d] == Static.One ? 1 : Symbol(:i_, d), N)...)
    d = sumprodprecomputed2(N)
    push!(d.args, :D_sp)
    e = Expr(:(=), c, Expr(:if, Expr(:call, :(==), a, b), d, c))
    push!(block.args, e)
    block
end

# function compareblock3(N::Int, D)
#     block = Expr(:block)
#     params = D.parameters
#     a = Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...)
#     b = Expr(:ref, :B, ntuple(d -> params[d] == Static.One ? 1 : Symbol(:i_, d), N)...)
#     c = Expr(:ref, :C, ntuple(d -> params[d] == Static.One ? 1 : Symbol(:i_, d), N)...)
#     d = sumprodprecomputed2(N)
#     push!(d.args, :D_sp)
#     # e = Expr(:if, Expr(:call, :(==), a, b), Expr(:(=), c, d))
#     j = Expr(:(=), :j, c)
#     e = Expr(:(=), c, Expr(:if, Expr(:call, :(==), a, b), d, :j))
#     push!(block.args, j)
#     push!(block.args, e)
#     block
# end

function compareblock4(N::Int, D)
    block = Expr(:block)
    params = D.parameters
    a = Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...)
    b = Expr(:ref, :B, ntuple(d -> params[d] == Static.One ? 1 : Symbol(:i_, d), N)...)
    c = Expr(:ref, :C, ntuple(d -> Symbol(:i_, d), N)...)
    e = Expr(:(=), c, Expr(:call, :(==), a, b))
    push!(block.args, e)
    block
end

# p. 26
function outerloopgen(N::Int, D)
    loops = Expr(:for)
    block = Expr(:block)
    params = D.parameters
    for d = N:-1:1
        if params[d] != Static.One
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
        if params[d] == Static.One
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
    b = Expr(:ref, :B, ntuple(d -> params[d] == Static.One ? 1 : Symbol(:i_, d), N)...)
    c = Expr(:ref, :C, ntuple(d -> params[d] == Static.One ? 1 : Symbol(:i_, d), N)...)
    e1 = Expr(:(=), b, :m)
    e2 = Expr(:(=), c, :j)
    push!(block.args, e1)
    push!(block.args, e2)
    block
end

function compareblock5(N::Int, D)
    block = Expr(:block)
    params = D.parameters
    a = Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...)
    d = sumprodprecomputed2(N)
    push!(d.args, :D_sp)
    yₑ = Expr(:(=), :y, Expr(:call, :(>), a, :m))
    mₑ = Expr(:(=), :m, Expr(:if, :y, a, :m))
    jₑ = Expr(:(=), :j, Expr(:if, :y, d, :j))
    push!(block.args, yₑ)
    push!(block.args, mₑ)
    push!(block.args, jₑ)
    block
end

function findmax5_quote(N::Int, D)
    block1 = sizeblock(N)
    block2 = sizeproductsblock(N)
    block3 = Expr(:block, sumprodconstant(N), Expr(:(=), :D_sp, Expr(:call, :-, :D_sp)))
    outerloops = outerloopgen(N, D)
    block4 = Expr(:block, Expr(:(=), :j, 1), Expr(:(=), :m, Expr(:call, :typemin, :T)))
    # push!(outerloops.args, block4)
    innerloops = innerloopgen(N, D)
    block5 = compareblock5(N, D)
    push!(innerloops.args, block5)
    push!(block4.args, innerloops)
    # push!(outerloops.args, block4)
    # push!(outerloops.args, innerloops)
    block6 = innerpost(N, D)
    # push!(outerloops.args, block6)
    push!(block4.args, block6.args...)
    push!(outerloops.args, block4)
    return quote
        $block1
        $block2
        $block3
        $outerloops
    end
end

function findequal_quote(N::Int, D)
    loops = loopgen(N)
    block1 = sizeblock(N)
    block2 = compareblock(N, D)
    push!(loops.args, block2)
    return quote
        $block1
        $loops
    end
end

function findequal_quote2(N::Int, D)
    loops = loopgen(N)
    block1 = sizeblock(N)
    block2 = sizeproductsblock(N)
    block3 = Expr(:block, sumprodconstant(N), Expr(:(=), :D_sp, Expr(:call, :-, :D_sp)))
    block4 = compareblock2(N, D)
    push!(loops.args, block4)
    return quote
        $block1
        $block2
        $block3
        @turbo $loops
    end
end
# function findequal_quote3(N::Int, D)
#     loops = loopgen(N)
#     block1 = sizeblock(N)
#     block2 = sizeproductsblock(N)
#     block3 = Expr(:block, sumprodconstant(N), Expr(:(=), :D_sp, Expr(:call, :-, :D_sp)))
#     block4 = compareblock3(N, D)
#     push!(loops.args, block4)
#     return quote
#         $block1
#         $block2
#         $block3
#         @turbo $loops
#     end
# end

function findequal_quote4(N::Int, D)
    loops = loopgen(N)
    block = compareblock4(N, D)
    push!(loops.args, block)
    return quote
        @turbo $loops
    end
end

@generated function findequal!(C::AbstractArray{Tₒ, N}, A::AbstractArray{T, N},
                               B::AbstractArray{T, N}, dims::D) where {Tₒ, T, N, D}
    findequal_quote2(N, D)
end
# @generated function findequal3!(C::AbstractArray{Tₒ, N}, A::AbstractArray{T, N},
#                                B::AbstractArray{T, N}, dims::D) where {Tₒ, T, N, D}
#     findequal_quote3(N, D)
# end
@generated function findequal4!(C::AbstractArray{Tₒ, N}, A::AbstractArray{T, N},
                                B::AbstractArray{T, N}, dims::D) where {Tₒ, T, N, D}
    findequal_quote4(N, D)
end

@generated function findmax5!(C::AbstractArray{Tₒ, N}, A::AbstractArray{T, N},
                              B::AbstractArray{T, N}, dims::D) where {Tₒ, T, N, D}
    findmax5_quote(N, D)
end

A = reshape([1:(4*3*5);], 4, 3, 5);
A = rand(1:10, 4, 3, 5);
dims = (2,);
Dᴮ′ = ntuple(d -> d ∈ dims ? StaticInt(1) : size(A, d), ndims(A));
findequal_quote(ndims(A), typeof(Dᴮ′))
findequal_quote2(ndims(A), typeof(Dᴮ′))
findequal_quote3(ndims(A), typeof(Dᴮ′))
findmax5_quote(ndims(A), typeof(Dᴮ′))

# C0 = deepcopy(C);
B = maximum(A, dims=dims);
C = ones(Int, size(B));

CartesianIndices(A)[C] == argmax(A, dims=dims)

compareblock(ndims(A), typeof(Dᴮ′))
compareblock2(ndims(A), typeof(Dᴮ′))
compareblock3(ndims(A), typeof(Dᴮ′))

function lvfindmax(A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
    B = lvmaximum(A, dims=dims)
    Dᴮ′ = ntuple(d -> d ∈ dims ? StaticInt(1) : size(A, d), N)
    C = ones(Int, size(B))
    findequal!(C, A, B, Dᴮ′)
    C
end
C2 = lvfindmax(A, dims)

CartesianIndices(A)[C2] == argmax(A, dims=dims)
LinearIndices(A)[argmax(A, dims=dims)]

# function lvfindmax3(A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
#     B = lvmaximum(A, dims=dims)
#     Dᴮ′ = ntuple(d -> d ∈ dims ? StaticInt(1) : size(A, d), N)
#     C = ones(Int, size(B))
#     findequal3!(C, A, B, Dᴮ′)
#     C
# end
# C3 = lvfindmax3(A, dims)

# function lvfindmax4(A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
#     B = lvmaximum(A, dims=dims)
#     Dᴮ′ = ntuple(d -> d ∈ dims ? StaticInt(1) : size(A, d), N)
#     C = similar(A, Bool)
#     findequal4!(C, A, B, Dᴮ′)
#     C
# end
# C4 = lvfindmax4(A, dims)
# reshape(findall(C4), size(B)) == argmax(A, dims=dims) == reshape(CartesianIndices(A)[C4], size(B))

function lvfindmax5(A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
    Dᴮ′ = ntuple(d -> d ∈ dims ? StaticInt(1) : size(A, d), N)
    B = similar(A, Dᴮ′)
    C = similar(B, Int)
    findmax5!(C, A, B, Dᴮ′)
    B, CartesianIndices(A)[C]
end
C5 = lvfindmax5(A, dims)
CartesianIndices(A)[C5] == argmax(A, dims=dims)
lvfindmax5(A, dims)
findmax(A, dims=dims)
lvfindmax5(A, dims) == findmax(A, dims=dims)


function lvfindequal(A::AbstractArray{T, 3}, B::AbstractArray{T, 3}) where {T}
    C = similar(B, Int)
    D_1 = size(A, 1)
    D_2 = size(A, 2)
    D_3 = size(A, 3)
    D_12 = D_1 * D_2
    D_sp = (*)(D_1) + D_1 * D_2
    D_sp = -D_sp
    @turbo for i_3 = axes(A, 3), i_1 = axes(A, 1)
        j = 1
        m = B[i_1, 1, i_3]
        for i_2 = axes(A, 2)
            # j = if A[i_1, i_2, i_3] == m
            #     i_1 + D_1 * i_2 + D_12 * i_3 + D_sp
            # else
            #     j
            # end
            yes = A[i_1, i_2, i_3] == m
            j = yes ? i_1 + D_1 * i_2 + D_12 * i_3 + D_sp : j
        end
        C[i_1, 1, i_3] = j
    end
    C
end
C5 = lvfindequal(A, B)
CartesianIndices(A)[C5] == argmax(A, dims=dims)


# an experiment -- seems to work
function lvfindmax5(A::AbstractArray{T, 3}, dims::NTuple{M, Int}) where {T, M}
    Dᴮ′ = ntuple(d -> d ∈ dims ? StaticInt(1) : size(A, d), 3)
    B = similar(A, Dᴮ′)
    C = similar(B, Int)
    D_1 = size(A, 1)
    D_2 = size(A, 2)
    D_3 = size(A, 3)
    D_12 = D_1 * D_2
    D_sp = (*)(D_1) + D_1 * D_2
    D_sp = -D_sp
    @turbo for i_3 = axes(A, 3), i_1 = axes(A, 1)
        j = 1
        m = typemin(T)
        for i_2 = axes(A, 2)
            # j = if A[i_1, i_2, i_3] == m
            #     i_1 + D_1 * i_2 + D_12 * i_3 + D_sp
            # else
            #     j
            # end
            yes = A[i_1, i_2, i_3] > m
            m = yes ? A[i_1, i_2, i_3] : m
            j = yes ? i_1 + D_1 * i_2 + D_12 * i_3 + D_sp : j
        end
        B[i_1, 1, i_3] = m
        C[i_1, 1, i_3] = j
    end
    B, C
end

B5, C5 = lvfindmax5(A, (1,))
A[C5] == B5
b5, c5 = findmax(A, dims=1)
b5 == B5
c5 == CartesianIndices(A)[C5]
