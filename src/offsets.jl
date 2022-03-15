#
# Date created: 2022-03-15
# Author: aradclif
#
#
############################################################################################

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

