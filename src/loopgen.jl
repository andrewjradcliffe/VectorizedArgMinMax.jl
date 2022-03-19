#
# Date created: 2022-03-15
# Author: aradclif
#
#
############################################################################################

function outerloop(N::Int, D)
    params = D.parameters
    block = Expr(:block)
    for d = N:-1:1
        if params[d] !== Val{1}
            push!(block.args, Expr(:(=), Symbol(:i_, d), Expr(:call, :axes, :A, d)))
        end
    end
    Expr(:for, block)
end

function innerloop(N::Int, D)
    params = D.parameters
    block = Expr(:block)
    for d = N:-1:1
        if params[d] === Val{1}
            push!(block.args, Expr(:(=), Symbol(:i_, d), Expr(:call, :axes, :A, d)))
        end
    end
    Expr(:for, block)
end

function loop(J::NTuple{N, Int}) where {N}
    Expr(:for, Expr(:block, ntuple(d -> Expr(:(=), Symbol(:i_, J[d]), Expr(:call, :axes, :A, J[d])), N)...))
end

################
function nonreduceloop(d::Int)
    Expr(:for, Expr(:(=), Symbol(:i_, d), Expr(:call, :indices, Expr(:tuple, :A, :B), d)))
end
l4 = nonreduceloop(4)
l2 = nonreduceloop(2)

function reduceloop(d::Int)
    Expr(:for, Expr(:(=), Symbol(:i_, d), Expr(:call, :axes, :A, d)))
end
l3 = reduceloop(3)
l1 = reduceloop(1)

function nonreducekernel(dims::Vector{Int})
    ds = sort(dims, rev=true)
    loops = nonreduceloop_first(first(ds))
    lₒ = loops
    for i = 2:length(ds)
        lᵢ = nonreduceloop(ds[i])
        push!(lₒ.args, lᵢ)
        lₒ = lᵢ
    end
    loops
end
function reducekernel(dims::Vector{Int})
    ds = sort(dims, rev=true)
    loops = reduceloop(first(ds))
    lₒ = loops
    for i = 2:length(ds)
        lᵢ = reduceloop(ds[i])
        push!(lₒ.args, lᵢ)
        lₒ = lᵢ
    end
    loops
end

lastfor(e::Expr) = length(e.args) ≥ 2 && e.args[2].head === :for ? lastfor(e.args[2]) : e
lastforb(e::Expr) = length(e.args) ≥ 2 && ls.args[1].head === :for ? lastforb(e.args[1]) : e
function lastfor(e::Expr)
    if length(e.args) ≥ 2 && e.args[2].head === :for
        lastfor(e.args[2])
    else# e.head === :block
        e.head === :block && e.args[1].head === :for ? lastfor(e.args[1]) : e
    end
end


e = reducekernel([1, 3])
el = lastfor(e)

e2 = nonreducekernel([2, 4])
el2 = lastfor(e2)
push!(el2.args, e)
push!(lastfor(el2).args, Expr(:call, :+, a, 1))

prog = "for i_4 = indices((A, B), 4)
          for i_2 = indices((A, B), 2)
              for i_3 = axes(A, 3)
                  for i_1 = axes(A, 1)
                      A[i_1, i_2, i_3, i_4] + 1
                  end
              end
          end
      end"
ex2 = Meta.parse(prog)
