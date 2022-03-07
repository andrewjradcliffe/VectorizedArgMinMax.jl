#
# Date created: 2022-03-06
# Author: aradclif
#
#
############################################################################################
n = 100
A = collect(reshape(1:24, 4, 3, 2))
A = rand(n, n, n);
A = rand(n, n, n, n, n, n);
n = 10
A = rand(n^3, n^2, n);

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
@benchmark argmax(A, dims=2)
@benchmark vargmax(A, dims=2)
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
