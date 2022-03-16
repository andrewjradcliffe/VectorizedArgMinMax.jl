#
# Date created: 2022-03-15
# Author: aradclif
#
#
############################################################################################

function maxblock(N::Int, D)
    params = D.parameters
    offset = partialterm(tuple((d for d = 1:N if params[d] === Val{1})...))
    a = Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...)
    jₑ₁ = Expr(:(+=), :j, offset)
    yₑ = Expr(:(=), :y, Expr(:call, :(>), a, :m))
    mₑ = Expr(:(=), :m, Expr(:call, :ifelse, :y, a, :m))
    jₑ₂ = Expr(:(+=), :j, Expr(:call, :*, Expr(:call, :!, :y), Expr(:call, :-, offset)))
    Expr(:block, jₑ₁, yₑ, mₑ, jₑ₂)
end

function postexpr(N::Int, D)
    params = D.parameters
    b = Expr(:ref, :B, ntuple(d -> params[d] === Val{1} ? 1 : Symbol(:i_, d), N)...)
    c = Expr(:ref, :C, ntuple(d -> params[d] === Val{1} ? 1 : Symbol(:i_, d), N)...)
    Expr(:block, Expr(:(=), b, :m), Expr(:(=), c, :j))
end

function maxblock2(N::Int, D)
    params = D.parameters
    a = Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...)
    yₑ = Expr(:(=), :y, Expr(:call, :(>), a, :m))
    mₑ = Expr(:(=), :m, Expr(:call, :ifelse, :y, a, :m))
    l = dynamicterm(N)
    push!(l.args, 1, :Dstar)
    jₑ = Expr(:(=), :j, Expr(:call, :ifelse, :y, l, :j))
    Expr(:block, yₑ, mₑ, jₑ)
end

function maxblock3(N::Int, D)
    params = D.parameters
    offset = partialterm(tuple((d for d = 1:N if params[d] === Val{1})...))
    a = Expr(:ref, :A, ntuple(d -> Symbol(:i_, d), N)...)
    yₑ = Expr(:(=), :y, Expr(:call, :(>), a, :m))
    mₑ = Expr(:(=), :m, Expr(:call, :ifelse, :y, a, :m))
    jₑ = Expr(:(=), :j, Expr(:call, :ifelse, :y, offset, :j))
    Expr(:block, yₑ, mₑ, jₑ)
end

function postexpr3(N::Int, D)
    params = D.parameters
    b = Expr(:ref, :B, ntuple(d -> params[d] === Val{1} ? 1 : Symbol(:i_, d), N)...)
    c = Expr(:ref, :C, ntuple(d -> params[d] === Val{1} ? 1 : Symbol(:i_, d), N)...)
    ex = partialterm(tuple((d for d = 1:N if D.parameters[d] !== Val{1})...))
    push!(ex.args, 1, :Dstar, :j)
    Expr(:block, Expr(:(=), b, :m), Expr(:(=), c, ex))
end
