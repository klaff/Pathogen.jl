"""
infer.jl - pathogen evolution and transmission dynamic inference tools
Justin Angevaare
June 2015
"""

function SEIR_surveilance(ids::Vector{Int64}, population::Population, ν::Float64)
  """
  Gather surveillance data on specific individuals in a population, with an exponentially distributed detection lag with rate ν
  """
  @assert(all(2 .<= ids .<= length(population.events)), "Invalid ID provided")
  @assert(0. < ν, "ν, the detection rate parameter must be greater than 0")
  @warning("Movement and covariate changes currently not supported, only initial conditions considered")
  eventtimes = DataFrame(id = ids, exposed = NaN, infectious_actual = NaN, infectious_observed = NaN, removed_actual = NaN, removed_observed = NaN)
  sampledetails = DataFrame(id = ids, covariates = NaN, seq = NaN)

  for i = 1:length(ids)
    # Initial conditions
    sampledetails[:covariates][ids[i]] = population.history[ids[i]][1][1]

    # Exposure time (unobservable)
    if length(population.events[ids[i]][1]) > 0
      eventtimes[:exposed][ids[i]] = population.events[ids[i]][1][1]
    end

    # Infectious time (observed with latency)
    if length(population.events[ids[i]][3]) > 0
      eventtimes[:infectious_actual][ids[i]] = population.events[ids[i]][3][1]
      eventtimes[:infectious_observed][ids[i]] = eventtimes[:infectious_actual][ids[i]] + rand(Exponential(1/ν))
      sampledetails[:seq][ids[i]] = population.history[ids[i]][2][find(eventtimes[:infectious_observed][ids[i]] .<= population.events[ids[i]][6])[end]]
    end

    # Removal time (observed with latency)
    if length(population.events[ids[i]][4]) > 0
      eventtimes[:removed_actual][ids[i]] = population.events[ids[i]][4][1]
      eventtimes[:removed_observed][ids[i]] = eventtimes[:removed_actual][ids[i]] + rand(Exponential(1/ν))
    end
  end
  return eventtimes, sampledetails
end

function create_tree(sequences::Vector{Nucleotide2bitSeq}, times::Vector{Float64})
  """
  Generate a phylogenetic tree based on sample times and sequences
  """
  @assert(length(sequences)==length(times), "There must be one sample time for each sequence")
  @assert(length(sequences)>2, "There must be at least 3 samples")
  # root
  vertices = TreeVertex()
  # nodes
  for i = 1:(length(sequences) - 2)
    push!(vertices, TreeVertex(minimum(times)))
  end
  # leaves
  for i = 1:length(sequences)
    push!(vertices, TreeVertex(sequences[i], times[i]))
  end
  # Create edges
  edges = Vector{TreeEdge}
  for i = 1:length(vertices)
    for j = 1:length(vertices)
      if vertices[i].out & vertices[j].in
        push!(edges, TreeEdge(i, j))
      end
    end
  end
  return Tree(vertices, edges)
end

function seqdistance(ancestor::Nucleotide2bitSeq, descendent::Nucleotide2bitSeq, substitution_matrix::Array)
  """
  Compute the genetic distance between two nucleotide sequences based on a `substitution_matrix`
  """
  @assert(length(ancestor) == length(descendent), "Sequences must be equal in length")
  rate_vector = Float64[]
  for i = 1:length(ancestor)
    if ancestor[i] != descendent[i]
     push!(rate_vector, substitution_matrix[convert(Int64, ancestor[i]), convert(Int64, descendent[i])])
    end
  end
  rate_vector .^= -1
  return sum(rate_vector)
end

function branchloglikelihood(seq1::Nucleotide2bitSeq, seq2::Nucleotide2bitSeq, branchdistance::Float64, substitution_matrix::Array)
  """
  Log likelihood for any two aligned sequences, a specified distance apart on a phylogenetic tree
  """
  @assert(length(seq1) == length(seq2), "Sequences not aligned")
  ll = 0
  for i = 1:length(seq1)
    base1 = convert(Int64, seq1[i])
    for base2 = 1:4
      if base2 == convert(Int64, seq2[i])
        if base1 != base2
          ll += log(1 - exp(substitution_matrix[base1, base2] .* branchdistance))
        end
      else
        ll += substitution_matrix[base1, base2] .* branchdistance
      end
    end
  end
  return ll
end

function treedistance(leaf1::Int64, leaf2::Int64, tree::Tree)
  """
  Find the minimumum branch distance between two leaves
  """
  @assert(all(1 .<= [leaf1, leaf2] .<= length(tree.distances)), "Invalid leaves specified")
  depthlimit = minimum([length(tree.positions[leaf1]), length(tree.positions[leaf2])])
  sharednode = findfirst(tree.positions[leaf1][1:depthlimit] .!= tree.positions[leaf2][1:depthlimit])
  return sum([tree.distances[leaf1][sharednode:end], tree.distances[leaf2][sharednode:end]])
end

function create_logprior1(α_prior::UnivariateDistribution, β_prior::UnivariateDistribution, ρ_prior::UnivariateDistribution, γ_prior::UnivariateDistribution, η_prior::UnivariateDistribution, ν_prior::UnivariateDistribution)
  """
  Create a log prior function using specified prior univariate distributions
  α, β: powerlaw exposure kernel parameters
  η: external pressure rate
  ρ: infectivity rate (1/mean latent period)
  γ: recovery rate (1/mean infectious period)
  ν: detection rate (1/mean detection lag)
  """
  return function(α::Float64, β::Float64, ρ::Float64, γ::Float64, η::Float64, ν::Float64)
    """
    α, β: powerlaw exposure kernel parameters
    η: external pressure rate
    ρ: infectivity rate (1/mean latent period)
    γ: recovery rate (1/mean infectious period)
    ν: detection rate (1/mean detection lag)
    """
    return logpdf(α_prior, α) + logpdf(β_prior, β) + logpdf(ρ_prior, ρ) + logpdf(γ_prior, γ) + logpdf(η_prior, η) + logpdf(ν_prior, ν)
  end
end

function augorg1(ρ::Float64, ν::Float64, obs::DataFrame)
  """
  Augments surveilance data, organizes observations
  """
  augorg = [obs, DataFrame(detectionlag = rand(Exponential(1/ν), size(obs, 1)))]
  augorg[:truetime] = augorg[:time] - augorg[:detectionlag]

  return augorg
  end

function loglikelihood1(α::Float64, β::Float64, ρ::Float64, γ::Float64, η::Float64, ν::Float64, augorg::DataFrame)
  """
  α, β: powerlaw exposure kernel parameters
  η: external pressure rate
  ρ: infectivity rate (1/mean latent period)
  γ: recovery rate (1/mean infectious period)
  ν: detection rate (1/mean detection lag)
  """
  loglikelihood(Exponential(1/ρ), aug.latentperiod[end]) + loglikelihood(Exponential(1/γ), aug.infectiousperiod[end]) + loglikelihood(Exponential(1/ν), aug.detectionlag[end])
  return

end

