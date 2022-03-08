#
# Date created: 2022-03-08
# Author: aradclif
#
#
############################################################################################
#### Experiments with programmatic generation

prog = "for i = 1:5
i + 1
end"
ex = Meta.parse(prog)

prog2 = "for i = 1:5, j = 1:4
i + j + 1
end"
ex2 = Meta.parse(prog2)

prog3 = "for i = 1:5 i + 1 end"
ex3 = Meta.parse(prog3)

prog4 = "for i = 1:5, j = 1:4 i + j + 1 end"
ex4 = Meta.parse(prog4)

Meta.show_sexpr(ex) == Meta.show_sexpr(ex3)
Meta.show_sexpr(ex2) == Meta.show_sexpr(ex4)

A = [1 2 3; 4 5 6]
B = zeros(Int, 1, 3)

prog5 = "for i = axes(A, 1)
i + 1
end"
ex5 = Meta.parse(prog5)

prog6 = "for i = axes(A, 1), j = axes(A, 2)
i + j + 1
end"
ex6 = Meta.parse(prog6)

prog7 = "for i = eachindex(A)
i + 1
end"
ex7 = Meta.parse(prog7)

#### Literal reconstructions
# building ex programmatically
_ex = Expr(:for)
e1 = Expr(:(=), :i)
e12 = Expr(:call, :(:), 1, 5)
push!(e1.args, e12)
push!(_ex.args, e1)
e2 = Expr(:block)
# e21 = :(#= none:2 =#)
# push!(e2.args, e21)
e22 = Expr(:call, :+, :i, 1)
push!(e2.args, e22)
push!(_ex.args, e2)

# building ex2 programmatically
_ex = Expr(:for)
e1 = Expr(:block)
e11 = Expr(:(=), :i)
e112 = Expr(:call, :(:), 1, 5)
push!(e11.args, e112)
push!(e1.args, e11)
e12 = Expr(:(=), :j)
e122 = Expr(:call, :(:), 1, 4)
push!(e12.args, e122)
push!(e1.args, e12)
push!(_ex.args, e1)
e2 = Expr(:block)
# e21 = :(#= none:2 =#)
# push!(e2.args, e21)
e22 = Expr(:call, :+, :i, :j, 1)
push!(e2.args, e22)
push!(_ex.args, e2)

# building ex, revised to conform with @nloops
loops = Expr(:for)
ex = Expr(:(=), Symbol(:i_, 1))
ax = Expr(:call, :axes, :A, 1)
push!(ex.args, ax)
push!(loops.args, ex)
body = Expr(:block)
e = Expr(:call, :+, Symbol(:i_, 1), 1)
# e = Expr(:call, :println, Expr(:call, :+, Symbol(:i_, 1), 1))
# e = Expr(:macrocall, :@show, Expr(:call, :+, Symbol(:i_, 1), 1))
push!(body.args, e)
push!(loops.args, body)

# building ex2, revised to conform with @nloops
N = ndims(A)
loops = Expr(:for)
block = Expr(:block)
for d = N:-1:1
    ex = Expr(:(=), Symbol(:i_, d), Expr(:call, :axes, :A, d))
    push!(block.args, ex)
end
push!(loops.args, block)
body = Expr(:block)
# create e somewhere...
# a couple examples:
# e = Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...)
# e = Expr(:call, :+, Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...), 1)
a = Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...)
e = Expr(:(=), a, Expr(:call, :+, a, 1))
push!(body.args, e)
push!(loops.args, body)

function loopgen(N::Int) #A::AbstractArray{T, N} where {T, N}
    if N == 1
        loops = Expr(:for)
        ex = Expr(:(=), Symbol(:i_, 1), Expr(:call, :axes, :A, 1))
        push!(loops.args, ex)
    else
        loops = Expr(:for)
        block = Expr(:block)
        for d = N:-1:1
            ex = Expr(:(=), Symbol(:i_, d), Expr(:call, :axes, :A, d))
            push!(block.args, ex)
        end
        push!(loops.args, block)
    end
    return loops
end
loopgen(A::AbstractArray{T, N}) where {T, N} = loopgen(N)

ls = loopgen(A)
push!(ls.args, body)

# Another experiment
h(x, y) = x * x + y
body = Expr(:block)
a = Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...)
e = Expr(:(=), a, Expr(:call, :h, a, 1))
push!(body.args, e)
ls = loopgen(A)
push!(ls.args, body)

function reducebody1(f, A::AbstractArray{T, N}) where {T, N}
    body = Expr(:block)
    a = Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...)
    e = Expr(:(=), a, Expr(:call, Symbol(f), a, 1))
    push!(body.args, e)
    body
end

ls = loopgen(A)
body = reducebody1(h, A)
push!(ls.args, body)

g(x, y) = x * (x + y)
ls = loopgen(A)
body = reducebody1(g, A)
push!(ls.args, body)

# Body expressions
ls = loopgen(A)
body = Expr(:block)
a = Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...)
b = Expr(:ref, :B, ntuple(d -> length(axes(B, d)) == 1 ? 1 : Symbol(:i_, d), N)...)
e = Expr(:(=), b, Expr(:call, :+, b, a))
# e = Expr(:(=), b, Expr(:call, :h, b, a))
push!(body.args, e)
push!(ls.args, body)

function reducebody(f, B::AbstractArray{T, N}, A::AbstractArray{T, N}) where {T, N}
    body = Expr(:block)
    a = Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...)
    b = Expr(:ref, :B, ntuple(d -> length(axes(B, d)) == 1 ? 1 : Symbol(:i_, d), N)...)
    e = Expr(:(=), b, Expr(:call, Symbol(f), b, a))
    push!(body.args, e)
    body
end

ls = loopgen(A)
body = reducebody(+, B, A)
push!(ls.args, body)
# Anonymous
y = (x, y) -> x * x
ls = loopgen(A)
body = reducebody(y, B, A)
push!(ls.args, body)

function reduce_quote(f, A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
    Dᴬ = size(A)
    Dᴮ = ntuple(d -> d ∈ dims ? 1 : Dᴬ[d], N)
    # B = similar(A, Base.promote_op(f, T), Dᴮ)
    ls = loopgen(A)
    body = reducebody(f, B, A)
    push!(ls.args, body)
    ls
end

function reducebody(f, N, D)
    body = Expr(:block)
    a = Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...)
    b = Expr(:ref, :B, ntuple(d -> D[d] == 1 ? 1 : Symbol(:i_, d), N)...)
    # type-stable? slower, actually
    # a = Expr(:ref, :A)
    # b = Expr(:ref, :B)
    # append!(b.args, ntuple(d -> D[d] == 1 ? 1 : Symbol(:i_, d), N))
        # for d = 1:N
    #     push!(a.args, Symbol(:i_, d))
    #     push!(b.args, D[d] == 1 ? 1 : Symbol(:i_, d))
    # end
    e = Expr(:(=), b, Expr(:call, Symbol(f), b, a))
    push!(body.args, e)
    body
end
function mapreducebody(f, op, N, D)
    body = Expr(:block)
    a = Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...)
    b = Expr(:ref, :B, ntuple(d -> D[d] == 1 ? 1 : Symbol(:i_, d), N)...)
    e = Expr(:(=), b, Expr(:call, Symbol(op), b, Expr(:call, Symbol(f), a)))
    push!(body.args, e)
    body
end
reducebody(|, 2, (1,3))
mapreducebody(abs2, +, 2, (1,3))
#### An attempt at reduce quote for use in @generated
function reduce_quote(F, N::Int, D)
    ls = loopgen(N)
    body = Expr(:block)
    params = D.parameters
    f = F.instance
    a = Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...)
    b = Expr(:ref, :B, ntuple(d -> params[d] == Static.One ? 1 : Symbol(:i_, d), N)...)
    e = Expr(:(=), b, Expr(:call, Symbol(f), b, a))
    push!(body.args, e)
    push!(ls.args, body)
    # return quote
    #     $ls
    #     return B
    # end
    ls
end
function mapreduce_quote(F, O, N::Int, D)
    ls = loopgen(N)
    body = Expr(:block)
    params = D.parameters
    f = F.instance
    op = O.instance
    a = Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...)
    b = Expr(:ref, :B, ntuple(d -> params[d] == Static.One ? 1 : Symbol(:i_, d), N)...)
    e = Expr(:(=), b, Expr(:call, Symbol(op), b, Expr(:call, Symbol(f), a)))
    push!(body.args, e)
    push!(ls.args, body)
    # return quote
    #     $ls
    #     return B
    # end
    ls
end
Db = size(B)
D_b = ntuple(d -> StaticInt(Db[d]), N)
reduce_quote(typeof(+), 2, typeof(D_b))
m2reduce_quote(typeof(+), 2, typeof(D_b))

function mreduce(f, A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
    Dᴬ = size(A)
    Dᴮ = ntuple(d -> d ∈ dims ? 1 : Dᴬ[d], N)
    B = zeros(Base.promote_op(f, T), Dᴮ)
    Dᴮ′ = ntuple(d -> StaticInt(Dᴮ[d]), N)
    _mreduce!(f, B, A, Dᴮ′)
    B
end

@generated function _mreduce!(f::F, B::AbstractArray{T, N}, A::AbstractArray{T, N}, dims::D) where {F, T, N, D}
    reduce_quote(F, N, D)
end
function mapmreduce(f, op, A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
    Dᴬ = size(A)
    Dᴮ = ntuple(d -> d ∈ dims ? 1 : Dᴬ[d], N)
    B = zeros(Base.promote_op(f, T), Dᴮ)
    Dᴮ′ = ntuple(d -> StaticInt(Dᴮ[d]), N)
    _mapmreduce!(f, op, B, A, Dᴮ′)
    B
end

@generated function _mapmreduce!(f::F, op::O, B::AbstractArray{T, N}, A::AbstractArray{T, N}, dims::D) where {F, O, T, N, D}
    mapreduce_quote(F, O, N, D)
end

A = rand(1000, 1000, 1000);
@benchmark mreduce(+, A, (1,))
@benchmark reduce(+, A, dims=(3,))
@benchmark m2reduce(+, A, (3,))
@benchmark m2treduce(+, A, (3,))
@benchmark mapmreduce(abs2, +, A, (3,))
@benchmark mapreduce(abs2, +, A, dims=(3,))
@benchmark mapm2reduce(abs2, +, A, (3,))
@benchmark mapm2treduce(abs2, +, A, (3,))
mreduce(|, A, (1,))
reduce(|, A, dims=(1,), init=0)
m2reduce(+, A, (1,))
m2treduce(+, A, (1,))
mapmreduce(cos, +, A, (1,))
mapreduce(abs2, +, A, dims=(1,))
mapm2reduce(cos, +, A, (1,))
mapm2treduce(abs2, +, A, (1,))


function m2reduce_quote(F, N::Int, D)
    ls = loopgen(N)
    body = Expr(:block)
    params = D.parameters
    f = F.instance
    a = Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...)
    b = Expr(:ref, :B, ntuple(d -> params[d] == Static.One ? 1 : Symbol(:i_, d), N)...)
    e = Expr(:(=), b, Expr(:call, Symbol(f), b, a))
    push!(body.args, e)
    push!(ls.args, body)
    return quote
        @turbo $ls
        return B
    end
end
function m2reduce(f, A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
    Dᴬ = size(A)
    Dᴮ = ntuple(d -> d ∈ dims ? 1 : Dᴬ[d], N)
    B = zeros(Base.promote_op(f, T), Dᴮ)
    Dᴮ′ = ntuple(d -> StaticInt(Dᴮ[d]), N)
    _m2reduce!(f, B, A, Dᴮ′)
    B
end
@generated function _m2reduce!(f::F, B::AbstractArray{T, N}, A::AbstractArray{T, N}, dims::D) where {F, T, N, D}
    m2reduce_quote(F, N, D)
end

function m2treduce_quote(F, N::Int, D)
    ls = loopgen(N)
    body = Expr(:block)
    params = D.parameters
    f = F.instance
    a = Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...)
    b = Expr(:ref, :B, ntuple(d -> params[d] == Static.One ? 1 : Symbol(:i_, d), N)...)
    e = Expr(:(=), b, Expr(:call, Symbol(f), b, a))
    push!(body.args, e)
    push!(ls.args, body)
    return quote
        @tturbo $ls
        return B
    end
end
function m2treduce(f, A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
    Dᴬ = size(A)
    Dᴮ = ntuple(d -> d ∈ dims ? 1 : Dᴬ[d], N)
    B = zeros(Base.promote_op(f, T), Dᴮ)
    Dᴮ′ = ntuple(d -> StaticInt(Dᴮ[d]), N)
    _m2treduce!(f, B, A, Dᴮ′)
    B
end
@generated function _m2treduce!(f::F, B::AbstractArray{T, N}, A::AbstractArray{T, N}, dims::D) where {F, T, N, D}
    m2treduce_quote(F, N, D)
end


function mapm2reduce_quote(F, O, N::Int, D)
    ls = loopgen(N)
    body = Expr(:block)
    params = D.parameters
    f = F.instance
    op = O.instance
    a = Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...)
    b = Expr(:ref, :B, ntuple(d -> params[d] == Static.One ? 1 : Symbol(:i_, d), N)...)
    e = Expr(:(=), b, Expr(:call, Symbol(op), b, Expr(:call, Symbol(f), a)))
    push!(body.args, e)
    push!(ls.args, body)
    return quote
        @turbo $ls
        return B
    end
end
function mapm2reduce(f, op, A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
    Dᴬ = size(A)
    Dᴮ = ntuple(d -> d ∈ dims ? 1 : Dᴬ[d], N)
    B = zeros(Base.promote_op(f, T), Dᴮ)
    Dᴮ′ = ntuple(d -> StaticInt(Dᴮ[d]), N)
    _mapm2reduce!(f, op, B, A, Dᴮ′)
    B
end

@generated function _mapm2reduce!(f::F, op::O, B::AbstractArray{T, N}, A::AbstractArray{T, N}, dims::D) where {F, O, T, N, D}
    mapm2reduce_quote(F, O, N, D)
end

function mapm2treduce_quote(F, O, N::Int, D)
    ls = loopgen(N)
    body = Expr(:block)
    params = D.parameters
    f = F.instance
    op = O.instance
    a = Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...)
    b = Expr(:ref, :B, ntuple(d -> params[d] == Static.One ? 1 : Symbol(:i_, d), N)...)
    e = Expr(:(=), b, Expr(:call, Symbol(op), b, Expr(:call, Symbol(f), a)))
    push!(body.args, e)
    push!(ls.args, body)
    return quote
        @tturbo $ls
        return B
    end
end
function mapm2treduce(f, op, A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
    Dᴬ = size(A)
    Dᴮ = ntuple(d -> d ∈ dims ? 1 : Dᴬ[d], N)
    B = zeros(Base.promote_op(f, T), Dᴮ)
    Dᴮ′ = ntuple(d -> StaticInt(Dᴮ[d]), N)
    _mapm2treduce!(f, op, B, A, Dᴮ′)
    B
end

@generated function _mapm2treduce!(f::F, op::O, B::AbstractArray{T, N}, A::AbstractArray{T, N}, dims::D) where {F, O, T, N, D}
    mapm2treduce_quote(F, O, N, D)
end
