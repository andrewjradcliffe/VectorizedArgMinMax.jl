#
# Date created: 2022-03-10
# Author: aradclif
#
#
############################################################################################

function aminusbbody(N::Int, D)
    body = Expr(:block)
    params = D.parameters
    a = Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...)
    b = Expr(:ref, :B, ntuple(d -> params[d] == Static.One ? 1 : Symbol(:i_, d), N)...)
    c = Expr(:ref, :C, ntuple(d -> Symbol(:i_, d), N)...)
    e = Expr(:(=), c, Expr(:call, :-, a, b))
    push!(body.args, e)
    body
end

function aminusb_quote(N::Int, D)
    ls = loopgen(N)
    body = aminusbbody(N, D)
    push!(ls.args, body)
    return quote
        @turbo $ls
        return C
    end
end

@generated function aminusb!(C::AbstractArray{T, N}, A::AbstractArray{T, N}, B::AbstractArray{T, N},
                             dims::D) where {T, N, D}
    aminusb_quote(N, D)
end

function exp!(A::AbstractArray{T, N}) where {T, N}
    @turbo for i ∈ eachindex(A)
        A[i] = exp(A[i])
    end
    A
end


function lvlogsoftmax(A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
    B = lvlse(A, dims=dims)
    Dᴮ′ = ntuple(d -> d ∈ dims ? StaticInt(1) : size(B, d), N)
    C = similar(A, promote_type(T, eltype(B)))
    aminusb!(C, A, B)
    C
end
