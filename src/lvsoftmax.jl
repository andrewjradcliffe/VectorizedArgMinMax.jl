#
# Date created: 2022-03-10
# Author: aradclif
#
#
############################################################################################
# Why not just exp! the result of lvlogsoftmax? Consider that such an approach would perform
# the operations:
# C[i_1,…] = A[i_1,…] - B[i_1, 1, …]
# C[i_1,…] = exp(C[i_1,…])
# One can combine this in order to traverse the memory once, i.e.
# C[i_1,…] = exp(A[i_1,…] - B[i_1, 1, …])

function aminusb_expbody(N::Int, D)
    body = Expr(:block)
    params = D.parameters
    a = Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...)
    b = Expr(:ref, :B, ntuple(d -> params[d] == Static.One ? 1 : Symbol(:i_, d), N)...)
    c = Expr(:ref, :C, ntuple(d -> Symbol(:i_, d), N)...)
    e = Expr(:(=), c, Expr(:call, :exp, Expr(:call, :-, a, b)))
    push!(body.args, e)
    body
end

function aminusb_exp_quote(N::Int, D)
    ls = loopgen(N)
    body = aminusb_expbody(N, D)
    push!(ls.args, body)
    return quote
        @turbo $ls
        return C
    end
end

@generated function aminusb_exp!(C::AbstractArray{T, N}, A::AbstractArray{T, N}, B::AbstractArray{T, N}, dims::D) where {T, N, D}
    aminusb_exp_quote(N, D)
end

function lvsoftmax(A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
    B = lvlse(A, dims=dims)
    Dᴮ′ = ntuple(d -> d ∈ dims ? StaticInt(1) : size(B, d), N)
    C = similar(A, promote_type(T, eltype(B)))
    aminusb_exp!(C, A, B)
    C
end

