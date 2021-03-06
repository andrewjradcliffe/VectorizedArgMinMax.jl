#
# Date created: 2022-03-09
# Author: aradclif
#
#
############################################################################################

function aminusb_exp_sumbody(N::Int, D)
    body = Expr(:block)
    params = D.parameters
    a = Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...)
    b = Expr(:ref, :B, ntuple(d -> params[d] == Static.One ? 1 : Symbol(:i_, d), N)...)
    c = Expr(:ref, :C, ntuple(d -> params[d] == Static.One ? 1 : Symbol(:i_, d), N)...)
    e = Expr(:(=), c, Expr(:call, :+, c, Expr(:call, :exp, Expr(:call, :-, a, b))))
    push!(body.args, e)
    body
end

function aminusb_exp_sum_quote(N::Int, D)
    ls = loopgen(N)
    body = aminusb_exp_sumbody(N, D)
    push!(ls.args, body)
    return quote
        @turbo $ls
        return C
    end
end

@generated function aminusb_exp_sum!(C::AbstractArray{Tₒ, N}, A::AbstractArray{T, N}, B::AbstractArray{T, N}, dims::D) where {Tₒ, T, N, D}
    aminusb_exp_sum_quote(N, D)
end

function logself_plusb!(C::AbstractArray{Tₒ, N}, B::AbstractArray{T, N}) where {Tₒ, T, N}
    @turbo for i ∈ eachindex(C)
        C[i] = B[i] + log(C[i])
    end
    C
end

function lvlogsumexp(A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
    if ntuple(identity, Val(N)) ⊆ dims
        # return hvncat(ntuple(i -> 1, Val(N)), true, lvlogsumexp1(A))
        C = hvncat(ntuple(i -> 1, Val(N)), true, lvlogsumexp1(A))
    else
        B = lvmaximum(A, dims=dims)
        Dᴮ = size(B)
        Dᴮ′ = ntuple(d -> d ∈ dims ? StaticInt(1) : Dᴮ[d], N)
        C = zeros(Base.promote_op(exp, T), Dᴮ)
        aminusb_exp_sum!(C, A, B, Dᴮ′)
        logself_plusb!(C, B)
        # return C
    end
    return C
end

lvlogsumexp(A::AbstractArray{T, N}, dims::Int) where {T, N} = lvlogsumexp(A, (dims,))
lvlogsumexp(A::AbstractArray{T, N}; dims=:) where {T, N} = lvlogsumexp(A, dims)
lvlogsumexp(A::AbstractArray{T, N}) where {T, N} = lvlogsumexp1(A)
lvlogsumexp(A::AbstractArray{T, N}, ::Colon) where {T, N} = lvlogsumexp1(A)

function lvlogsumexp1(A::AbstractArray{T, N}) where {T, N}
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
function taminusb_exp_sum_quote(N::Int, D)
    ls = loopgen(N)
    body = aminusb_exp_sumbody(N, D)
    push!(ls.args, body)
    return quote
        @tturbo $ls
        return B
    end
end

@generated function taminusb_exp_sum!(C::AbstractArray{Tₒ, N}, A::AbstractArray{T, N}, B::AbstractArray{T, N}, dims::D) where {Tₒ, T, N, D}
    taminusb_exp_sum_quote(N, D)
end

function tlogself_plusb!(C::AbstractArray{Tₒ, N}, B::AbstractArray{T, N}) where {Tₒ, T, N}
    @tturbo for i ∈ eachindex(C)
        C[i] = B[i] + log(C[i])
    end
    C
end

function lvtlogsumexp(A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
    if ntuple(identity, Val(N)) ⊆ dims
        C = hvncat(ntuple(i -> 1, Val(N)), true, lvtlogsumexp1(A))
    else
        B = lvtmaximum(A, dims=dims)
        Dᴮ = size(B)
        Dᴮ′ = ntuple(d -> d ∈ dims ? StaticInt(1) : Dᴮ[d], N)
        C = zeros(Base.promote_op(exp, T), Dᴮ)
        taminusb_exp_sum!(C, A, B, Dᴮ′)
        tlogself_plusb!(C, B)
        C
    end
    return C
end

lvtlogsumexp(A::AbstractArray{T, N}, dims::Int) where {T, N} = lvtlogsumexp(A, (dims,))
lvtlogsumexp(A::AbstractArray{T, N}; dims=:) where {T, N} = lvtlogsumexp(A, dims)
lvtlogsumexp(A::AbstractArray{T, N}) where {T, N} = lvtlogsumexp1(A)
lvtlogsumexp(A::AbstractArray{T, N}, ::Colon) where {T, N} = lvtlogsumexp1(A)

function lvtlogsumexp1(A::AbstractArray{T, N}) where {T, N}
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
