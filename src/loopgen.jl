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
