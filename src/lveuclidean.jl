#
# Date created: 2022-03-10
# Author: aradclif
#
#
############################################################################################

function sumsqbody(N::Int, D)
    body = Expr(:block)
    params = D.parameters
    a = Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...)
    b = Expr(:ref, :B, ntuple(d -> params[d] == Static.One ? 1 : Symbol(:i_, d), N)...)
    δ = Expr(:(=), :Δ, a)
    e = Expr(:(=), b, Expr(:call, :+, b, Expr(:call, :*, :Δ, :Δ)))
    push!(body.args, δ)
    push!(body.args, e)
    body
end

function sumsq_quote(N::Int, D)
    ls = loopgen(N)
    body = sumsqbody(N, D)
    push!(ls.args, body)
    return quote
        @turbo $ls
        return B
    end
end

@generated function sumsq!(B::AbstractArray{T, N}, A::AbstractArray{T, N}, dims::D) where {T, N, D}
    sumsq_quote(N, D)
end

function sqrt!(A::AbstractArray{T, N}) where {T, N}
    @turbo for i ∈ eachindex(A)
        A[i] = sqrt(A[i])
    end
    A
end

function lveuclidean(A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
    Dᴬ = size(A)
    Dᴮ′ = ntuple(d -> d ∈ dims ? StaticInt(1) : Dᴬ[d], N)
    B = zeros(Base.promote_op(/, T, Int), Dᴮ′)
    sumsq!(B, A, Dᴮ′)
    sqrt!(B)
    B
end
