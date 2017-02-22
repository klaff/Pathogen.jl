"""
rand(network_rates::NetworkRates)

Probablistically generate a network object based on exposure network rates
"""
function rand(network_rates::NetworkRates)
  external_rates = network_rates.external
  internal_rates = network_rates.internal
  external_network = fill(false, length(external_rates))
  internal_network = fill(false, size(internal_rates))
  if !(length(external_rates) == size(internal_rates, 1) == size(internal_rates, 2))
    throw(BoundsError)
  end
  for i = 1:length(external_rates)
    external_total = external_rates[i]
    internal_total = sum(internal_rates[:, i])
    if sum(external_total + internal_total) > 0.
      if rand() < external_total/(external_total + internal_total)
        external_network[i] = true
      else
        source = findfirst(rand(Multinomial(1, internal_rates[:, i]/internal_total)))
        internal_network[source, i] = true
      end
    end
  end
  return Network(external_network, internal_network)
end


"""
propose(individuals::Vector{Int64},
        network::Network,
        network_rates::NetworkRates)

Propose an exposure network based on a previous exposure network and exposure
network rates
"""
function propose(individuals::Vector{Int64},
                 network::Network,
                 network_rates::NetworkRates)
  external = copy(network.external)
  internal = copy(network.internal)
  external_rates = network_rates.external
  internal_rates = network_rates.internal
  for i in individuals
    external[i] = false
    internal[:, i] = false
    external_total = external_rates[i]
    internal_total = sum(internal_rates[:, i])
    if sum(external_total + internal_total) > 0.
      if rand() < external_total/(external_total + internal_total)
        external[i] = true
      else
        source = findfirst(rand(Multinomial(1, internal_rates[:, i]/internal_total)))
        internal[source, i] = true
      end
    end
  end
  return Network(external, internal)
end


"""
propose(i::Int64,
        network::Network,
        network_rates::NetworkRates)

Propose an exposure network based on a previous exposure network and exposure
network rates
"""
function propose(i::Int64,
                 network::Network,
                 network_rates::NetworkRates)
  external = network.external
  internal = network.internal
  external_rates = network_rates.external
  internal_rates = network_rates.internal
  external_total = external_rates[i]
  internal_total = sum(internal_rates[:, i])
  if sum(external_total + internal_total) > 0.
    external[i] = false
    internal[:, i] = false
    if rand() < external_total/(external_total + internal_total)
      external[i] = true
    else
      source = findfirst(rand(Multinomial(1, internal_rates[:, i]/internal_total)))
      internal[source, i] = true
    end
  end
  return Network(external, internal)
end
