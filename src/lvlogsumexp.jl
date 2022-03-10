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

function apluslogb!(A::AbstractArray{T, N}, B::AbstractArray{T, N}) where {T, N}
    @turbo for i ∈ eachindex(A)
        A[i] += log(B[i])
    end
    A
end
function apluslogb!(C::AbstractArray{T, N}, A::AbstractArray{T, N}, B::AbstractArray{T, N}) where {T, N}
    @turbo for i ∈ eachindex(A)
        C[i] = A[i] + log(B[i])
    end
    C
end
apluslogb(A::AbstractArray{T, N}, B::AbstractArray{S, N}) where {T, N, S} =
    apluslogb!(similar(A, promote_type(T, S)), A, B)

function lvlse(A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
    α = lvmaximum(A, dims=dims)
    Dᴮ = size(α)
    Tₒ = Base.promote_op(exp, T)
    B = zeros(Tₒ, Dᴮ)
    Dᴮ′ = ntuple(d -> d ∈ dims ? StaticInt(1) : Dᴮ[d], N)
    expminus!(B, A, α, Dᴮ′)
    return eltype(α) <: AbstractFloat ? apluslogb!(α, B) : apluslog(α, B)
end

lvlse(A::AbstractArray{T, N}, dims::Int) where {T, N} = lvlse(A, (dims,))
lvlse(A::AbstractArray{T, N}; dims=:) where {T, N} = lvlse(A, dims)
lvlse(A::AbstractArray{T, N}) where {T, N} = lvlse1(A)
lvlse(A::AbstractArray{T, N}, ::Colon) where {T, N} = lvlse1(A)

function lvlse1(A::AbstractArray{T, N}) where {T, N}
    α = typemin(T)
    s = zero(promote_type(T, Float64))
    @turbo for i ∈ eachindex(A)
        α = max(A[i], α)
    end
    @turbo for i ∈ eachindex(A)
        s += exp(A[i] - α)
    end
    α + log(s)
end

################ threaded version
function texpminus_quote(N::Int, D)
    ls = loopgen(N)
    body = expminusbody(N, D)
    push!(ls.args, body)
    return quote
        @tturbo $ls
        return B
    end
end

@generated function texpminus!(B::AbstractArray{T, N}, A::AbstractArray{T, N}, α::AbstractArray{T, N}, dims::D) where {T, N, D}
    texpminus_quote(N, D)
end

function tapluslogb!(A::AbstractArray{T, N}, B::AbstractArray{T, N}) where {T, N}
    @tturbo for i ∈ eachindex(A)
        A[i] += log(B[i])
    end
    A
end
function tapluslogb!(C::AbstractArray{T, N}, A::AbstractArray{T, N}, B::AbstractArray{T, N}) where {T, N}
    @tturbo for i ∈ eachindex(A)
        C[i] = A[i] + log(B[i])
    end
    C
end
tapluslogb(A::AbstractArray{T, N}, B::AbstractArray{S, N}) where {T, N, S} =
    tapluslogb!(similar(A, promote_type(T, S)), A, B)

function lvtlse(A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
    α = lvtmaximum(A, dims=dims)
    Dᴮ = size(α)
    Tₒ = Base.promote_op(exp, T)
    B = zeros(Tₒ, Dᴮ)
    Dᴮ′ = ntuple(d -> d ∈ dims ? StaticInt(1) : Dᴮ[d], N)
    texpminus!(B, A, α, Dᴮ′)
    return eltype(α) <: AbstractFloat ? tapluslogb!(α, B) : tapluslog(α, B)
end

lvtlse(A::AbstractArray{T, N}, dims::Int) where {T, N} = lvtlse(A, (dims,))
lvtlse(A::AbstractArray{T, N}; dims=:) where {T, N} = lvtlse(A, dims)
lvtlse(A::AbstractArray{T, N}) where {T, N} = lvtlse1(A)
lvtlse(A::AbstractArray{T, N}, ::Colon) where {T, N} = lvtlse1(A)

function lvtlse1(A::AbstractArray{T, N}) where {T, N}
    α = typemin(T)
    s = zero(promote_type(T, Float64))
    @tturbo for i ∈ eachindex(A)
        α = max(A[i], α)
    end
    @tturbo for i ∈ eachindex(A)
        s += exp(A[i] - α)
    end
    α + log(s)
end
