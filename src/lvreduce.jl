#
# Date created: 2022-03-08
# Author: aradclif
#
#
############################################################################################
# Cleaned version of experimental.jl

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

function reducebody(f, N, D)
    body = Expr(:block)
    a = Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...)
    b = Expr(:ref, :B, ntuple(d -> D[d] == 1 ? 1 : Symbol(:i_, d), N)...)
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

#### quote for use in @generated
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
    return quote
        @turbo $ls
        return B
    end
end
function mapreduce_quote(F, OP, N::Int, D)
    ls = loopgen(N)
    body = Expr(:block)
    params = D.parameters
    f = F.instance
    op = OP.instance
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

function mreduce(f, A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
    Dᴬ = size(A)
    Dᴮ = ntuple(d -> d ∈ dims ? 1 : Dᴬ[d], N)
    B = zeros(Base.promote_op(f, T), Dᴮ)
    Dᴮ′ = ntuple(d -> StaticInt(Dᴮ[d]), N)
    _mreduce!(f, B, A, Dᴮ′)
    B
end
