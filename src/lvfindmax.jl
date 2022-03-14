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

@generated function findequal!(C::AbstractArray{Tₒ, N}, A::AbstractArray{T, N},
                               B::AbstractArray{T, N}, dims::D) where {Tₒ, T, N, D}
    findequal_quote2(N, D)
end
# @generated function findequal3!(C::AbstractArray{Tₒ, N}, A::AbstractArray{T, N},
#                                B::AbstractArray{T, N}, dims::D) where {Tₒ, T, N, D}
#     findequal_quote3(N, D)
# end


A = reshape([1:(4*3*5);], 4, 3, 5);
dims = (2,);
Dᴮ′ = ntuple(d -> d ∈ dims ? StaticInt(1) : size(A, d), ndims(A));
findequal_quote(ndims(A), typeof(Dᴮ′))
findequal_quote2(ndims(A), typeof(Dᴮ′))
findequal_quote3(ndims(A), typeof(Dᴮ′))

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
