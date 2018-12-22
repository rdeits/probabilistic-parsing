struct Arc
    start::Int
    stop::Int
    rule::Rule
    constituents::Vector{Arc}
    outputs::Vector{String}
end

@generated function _apply!(output::Vector{String}, head::GrammaticalSymbol,
                            args::Tuple{Vararg{GrammaticalSymbol, N}},
                            constituents::Vector{Arc}) where {N}
    quote
        for inputs in product($([:(outputs(constituents[$i])) for i in 1:N]...))
            apply!(output, head, args, $(Expr(:tuple, [:(inputs[$i]) for i in 1:N]...)))
        end
        nothing
    end
end

function _apply!(outputs::Vector{String},
                rule::Rule,
                constituents::Vector{Arc})
    _apply!(outputs, first(rule), last(rule), constituents)
end

function solve!(arc)
    _apply!(arc.outputs, arc.rule, arc.constituents)::Nothing
end

rule(arc::Arc) = arc.rule
head(arc::Arc) = lhs(rule(arc))
completions(arc::Arc) = length(arc.constituents)
constituents(arc::Arc) = arc.constituents
outputs(arc::Arc) = arc.outputs
isactive(arc::Arc) = completions(arc) < length(rhs(rule(arc)))
function next_needed(arc::Arc)
    @assert isactive(arc)
    rhs(rule(arc))[completions(arc) + 1]
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

function Base.:*(a1::Arc, a2::Arc)
    @assert isactive(a1) && !isactive(a2)
    @assert next_needed(a1) == head(a2)

    result = Arc(a1.start, a2.stop, a1.rule,
                 vcat(a1.constituents, a2),
                 String[])
    if !isactive(result)
        solve!(result)
    end
    result
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

function Base.show(io::IO, arc::Arc)
    expand(io, arc, 0)
end

name(s::GrammaticalSymbol) = typeof(s).name.name

function expand(io::IO, arc::Arc, indentation=0)
    print(io, "(", name(head(arc)))
    arguments = rhs(rule(arc))
    for i in eachindex(arguments)
        if length(arguments) > 1
            print(io, "\n", repeat(" ", indentation + 2))
        else
            print(io, " ")
        end
        if i > completions(arc)
            print(io, "(", name(arguments[i]), ")")
        else
            constituent = constituents(arc)[i]
            if constituent isa String
                print(io, "\"$constituent\"")
            else
                expand(io, constituent, indentation + 2)
            end
        end
    end
    print(io, " -> ", outputs(arc))
    print(io, ")")
end


struct Chart
    num_tokens::Int
    active::Dict{GrammaticalSymbol, Vector{Set{Arc}}} # organized by next needed constituent then by stop
    inactive::Dict{GrammaticalSymbol, Vector{Set{Arc}}} # organized by head then by start
end

num_tokens(chart::Chart) = chart.num_tokens

Chart(num_tokens) = Chart(num_tokens,
                          Dict{GrammaticalSymbol, Vector{Set{Arc}}}(),
                          Dict{GrammaticalSymbol, Vector{Set{Arc}}}())

function storage(chart::Chart, active::Bool, symbol::GrammaticalSymbol, node::Integer)
    if active
        d = chart.active
    else
        d = chart.inactive
    end
    v = get!(d, symbol) do
        [Set{Arc}() for _ in 0:num_tokens(chart)]
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

complete_parses(chart::Chart) = filter(storage(chart, false, Clue(), 0)) do arc
    arc.stop == num_tokens(chart)
end

struct Grammar
    productions::Vector{Rule}
    # words::Dict{String, Vector{GrammaticalSymbol}}
end


function initial_agenda(tokens, grammar)
    agenda = Arc[]

    for (i, token) in enumerate(tokens)
        push!(agenda, Arc(i - 1, i, Token() => (), [], [String(token)]))
    end
    agenda
end

const Agenda = Vector{Arc}

function parse(tokens, grammar)
    chart = Chart(length(tokens))
    agenda = initial_agenda(tokens, grammar)

    while !isempty(agenda)
        candidate = popfirst!(agenda)
        update!(chart, agenda, candidate, grammar)
    end
    chart
end

function update!(chart::Chart, agenda::Agenda, candidate::Arc, grammar::Grammar)
    push!(chart, candidate)

    for mate in mates(chart, candidate)
        combined = candidate + mate
        if combined ∉ chart
            pushfirst!(agenda, combined)
        end
    end
    if !isactive(candidate)
        for rule in grammar.productions
            if first(rhs(rule)) == head(candidate)
                hypothesis = Arc(candidate.start,
                                 candidate.start,
                                 rule,
                                 [],
                                 [])
                if hypothesis ∉ chart
                    pushfirst!(agenda, hypothesis)
                end
            end
        end
    end
    # @show agenda
end
