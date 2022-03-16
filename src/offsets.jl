#
# Date created: 2022-03-15
# Author: aradclif
#
#
############################################################################################

# Dᵢ ∀i    : size of each dimension
function sizeblock(N::Int)
    block = Expr(:block)
    for d = 1:N
        ex = Expr(:(=), Symbol(:D_, d), Expr(:call, :size, :A, d))
        push!(block.args, ex)
    end
    block
end

# ∏ᵢ₌₁ᵏ⁻¹Dᵢ    : D₁D₂⋯Dₖ₋₁
offsetk(k::Int) = Expr(:(=), Symbol(:D_, ntuple(identity, k - 1)...),
                       Expr(:call, :*, ntuple(d -> Symbol(:D_, d), k - 1)...))
#                      Expr(:call, :*, ntuple(d -> d == 1 ? 1 : Symbol(:D_, d), k)...))

# ∑ₖ₌₁ᴺ(∏ᵢ₌₁ᵏ⁻¹Dᵢ)    : 1 + D₁ + D₁D₂ + ⋯ + D₁D₂⋯Dₖ₋₁
totaloffsetraw(N::Int) =
    Expr(:(=), :Dstar, Expr(:call, :+, ntuple(d -> d == 1 ? Expr(:call, :*, 1) :
    Expr(:call, :*, ntuple(i -> Symbol(:D_, i), d - 1)...), N)...))
totaloffset(N::Int) =
    Expr(:(=), :Dstar, Expr(:call, :+, 1, ntuple(d -> Symbol(:D_, ntuple(identity, d)...), N - 1)...))


# ∑ₖ₌₁ᴺ(∏ᵢ₌₁ᵏ⁻¹Dᵢ)Iₖ    : I₁ + D₁I₂ + D₁D₂I₃ + ⋯ + D₁D₂⋯Dₖ₋₁Iₖ
dynamictermraw(N::Int) = Expr(:call, :+, ntuple(d -> d == 1 ? :i_1 :
    Expr(:call, :*, ntuple(i -> Symbol(:D_, i), d - 1)..., Symbol(:i_, d)), N)...)
dynamicterm(N::Int) = Expr(:call, :+, ntuple(d -> d == 1 ? :i_1 :
    Expr(:call, :*, Symbol(:D_, ntuple(identity, d - 1)...), Symbol(:i_, d)), N)...)

# Jₒ ≡ index set of outer loop
# Jᵢ ≡ index set of inner loop
# ∑ₖ(∏ᵢ₌₁ᵏ⁻¹Dᵢ)Iₖ    , k ∈ J
partialtermraw(J::NTuple{N, Int}) where {N} =
    Expr(:call, :+, ntuple(d -> J[d] == 1 ? :i_1 :
    Expr(:call, :*, ntuple(i -> Symbol(:D_, i), J[d] - 1)..., Symbol(:i_, J[d])), N)...)

partialterm(J::NTuple{N, Int}) where {N} =
    Expr(:call, :+, ntuple(d -> J[d] == 1 ? :i_1 :
    Expr(:call, :*, Symbol(:D_, ntuple(identity, J[d] - 1)...), Symbol(:i_, J[d])), N)...)

function preexprmax(J::NTuple{N, Int}) where {N}
    block = Expr(:block, Expr(:(=), :m, Expr(:call, :typemin, :T)))
    ex = partialterm(J)
    push!(ex.args, 1, :Dstar)
    push!(block.args, Expr(:(=), :j, ex))
    block
end
# function preexprmax2(J::NTuple{N, Int}) where {N}
#     Expr(:block, Expr(:(=), :m, Expr(:call, :typemin, :T)), Expr(:(=), :j, 0))
# end
function preexpr2(init::Symbol)
    Expr(:block, Expr(:(=), :m, Expr(:call, init, :T)), Expr(:(=), :j, 0))
end

function findmax_quote(N::Int, D)
    b1 = sizeblock(N)
    b2 = Expr(:block, ntuple(d -> offsetk(d + 2), N - 2)...)
    b3 = Expr(:block, totaloffsetraw(N), Expr(:(=), :Dstar, Expr(:call, :-, :Dstar)))
    b4 = preexprmax(tuple((d for d = 1:N if D.parameters[d] !== Val{1})...))
    inner = innerloop(N, D)
    push!(inner.args, maxblock(N, D))
    push!(b4.args, inner)
    push!(b4.args, postexpr(N, D).args...)
    outer = outerloop(N, D)
    push!(outer.args, b4)
    return quote
        $b1
        $b2
        $b3
        $outer
    end
end
function findmax_quote2(N::Int, D)
    b1 = sizeblock(N)
    b2 = Expr(:block, ntuple(d -> offsetk(d + 2), N - 2)...)
    b3 = Expr(:block, totaloffsetraw(N), Expr(:(=), :Dstar, Expr(:call, :-, :Dstar)))
    b4 = preexpr2(:typemin)
    inner = innerloop(N, D)
    push!(inner.args, maxblock2(N, D))
    push!(b4.args, inner)
    push!(b4.args, postexpr(N, D).args...)
    outer = outerloop(N, D)
    push!(outer.args, b4)
    return quote
        $b1
        $b2
        $b3
        $outer
    end
end
function findmax_quote3(N::Int, D)
    b1 = sizeblock(N)
    b2 = Expr(:block, ntuple(d -> offsetk(d + 2), N - 2)...)
    b3 = Expr(:block, totaloffsetraw(N), Expr(:(=), :Dstar, Expr(:call, :-, :Dstar)))
    b4 = preexpr2(:typemin)
    inner = innerloop(N, D)
    push!(inner.args, maxblock3(N, D))
    push!(b4.args, inner)
    push!(b4.args, postexpr3(N, D).args...)
    outer = outerloop(N, D)
    push!(outer.args, b4)
    return quote
        $b1
        $b2
        $b3
        $outer
    end
end

D_1 = 4
D_2 = 3
D_3 = 2
N = 3
dd = typeof((D_1, Val(1), D_3))
findmax_quote(N, dd)
findmax_quote2(N, dd)
findmax_quote3(N, dd)
maxblock(N, dd)
maxblock2(N, dd)

A = reshape([1:24;], D_1, D_2, D_3);
dims = (1,)
Dᴮ = ntuple(d -> d ∈ dims ? 1 : size(A, d), N)
Dᴮ′ = ntuple(d -> d ∈ dims ? Val(1) : size(A, d), N)
T = eltype(A)
B = similar(A, Int, Dᴮ);
C = similar(A, Dᴮ);
ex = findmax_quote(N, typeof(Dᴮ′))
ex2 = findmax_quote2(N, typeof(Dᴮ′))
ex3 = findmax_quote3(N, typeof(Dᴮ′))
eval(ex2)
eval(ex3)
CartesianIndices(A)[C] == argmax(A, dims=dims)

@generated _vfindmax2!(B::AbstractArray{T, N}, C::AbstractArray{Tₒ, N},
                       A::AbstractArray{T, N}, dims::D) where {T, Tₒ, N, D} = findmax_quote2(N, D)
function vfindmax2(A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
    Dᴮ = ntuple(d -> d ∈ dims ? 1 : size(A, d), N)
    Dᴮ′ = ntuple(d -> d ∈ dims ? Val(1) : size(A, d), N)
    B = similar(A, Dᴮ)
    C = similar(A, Int, Dᴮ)
    _vfindmax2!(B, C, A, Dᴮ′)
    B, CartesianIndices(A)[C]
end

@generated _vfindmax3!(B::AbstractArray{T, N}, C::AbstractArray{Tₒ, N},
                       A::AbstractArray{T, N}, dims::D) where {T, Tₒ, N, D} = findmax_quote3(N, D)
function vfindmax3(A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
    Dᴮ = ntuple(d -> d ∈ dims ? 1 : size(A, d), N)
    Dᴮ′ = ntuple(d -> d ∈ dims ? Val(1) : size(A, d), N)
    B = similar(A, Dᴮ)
    C = similar(A, Int, Dᴮ)
    _vfindmax3!(B, C, A, Dᴮ′)
    B, CartesianIndices(A)[C]
end

dims = (4,)
@benchmark vfindmax2(A, dims)
@benchmark vfindmax3(A, dims)
@benchmark findmax(A, dims=dims)
n = 4
A = rand(50, 50, 50, 50);
A = rand(50, 50, 10000);
A = rand(10,10,10,10,10,10,10,10);

vfindmax2(A, dims) == vfindmax3(A, dims) == findmax(A, dims=dims)

ns = [1, 5, 10, 50]
bs = Matrix{NTuple{3, BenchmarkTools.Trial}}(undef, length(ns), 4);
for d = 1:4
    for (i, n) ∈ enumerate(ns)
        A = rand(n, 2n, 3n, 4n)
        bs[i, d] = ((@benchmark findmax(A, dims=($d,))),
                    (@benchmark vfindmax2(A, ($d,))),
                    (@benchmark vfindmax3(A, ($d,))))
    end
end

ts = map(bs) do b
    mean.(b)
end
tso = map(ts) do t
    getproperty.(t, :time)
end
