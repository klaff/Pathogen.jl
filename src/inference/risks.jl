"""
Prior distributions vectors for the `RiskParameters`
"""
type RiskParameterPriors
  sparks::Vector{UnivariateDistribution}
  susceptibility::Vector{UnivariateDistribution}
  transmissibility::Vector{UnivariateDistribution}
  infectivity::Vector{UnivariateDistribution}
  latency::Vector{UnivariateDistribution}
  removal::Vector{UnivariateDistribution}
end


"""
rand(riskpriors::RiskParameterPriors)

Randomly generate a set of `RiskParameters` from their prior distributions
"""
function rand(riskpriors::RiskParameterPriors)
  sparks = Float64[]
  susceptibility = Float64[]
  transmissibility = Float64[]
  infectivity = Float64[]
  latency = Float64[]
  removal = Float64[]

  for i = 1:length(riskpriors.sparks)
    push!(sparks, rand(riskpriors.sparks[i]))
  end

  for i = 1:length(riskpriors.susceptibility)
    push!(susceptibility, rand(riskpriors.susceptibility[i]))
  end

  for i = 1:length(riskpriors.transmissibility)
    push!(transmissibility, rand(riskpriors.transmissibility[i]))
  end

  for i = 1:length(riskpriors.infectivity)
    push!(infectivity, rand(riskpriors.infectivity[i]))
  end

  for i = 1:length(riskpriors.latency)
    push!(latency, rand(riskpriors.latency[i]))
  end

  for i = 1:length(riskpriors.removal)
    push!(removal, rand(riskpriors.removal[i]))
  end

  return RiskParameters(sparks,
                        susceptibility,
                        transmissibility,
                        infectivity,
                        latency,
                        removal)
end


"""
logprior(riskpriors::RiskParameterPriors,
         riskparams::RiskParameters)

Calculate the log prior of a set of `RiskParameters`
"""
function logprior(riskpriors::RiskParameterPriors,
                  riskparams::RiskParameters)
  lp = 0.
  for i = 1:length(riskparams.sparks)
    lp += loglikelihood(riskpriors.sparks[i], [riskparams.sparks[i]])
  end
  for i = 1:length(riskparams.susceptibility)
    lp += loglikelihood(riskpriors.susceptibility[i], [riskparams.susceptibility[i]])
  end
  for i = 1:length(riskparams.transmissibility)
    lp += loglikelihood(riskpriors.transmissibility[i], [riskparams.transmissibility[i]])
  end
  for i = 1:length(riskparams.infectivity)
    lp += loglikelihood(riskpriors.infectivity[i], [riskparams.infectivity[i]])
  end
  for i = 1:length(riskparams.latency)
    lp += loglikelihood(riskpriors.latency[i], [riskparams.latency[i]])
  end
  for i = 1:length(riskparams.removal)
    lp += loglikelihood(riskpriors.removal[i], [riskparams.removal[i]])
  end
  return lp
end


"""
propose(currentstate::RiskParameters,
        transition_kernel_variance::Array{Float64, 2})

Generate a `RiskParameters` proposal using the multivariate normal distribution
as the transition kernel, with a previous set of `RiskParameters` as the mean
vector and a transition kernel variance as the variance-covariance matrix
"""
function propose(currentstate::RiskParameters,
                 transition_kernel_variance::Array{Float64, 2})
  newstate = rand(MvNormal(Vector(currentstate), transition_kernel_variance))
  inds = cumsum([length(currentstate.sparks);
                 length(currentstate.susceptibility);
                 length(currentstate.transmissibility);
                 length(currentstate.infectivity);
                 length(currentstate.latency);
                 length(currentstate.removal)])
  return RiskParameters(newstate[1:inds[1]],
                        newstate[inds[1]+1:inds[2]],
                        newstate[inds[2]+1:inds[3]],
                        newstate[inds[3]+1:inds[4]],
                        newstate[inds[4]+1:inds[5]],
                        newstate[inds[5]+1:inds[6]])
end
