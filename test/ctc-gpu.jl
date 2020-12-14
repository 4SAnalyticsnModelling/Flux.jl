using Test
using Flux
using Flux.Losses: ctc_loss
using Zygote: gradient
using LinearAlgebra
using CUDA
using Statistics

# Custom function to check numerical gradient of ctc loss,
# based on `ngradient` in `Tracker.jl`
# 
# Needs to check loss as defined at a particular time step
# related to the change in x because slight deviations in
# input propagate through further time steps, intrinsically
# causing the gradients to change and thus not be comparable
# between the numeric and analytical definitions
function ctc_ngradient(xs...)
  f = Flux.Losses.ctc_
  grads = zero.(xs)
  for (x, Δ) in zip(xs, grads), i in 1:length(x)
    δ = sqrt(eps())
    t = div(i-1, size(x, 1)) + 1
    tmp = x[i]
    x[i] = tmp - δ/2
    y1 = f(xs...)[1][t]
    x[i] = tmp + δ/2
    y2 = f(xs...)[1][t]
    x[i] = tmp
    Δ[i] = (y2-y1)/δ
  end
  return grads
end

@testset "ctc-gpu" begin
  
  x = rand(10, 50)
  y = reduce(hcat, repeat([Array{Float64}(I, 10, 10)[min(i, 9),:] for i in 1:10], inner=5))

  x_cu = CuArray(x)
  y_cu = CuArray(y)
  
  g1 = gradient(ctc_loss, x_cu, y_cu)[1]
  g1 = g1 |> collect
  
  g2 = ctc_ngradient(x, y)[1]
  
  @test all(isapprox.(g1, g2, rtol=1e-5, atol=1e-5))
  
  # test that GPU loss matches CPU implementation
  
  l1 = ctc_loss(x_cu, y_cu)
  l2 = ctc_loss(x, y)
  
  @test all(isapprox.(l1, l2, rtol=1e-5, atol=1e-5))
  
  # tests using hand-calculated values
  
  x_cu = [1. 2. 3.; 2. 1. 1.; 3. 3. 2.] |> CuArray
  y_cu = [1 1 0; 0 0 1; 0 0 0] |> CuArray
  
  @test mean(ctc_loss(x_cu, y_cu)) ≈ 3.6990738275138035
  
  g = [-0.317671 -0.427729 0.665241; 0.244728 -0.0196172 -0.829811; 0.0729422 0.447346 0.16457]
  ghat = gradient(ctc_loss, x_cu, y_cu)[1] |> collect
  
  @test all(isapprox.(g, ghat, rtol=1e-5, atol=1e-5))

  x_cu = [-3. 12. 8. 15.; 4. 20. -2. 20.; 8. -33. 6. 5.] |> CuArray
  y_cu = [1 1 0 0; 0 0 1 1; 0 0 0 0] |> CuArray
  @test ctc_loss(x_cu, y_cu) ≈ 8.02519869363453

  g = [-2.29294774655333e-06 -0.999662657278862 1.75500863563993e-06 0.00669284889063; 0.017985914969696 0.999662657278861 -1.9907078755387e-06 -0.006693150917307; -0.01798362202195 -2.52019580677916e-20 2.35699239251042e-07 3.02026677058789e-07]

  ghat = gradient(ctc_loss, x_cu, y_cu)[1] |> collect
  @test all(isapprox.(g, ghat, rtol=1e-5, atol=1e-5))
  
end
