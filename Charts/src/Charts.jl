module Charts

# include("FixedCapacityVectors.jl")
# using .FixedCapacityVectors

const Rule = Pair{Symbol, Vector{Symbol}}
lhs(r::Rule) = first(r)
rhs(r::Rule) = last(r)

struct Arc
    start::Int
    stop::Int
    rule::Rule
    constituents::Vector{Union{Arc, String}}
end

rule(arc::Arc) = arc.rule
head(arc::Arc) = lhs(rule(arc))
completions(arc::Arc) = length(arc.constituents)
isactive(arc::Arc) = completions(arc) < length(rhs(rule(arc)))
function next_needed(arc::Arc)
    @assert isactive(arc)
    rhs(rule(arc))[completions(arc) + 1]
end

function Base.show(io::IO, arc::Arc)
    constituents = copy(rhs(rule(arc)))
    insert!(constituents, completions(arc) + 1, :.)
    print(io, "<$(arc.start), $(arc.stop), $(head(arc)) -> $(join(constituents, ' '))>")
end


function Base.hash(arc::Arc, h::UInt)
    h = hash(arc.start, h)
    h = hash(arc.stop, h)
    h = hash(objectid(arc.rule), h)
    for c in arc.constituents
        h = hash(objectid(c), h)
    end
    h
end

function Base.:(==)(a1::Arc, a2::Arc)
    a1.start == a2.start || return false
    a1.stop == a2.stop || return false
    a1.rule === a2.rule || return false
    length(a1.constituents) == length(a2.constituents) || return false
    for i in eachindex(a1.constituents)
        a1.constituents[i] === a2.constituents[i] || return false
    end
    true
end

struct Chart
    active::Dict{Symbol, Vector{Set{Arc}}} # organized by next needed constituent then by stop
    inactive::Dict{Symbol, Vector{Set{Arc}}} # organized by head then by start
end

Chart() = Chart(Dict{Symbol, Vector{Set{Arc}}}(),
                Dict{Symbol, Vector{Set{Arc}}}())

function storage(chart::Chart, active::Bool, symbol::Symbol, node::Integer)
    if active
        d = chart.active
    else
        d = chart.inactive
    end
    v = get!(d, symbol) do
        Vector{Set{Arc}}()
    end
    for _ in length(v):node
        push!(v, Set{Arc}())
    end
    v[node + 1]
end


function storage(chart::Chart, arc::Arc)
    if isactive(arc)
        i = arc.stop
        s = next_needed(arc)
        return storage(chart, true, s, i)
    else
        i = arc.start
        s = head(arc)
        return storage(chart, false, s, i)
    end
end

function mates(chart::Chart, candidate::Arc)
    if isactive(candidate)
        i = candidate.stop
        s = next_needed(candidate)
        return storage(chart, false, s, i)
    else
        i = candidate.start
        s = head(candidate)
        return storage(chart, true, s, i)
    end
end

function Base.push!(chart::Chart, arc::Arc)
    push!(storage(chart, arc), arc)
end

function Base.in(arc::Arc, chart::Chart)
    arc ∈ storage(chart, arc)
end

function Base.:*(a1::Arc, a2::Arc)
    @assert isactive(a1) && !isactive(a2)
    @assert next_needed(a1) == head(a2)
    Arc(a1.start, a2.stop, a1.rule, vcat(a1.constituents, a2))
end

function Base.:+(a1::Arc, a2::Arc)
    if isactive(a1) && !isactive(a2)
        a1 * a2
    elseif !isactive(a1) && isactive(a2)
        a2 * a1
    else
        throw(ArgumentError("Can only combine an active and an inactive edge"))
    end
end

function parse()
    grammar = [
        :S => [:NP, :VP, :PP],
        :S => [:NP, :VP],
        :NP => [:PN],
        :VP => [:IV],
        :PP => [:P, :NP],
    ]

    # step 1
    agenda = Arc[]

    push!(agenda, Arc(0, 1, :PN => [:W], ["mia"]))
    push!(agenda, Arc(1, 2, :IV => [:W], ["danced"]))
    parse(agenda, grammar)
end

function parse(agenda, grammar)
    chart = Chart()
    while !isempty(agenda)
        candidate = popfirst!(agenda)
        push!(chart, candidate)

        for mate in mates(chart, candidate)
            combined = candidate + mate
            if combined ∉ chart
                pushfirst!(agenda, combined)
            end
        end
        if !isactive(candidate)
            for rule in grammar
                if first(rhs(rule)) == head(candidate)
                    hypothesis = Arc(candidate.start,
                                     candidate.start,
                                     rule,
                                     [])
                    if hypothesis ∉ chart
                        pushfirst!(agenda, hypothesis)
                    end
                end
            end
        end
        @show agenda
    end
    chart
end


end # module
