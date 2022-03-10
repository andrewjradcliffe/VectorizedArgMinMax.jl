#
# Date created: 2022-03-09
# Author: aradclif
#
#
############################################################################################

function expminusbody(N::Int, D)
    body = Expr(:block)
    params = D.parameters
    a = Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...)
    b = Expr(:ref, :B, ntuple(d -> params[d] == Static.One ? 1 : Symbol(:i_, d), N)...)
    m = Expr(:ref, :α, ntuple(d -> params[d] == Static.One ? 1 : Symbol(:i_, d), N)...)
    e = Expr(:(=), b, Expr(:call, :+, b, Expr(:call, :exp, Expr(:call, :-, a, m))))
    push!(body.args, e)
    body
end

function expminus_quote(N::Int, D)
    ls = loopgen(N)
    body = expminusbody(N, D)
    push!(ls.args, body)
    return quote
        @turbo $ls
        return B
    end
end

@generated function expminus!(B::AbstractArray{T, N}, A::AbstractArray{T, N}, α::AbstractArray{T, N}, dims::D) where {T, N, D}
    expminus_quote(N, D)
end

function _apluslogb!(A::AbstractArray{T, N}, B::AbstractArray{T, N}) where {T, N}
    @turbo for i ∈ eachindex(A)
        A[i] += log(B[i])
    end
    A
end

function lvlse(A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
    α = lvmaximum(A, dims=dims)
    Dᴮ = size(α)
    B = zeros(Base.promote_op(exp, T), Dᴮ)
    Dᴮ′ = ntuple(d -> d ∈ dims ? StaticInt(1) : Dᴮ[d], N)
    expminus!(B, A, α, Dᴮ′)
    _apluslogb!(α, B)
    α
end
