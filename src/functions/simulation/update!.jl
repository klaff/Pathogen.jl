function update!(states::States{T},
                 event::Event{T}) where T <: EpidemicModel
  next!(states[event.individual])
  return states
end

function update!(net::TransmissionNetwork,
                 xfer::ExogenousTransmission)
  net.external[xfer.individual] = true
  return net
end

function update!(net::TransmissionNetwork,
                 xfer::EndogenousTransmission)
  net.internal[xfer.source, xfer.individual] = true
  return net
end

function update!(events::Events{T},
                 event::Event{T}) where T <: EpidemicModel

  id = event.individual
  if event.present == State_E
    events.exposed[id] = event.time
  elseif event.present == State_I
    events.infected[id] = event.time
  elseif event.present == State_R
    events.removed[id] = event.time
  end
  return events
end

function update!(rates::Rates{T},
                 tr:: TransmissionRates,
                 event::Event{T}
                 states::States{T},
                 pop::DataFrame,
                 rf::RiskFunctions{T},
                 rp::RiskParameters{T}) where T <: EpidemicModel
  id = event.individual
  if event.present == State_E
    rates.exposure[id] = 0.
    rates.infection[id] = rf.latency(rp.latency, pop, id)
  elseif event.present == State_I
    rates.infection[id] = 0.
    if T in [SEIR; SIR]
      rates.removal[id] = rf.removal(rp.removal, pop, id)
    end
    if T in [SEIR; SEI]
      @simd for i in find(states .== State_S)
        rates.exposure[i] -= tr[id, i]
      end
    elseif T in [SIR; SI]
      @simd for i in find(states .== State_S)
        rates.infection[i] -= tr[id, i]
      end
    end
  elseif event.present == State_R
    rates.removal[id] = 0.
  end
  return rates
end

function update!(tr:: TransmissionRates,
                 event::Event{T}
                 states::States{T},
                 pop::DataFrame,
                 rf::RiskFunctions{T},
                 rp::RiskParameters{T}) where T <: EpidemicModel

  id = event.individual
  if event.present == State_E
    tr.external[id] = 0.
    tr.internal[:, id] = 0.
  elseif event.present == State_I
    if event.prior == State_S
      tr.external[id] = 0.
      tr.internal[:, id] = 0.
    end
    @simd for i in find(states .== State_S)
      tr.internal[id, i] = rf.susceptibility(rp.susceptibility, pop, i) *
                           rf.transmissibility(rp.transmissibility, pop, id) *
                           rf.infectivity(rp.infectivity, pop, i, id)
    end
  elseif event.present == State_R
    tr.internal[id, :] = 0.
  end
  return tr
end