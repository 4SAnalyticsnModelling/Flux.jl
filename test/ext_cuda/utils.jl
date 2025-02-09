

@testset "Rrule" begin
  @testset "issue 2033" begin
    if CUDA.functional()
      struct Wrapped{T}
          x::T
      end
      y, _ = Flux.pullback(Wrapped, cu(randn(3,3)))
      @test y isa Wrapped{<:CuArray}
    end
  end
end
