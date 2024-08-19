using SimTreeUtils
using Test
using BSON

include("testutils.jl")
@testset "SimTreeUtils.jl" begin
    # Write your tests here.
    @test typeof(SimTreeUtils.stsimulate(testmainfunction))== Dict{String,Any}
    @test typeof(BSON.load("results/study.bson"))== Dict{String,Any}
end
