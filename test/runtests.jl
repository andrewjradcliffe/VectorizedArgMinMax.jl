using VectorizedArgMinMax
using Test

@testset "VectorizedArgMinMax.jl" begin
    @testset "vargmax.jl" begin
        n = 10
        A = rand(n, n, n);
        @test argmax(A) == vargmax(A)
        @test argmax(A, dims=1) == vargmax(A, dims=1)
        @test argmax(A, dims=2) == vargmax(A, dims=2)
        @test argmax(A, dims=3) == vargmax(A, dims=3)
    end
    @testset "vfindmax.jl" begin
        n = 10
        A = rand(n, n, n);
        @test findmax(A) == vfindmax(A)
        @test findmax(A, dims=1) == vfindmax(A, dims=1)
        @test findmax(A, dims=2) == vfindmax(A, dims=2)
        @test findmax(A, dims=3) == vfindmax(A, dims=3)
    end
end
