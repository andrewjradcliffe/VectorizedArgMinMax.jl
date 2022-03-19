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
        @turbo $outer
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
        @turbo $outer
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
B = similar(A, Dᴮ);
C = similar(A, Int, Dᴮ);
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
vargmax3(A, dims) == argmax(A, dims=dims)
vfindmax3(A, dims)[2] == vargmax3(A, dims)

@benchmark vfindmax2(A, dims)
@benchmark vfindmax3(A, dims)

ns = [1, 5, 10, 50]
bs = Matrix{NTuple{3, BenchmarkTools.Trial}}(undef, length(ns), 4);
for d = 2:4
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


outer = :(for i_3 = axes(A, 3), i_1 = axes(A, 1)
              m = typemin(T)
              j = 0
              for i_2 = axes(A, 2)
                  y = A[i_1, i_2, i_3] > m
                  m = ifelse(y, A[i_1, i_2, i_3], m)
                  j = ifelse(y, +(D_1 * i_2), j)
              end
              B[i_1, 1, i_3] = m
              C[i_1, 1, i_3] = i_1 + D_12 * i_3 + 1 + Dstar + j
          end);
ls = LoopVectorization.LoopSet(outer);
ops = LoopVectorization.operations(ls)
LoopVectorization.loopdependencies.(ops)
@macroexpand @turbo for i_3 = axes(A, 3), i_1 = axes(A, 1)
    m = typemin(T)
    j = 0
    for i_2 = axes(A, 2)
        y = A[i_1, i_2, i_3] > m
        m = ifelse(y, A[i_1, i_2, i_3], m)
        j = ifelse(y, +(D_1 * i_2), j)
    end
    B[i_1, 1, i_3] = m
    C[i_1, 1, i_3] = i_1 + D_12 * i_3 + 1 + Dstar + j
end

outer = :(for i_3 = axes(A, 3), i_2 = axes(A, 2)
              m = typemin(T)
              j = 0
              for i_1 = axes(A, 1)
                  y = A[i_1, i_2, i_3] > m
                  m = ifelse(y, A[i_1, i_2, i_3], m)
                  j = ifelse(y, i_1, j)
              end
              B[1, i_2, i_3] = m
              C[1, i_2, i_3] = j#D_1 * i_2 + D_12 * i_3 + 1 + Dstar + j
          end)
ls = LoopVectorization.LoopSet(outer);
ops = LoopVectorization.operations(ls)
LoopVectorization.loopdependencies.(ops)
ls = LoopVectorization.@turbo_debug for i_3 = axes(A, 3), i_2 = axes(A, 2)
    m = typemin(T)
    j = 0
    for i_1 = axes(A, 1)
        # j = C[1, i_2, i_3]
        # m = B[1, i_2, i_3]
        y = A[i_1, i_2, i_3] > m
        m = ifelse(y, A[i_1, i_2, i_3], m)
        j = ifelse(y, i_1, j)
        # B[1, i_2, i_3] = ifelse(y, A[i_1, i_2, i_3], m)
        # C[1, i_2, i_3] = ifelse(y, i_1, j)
    end
    B[1, i_2, i_3] = m
    C[1, i_2, i_3] = j#D_1 * i_2 + D_12 * i_3 + 1 + Dstar + j
end

############################################################################################
#### 2022-03-18: Experiments applying methodology to reduce, mapreduce
# Alas, performance is worse as the loop ordering is kind of absurd...
function reduce_quote2(OP, I, N::Int, D)
    init = I.instance
    pre = Expr(:block, Expr(:(=), :s, Expr(:call, Symbol(init), :T)))
    inner = innerloop(N, D)
    rₑ = reduceexpr(OP, N)
    push!(inner.args, Expr(:block, rₑ))
    push!(pre.args, inner)
    push!(pre.args, postexpr(:B, :s, N, D))
    outer = outerloop(N, D)
    push!(outer.args, pre)
    # outer
    return quote
        @turbo $outer
    end
end

function mapreduce_quote2(F, OP, I, N::Int, D)
    init = I.instance
    pre = Expr(:block, Expr(:(=), :s, Expr(:call, Symbol(init), :T)))
    inner = innerloop(N, D)
    rₑ = mapreduceexpr(F, OP, N)
    push!(inner.args, rₑ)
    push!(pre.args, inner)
    push!(pre.args, postexpr(:B, :s, N, D))
    outer = outerloop(N, D)
    push!(outer.args, pre)
    outer
end

function reduce_quote2(OP, N::Int, D)
    pre = Expr(:block, Expr(:(=), :s, reduceref(:B, N, D)))
    inner = innerloop(N, D)
    rₑ = reduceexpr(OP, N)
    push!(inner.args, rₑ)
    push!(pre.args, inner)
    push!(pre.args, postexpr(:B, :s, N, D))
    outer = outerloop(N, D)
    push!(outer.args, pre)
    outer
    return quote
        @turbo $outer
    end
end

function _lvreduce2(f, A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
    if ntuple(identity, Val(N)) ⊆ dims
        B = hvncat(ntuple(_ -> 1, Val(N)), true, lvreduce21(f, A))
    else
        Dᴮ = ntuple(d -> d ∈ dims ? 1 : size(A, d), Val(N))
        Dᴮ′ = ntuple(d -> d ∈ dims ? Val(1) : size(A, d), Val(N))
        B = zeros(Base.promote_op(f, T), Dᴮ)
        _lvreduce2!(f, zero, B, A, Dᴮ′)
        # _lvreduce2!(f, B, A, Dᴮ′)
    end
    return B
end

@generated function _lvreduce2!(f::F, init::I, B::AbstractArray{Tₒ, N}, A::AbstractArray{T, N}, dims::D) where {F, I, Tₒ, T, N, D}
    reduce_quote2(F, I, N, D)
end
@generated function _lvreduce2!(f::F, B::AbstractArray{Tₒ, N}, A::AbstractArray{T, N}, dims::D) where {F, Tₒ, T, N, D}
    reduce_quote2(F, I, N, D)
end

@benchmark _lvreduce2(+, A, (1,2))
@benchmark lvsum(A, dims=(1,2,))
@benchmark vsum(A, dims=(1,2))
_lvreduce2(+, A, (1,2)) == lvsum(A, dims=(1,2)) == vsum(A, dims=(1,2))

############################################################################################
#### Interesting experiment using indices
ex = VectorizedStatistics.staticdim_mean_quote([1,3], 4)
Meta.show_sexpr(ex)
D = typeof((StaticInt(1), 10, StaticInt(1), 10))
N = 4
function reduce_quote3(OP, I, N::Int, D)
    _params = D.parameters
    a = Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...)
    bᵥ = Expr(:call, :view, :B)
    bᵥ′ = Expr(:ref, :Bᵥ)
    rinds = Int[]
    nrinds = Int[]
    for d = 1:N
        if _params[d] === Static.One
            push!(bᵥ.args, Expr(:call, :firstindex, :B, d))
            push!(rinds, d)
        else
            push!(bᵥ.args, Expr(:call, :Colon))
            push!(nrinds, d)
            push!(bᵥ′.args, Symbol(:i_, d))
        end
    end
    bᵥ = Expr(:(=), :Bᵥ, bᵥ)
    sort!(rinds, rev=true)
    sort!(nrinds, rev=true)
    block = Expr(:block)
    loops = Expr(:for, Expr(:(=), Symbol(:i_, nrinds[1]),
                            Expr(:call, :indices, Expr(:tuple, :A, :B), nrinds[1])), block)
    for i = 2:length(nrinds)
        newblock = Expr(:block)
        push!(block.args,
              Expr(:for, Expr(:(=), Symbol(:i_, nrinds[i]),
                              Expr(:call, :indices, Expr(:tuple, :A, :B), nrinds[i])), newblock))
        block = newblock
    end
    rblock = block
    # Push to before reduction loop
    pre = Expr(:(=), :ξ, Expr(:call, Symbol(I.instance), Expr(:call, :eltype, :Bᵥ)))
    push!(rblock.args, pre)
    # Reduction loop
    for i = 1:length(rinds)
        newblock = Expr(:block)
        push!(block.args,
              Expr(:for, Expr(:(=), Symbol(:i_, rinds[i]),
                              Expr(:call, :axes, :A, rinds[i])), newblock))
        block = newblock
    end
    # Push to inside innermost loop
    reduction = Expr(:(=), :ξ, Expr(:call, Symbol(OP.instance), :ξ, a))
    push!(block.args, reduction)
    # Push to after reduction loop
    post = Expr(:(=), bᵥ′, :ξ)
    push!(rblock.args, post)
    return quote
        $bᵥ
        @turbo $loops
        return B
    end
end

reduce_quote3(typeof(max), typeof(typemin), N, D)

function _lvreduce3(op, init, A::AbstractArray{T, N}, dims::NTuple{M, Int}) where {T, N, M}
    if ntuple(identity, Val(N)) ⊆ dims
        B = hvncat(ntuple(_ -> 1, Val(N)), true, lvreduce1(op, A))
    else
        Dᴮ′ = ntuple(d -> d ∈ dims ? StaticInt(1) : size(A, d), Val(N))
        B = similar(A, Base.promote_op(op, T), Dᴮ′)
        _lvreduce3!(op, init, B, A, Dᴮ′)
    end
    return B
end

@generated function _lvreduce3!(op::OP, init::I, B::AbstractArray{Tₒ, N}, A::AbstractArray{T, N}, dims::D) where {OP, I, Tₒ, T, N, D}
    reduce_quote3(OP, I, N, D)
end

lvsum3(A, dims) = _lvreduce3(+, zero, A, dims)
@benchmark _lvreduce3(+, zero, A, (1,3))
@benchmark lvsum3(A, (1,3))
@benchmark lvsum(A, dims=(1,3), multithreaded=false)
@benchmark vsum(A, dims=(1,3), multithreaded=false)
_lvreduce3(+, zero, A, (1,3)) == lvsum(A, dims=(1,3))
