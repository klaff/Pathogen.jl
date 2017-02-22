"""
loglikelihood(riskparams::RiskParameters,
              events::Events,
              riskfuncs::RiskFunctions,
              population::DataFrame)
              
Calculates the log likelihood of a continuous time individual level model of
infectious disease transmission
"""
function loglikelihood(riskparams::RiskParameters,
                       events::Events,
                       riskfuncs::RiskFunctions,
                       population::DataFrame)
  # Initialize
  ll = 0.
  eventtimes = [events.exposed events.infected events.removed]
  states = States(population)
  rates = initialize_rates(states, population, riskfuncs, riskparams)
  network_rates = NetworkRates(events.individuals)

  # Find event order
  eventorder = sortperm(eventtimes[:])

  for i = 1:length(eventorder)
    # Stop log likelihood calculation after the last event
    isnan(eventtimes[eventorder[i]]) && break

    # Stop log likelihood calculation anytime the loglikelihood goes to -Inf
    ll == -Inf && break

    # Convert linear index to an event tuple (individual, event type)
    individual, eventtype = ind2sub(size(eventtimes), eventorder[i])

    # Find the rate total
    ratetotal = sum([sum(rates[1]);
                     sum(rates[2]);
                     sum(rates[3]);
                     sum(rates[4])])

    if i > 1
      # Find the time difference between consecutive events
      ΔT = eventtimes[eventorder[i]] - eventtimes[eventorder[i-1]]

      # loglikelihood contribution of specific event
      ll += log(ratetotal) - ratetotal*ΔT
    end

    # For exposure events
    if eventtype == 1
      # Copy exposure rates from this moment in time
      network_rates.external[individual] = rates.external[individual]
      network_rates.internal[:, individual] = rates.internal[:, individual]
      exposuretotal = network_rates.external[individual] + sum(network_rates.internal[:, individual])

      # loglikelihood contribution of an exposure event
      ll += log(exposuretotal/ratetotal)
      update_states!(states, (1, individual))
      update_rates!(rates, states, (1, individual), population, riskfuncs, riskparams)
    # For non-exposure events
    else
      # loglikelihood contribution of a non-exposure event
      ll += log(rates[eventtype+1][individual]/ratetotal)
      update_states!(states, (eventtype+1, individual))
      update_rates!(rates, states, (eventtype+1, individual), population, riskfuncs, riskparams)
    end
  end
  return ll, network_rates
end