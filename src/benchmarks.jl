#
# Date created: 2022-03-06
# Author: aradclif
#
#
############################################################################################
using VectorizedArgMinMax, BenchmarkTools
n = 100
A = collect(reshape(1:24, 4, 3, 2))
A = rand(n, n, n);
#A = rand(n^3, n^2, n);

argmax(A) == vargmax(A)
argmax(A, dims=1) == vargmax(A, dims=1)
argmax(A, dims=2) == vargmax(A, dims=2)
argmax(A, dims=3) == vargmax(A, dims=3)
# @code_warntype vargmax(A, 2)
# @code_warntype _vargmax_dims!(out, Rpre, 1:size(A, dims), Rpost, A)
@benchmark argmax(A)
@benchmark vargmax(A)
@benchmark vtargmax(A)
@benchmark argmax(A, dims=1)
@benchmark vargmax(A, dims=1)
@benchmark vtargmax(A, dims=1)
@benchmark argmax(A, dims=2)
@benchmark vargmax(A, dims=2)
@benchmark vtargmax(A, dims=2)
@benchmark argmax(A, dims=3)
@benchmark vargmax(A, dims=3)
@benchmark vtargmax(A, dims=3)

# @benchmark _vargmax_dims!(out, Rpre, 1:size(A, dims), Rpost, A)
# @benchmark _vargmax_dims2!(out, Rpre, 1:size(A, dims), Rpost, A)
# @benchmark _tvargmax_dims!(out, Rpre, 1:size(A, dims), Rpost, A)

findmax(A) == vfindmax(A)
findmax(A, dims=1) == vfindmax(A, dims=1)
findmax(A, dims=2) == vfindmax(A, dims=2)

@benchmark findmax(A)
@benchmark vfindmax(A)
@benchmark findmax(A, dims=1)
@benchmark vfindmax(A, dims=1)
@benchmark findmax(A, dims=2)
@benchmark vfindmax(A, dims=2)
@benchmark findmax(A, dims=3)
@benchmark vfindmax(A, dims=3)
@benchmark vfindmaxt(A, dims=3)

#### Pathological examples: in essence, the Base implementations always prefer
# an optimal memory traversal; the crude vectorization struggles when the memory
# access pattern is absurd, e.g. when reducing on the third dimension in the
# example below.
A = rand(124, 124, 40000);
@benchmark argmax(A, dims=3)
@benchmark vargmax(A, dims=3)
@benchmark reduce(+, A, dims=3)
@benchmark vreduce(+, A, dims=3)
# And then things become rather strange... reduction on 3rd dimension is
# markedly slower, and allocates excessively. But reduction on 4th is normal...?
n = 10
A = rand(n, n, n, n, n, n);
@benchmark argmax(A, dims=3)
@benchmark vargmax(A, dims=3)
@benchmark argmax(A, dims=4)
@benchmark vargmax(A, dims=4)
# 5th, 6th behave like 3rd
@benchmark argmax(A, dims=5)
@benchmark vargmax(A, dims=5)
@benchmark argmax(A, dims=6)
@benchmark vargmax(A, dims=6)
