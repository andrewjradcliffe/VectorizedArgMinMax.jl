#
# Date created: 2022-03-07
# Author: aradclif
#
#
############################################################################################
# Experiments in efficiency improvements
using Base.Cartesian

A = rand(4,3,5);
Da = axes(A)
Db = Da
dims = (1,3)
Db = Base.setindex(Db, 1, dims[1])
Db = Base.setindex(Db, 1, dims[2])
B = similar(A, Db);
fill!(B, 0.0);
sum(B)
@macroexpand @nloops 3 i A begin
    (@nref 3 B d -> length(Db[d]) == 1 ? 1 : i_d) =
        +((@nref 3 B d -> length(Db[d]) == 1 ? 1 : i_d), (@nref 3 A i))
end
@macroexpand @nloops 3 i A begin
    (@nref 3 B d -> length(axes(B, d)) == 1 ? 1 : i_d) =
        +((@nref 3 B d -> length(axes(B, d)) == 1 ? 1 : i_d), (@nref 3 A i))
end
@macroexpand @nref 3 B d -> length(axes(B, d)) == 1 ? 1 : i_d
@macroexpand @nexprs 3 d -> (j_d = length(axes(B, d)) == 1 ? 1 : i_d)
@macroexpand @nref 3 A i
Expr(:ref, :A, :(1), :i_2, :(3))
(LoopVectorization.StaticInt(1), LoopVectorization.StaticInt(3), LoopVectorization.StaticInt(1))

@generated function prepare(A, dims::NTuple{N, Int}) where {N}
    quote
        Da = axes(A)
        Db = Da
        @nexprs $N d -> (Db = Base.setindex(Db, Base.OneTo(1), dims[d]))
        Db
    end
end

@generated function vreduce!(f::Function, B::AbstractArray{T, N}, A::AbstractArray{T, N}) where {T, N}
    quote
        @nloops $N i A begin
            (@nref $N B d -> length(axes(B, d)) == 1 ? 1 : i_d) =
                f((@nref $N B d -> length(axes(B, d)) == 1 ? 1 : i_d), (@nref $N A i))
        end
        B
    end
end

# @generated function _vreduce!(f::F, B::AbstractArray{T, N}, A::AbstractArray{T, N}) where {F, T, N}
#     quote
#         ee = @macroexpand @nloops $N i A begin
#             (@nref $N B d -> length(axes(B, d)) == 1 ? 1 : i_d) =
#                 $(f.instance)((@nref $N B d -> length(axes(B, d)) == 1 ? 1 : i_d), (@nref $N A i))
#         end
#         ea = ee.args[2]
#         return quote
#             $ea
#             return B
#         end
#     end
#     # ee = quote
#     #     @macroexpand @nloops 3 i A begin
#     #     (@nref 3 B d -> length(axes(B, d)) == 1 ? 1 : i_d) =
#     #         +((@nref 3 B d -> length(axes(B, d)) == 1 ? 1 : i_d), (@nref 3 A i))
#     #     end
#     # end
#     # ee.args[2]
# end

function preparedims(B::AbstractArray{T, N}, A::AbstractArray{T, N}) where {T, N}
    Db = axes(B)
    Dᵥ = ntuple(d -> length(Db[d]) == 1 ? StaticInt(1) : Symbol(:i_, d), N)
end
# preparedims(B, A)

# function vvreduce!(f::F, B::AbstractArray{T, N}, A::AbstractArray{T, N}) where {F, T, N}
#     dims = preparedims(B, A)
#     _vvreduce!(f, B, A, dims)
# end
# @generated function _vvreduce!(f::F, B::AbstractArray{T, N}, A::AbstractArray{T, N}, dims::D) where {F, T, N, D}
#     e = Expr(:ref, :B, ntuple(d -> D.parameters[d] !== StaticInt{1} ? Symbol(:i_, d) : :(1), N)...)
#     quote
#         ex = @macroexpand @nloops $N i A begin
#             $e = $(F.instance)($e, (@nref $N A i))
#         end
#         loops = ex.args[2]
#         return quote
#             # @turbo $loops
#             $loops
#             return B
#         end
#         # @turbo $loops
#         # return B
#     end
# end
# _vvreduce!(+, B, A, preparedims(B, A))
function branches_quote(F, N::Int, D)
    e = Expr(:ref, :B, ntuple(d -> D.parameters[d] !== StaticInt{1} ? Symbol(:i_, d) : :(1), N)...)
    ex = :(@nloops $N i A begin
               $e = $(F.instance)($e, (@nref $N A i))
           end)
    exm = macroexpand(Main, ex)
    loops = exm.args[2]
    return quote
        @tturbo $loops
        return B
    end
end
@generated function vvvreduce!(f::F, B::AbstractArray{T, N}, A::AbstractArray{T, N}, dims::D) where {F, T, N, D}
    branches_quote(F, N, D)
end
function vvvreduce(f, A::AbstractArray{T}; dims::NTuple{N, Int}) where {N} where {T}
    Db = prepare(A, dims)
    # B = similar(A, Db)
    # fill!(B, 0.0)
    B = zeros(T, Db)
    vvvreduce!(f, B, A, preparedims(B, A))
end

@generated function vvvreduce(f::F, A::AbstractArray{T, N}) where {F, T, N}
    quote
        s = zero($T)
        @tturbo for i ∈ eachindex(A)
            s = $(F.instance)(s, A[i])
        end
        return s
    end
end
@timev vvvreduce(+, A)
A = rand(4,3,5);

# branches_quote(typeof(+), 3, typeof(preparedims(B, A)))
# dd = preparedims(B, A)
# @timev vvvreduce!(+, B, A, dd)

@benchmark vvvreduce(+, A, dims=dims)
@benchmark sum(A, dims=dims)
@timev vvvreduce(+, A, dims=(1,))
# This causes an error -- however, one can actually perform this faster by just
# reducing using a scalar, then doing cat(s, dims=N).
B = zeros(Float64, prepare(A, (1,2,3)))
branches_quote(typeof(+), 3, typeof(preparedims(B, A)))
eval(ans)
@timev sum(A, dims=(1,))




@generated function indexexpr(D::NTuple{N, T}) where {N, T}
    ex = quote
        @ntuple $N d -> length(D[d]) == 1 ? Symbol(1) : Symbol("i_$(d)")
    end
    # return :($ex)
    ex
end
Isym = indexexpr(Db2)
@nref 3 B j -> ($(Isym[j]))

Db2 = prepare(A, dims)
B2 = similar(A, Db2);
fill!(B2, 0.0);
vreduce!(+, B2, A);
_vreduce!(+, B2, A)
vreduce6!(+, B2, A)
vreduce2!(+, B2, A);

s = 0.0
ex = quote @nloops 3 i A begin
    s += @nref 3 A i
end
end
ex2 = :(@nloops 3 i A begin
    s += @nref 3 A i
end)


@macroexpand @turbo for i ∈ eachindex(A)
    s = +(s, A[i])
end

LoopVectorization.@_turbo(ex)

ex = quote
    for i ∈ eachindex(A)
        s += A[i]
    end
end
ex2 = :(for i ∈ eachindex(A)
            s += A[i]
        end)

N = 3
static_dims = [1,2,3]
quote
    @turbo $loops
end
quote
    @turbo $loop3
end

loop3 = @macroexpand @nloops 3 i A begin
    (@nref 3 B d -> length(axes(B, d)) == 1 ? 1 : i_d) =
        +((@nref 3 B d -> length(axes(B, d)) == 1 ? 1 : i_d), (@nref 3 A i))
end
ee = loop3.args[2]
quote
    @turbo $ee
end

function simdsum(A::Array{T, 3}) where {T}
    s = zero(T)
    @turbo for k ∈ axes(A, 3)
        nothing
        for j ∈ axes(A, 2)
            for i ∈ axes(A, 1)
                s = (+)(s, A[i, j, k])
            end
        end
    end
    s
end

simdsum(A)
