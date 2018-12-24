abstract type AbstractStrategy end
struct BottomUp <: AbstractStrategy end
struct TopDown <: AbstractStrategy end

struct Arc
    start::Int
    stop::Int
    rule::Rule
    constituents::Vector{Arc}
    output::String

    Arc(start::Integer, stop::Integer, rule::Rule, constituents=Arc[], output="") = new(start, stop, rule, constituents, output)
end

const Agenda = Vector{Arc}

@generated function _apply(head::GrammaticalSymbol,
                           args::Tuple{Vararg{GrammaticalSymbol, N}},
                           constituents::Vector{Arc}) where {N}
    quote
        apply(head, args, $(Expr(:tuple, [:(constituents[$i].output) for i in 1:N]...)))
    end
end

function apply(rule::Rule,
                constituents::Vector{Arc})
    _apply(first(rule), last(rule), constituents)
end

rule(arc::Arc) = arc.rule
head(arc::Arc) = lhs(rule(arc))
num_arguments(arc::Arc)::Int = length(rhs(rule(arc)))
num_completions(arc::Arc) = length(arc.constituents)
isactive(arc::Arc) = num_completions(arc) < num_arguments(arc)
constituents(arc::Arc) = arc.constituents
output(arc::Arc) = arc.output
function next_needed(arc::Arc)
    @assert isactive(arc)
    rhs(rule(arc))[num_completions(arc) + 1]
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

function _combine(a1::Arc, a2::Arc, output::String)
    @assert isactive(a1) && !isactive(a2)
    @assert next_needed(a1) == head(a2)
    Arc(a1.start, a2.stop, a1.rule, vcat(a1.constituents, a2), output)
end

function combinations(a1::Arc, a2::Arc)::Vector{Arc}
    if !isactive(a1) && isactive(a2)
        return combinations(a2, a1)
    elseif isactive(a1) && !isactive(a2)
        new_constituents = vcat(a1.constituents, a2)
        if num_completions(a1) + 1 == num_arguments(a1)
            # then the combined arc will be complete, so we should solve it
            result = Arc[]
            for output in apply(a1.rule, new_constituents)
                combined = _combine(a1, a2, output)
                println(combined)
                push!(result, combined)
            end
        else
            result = [_combine(a1, a2, "")]
        end
    end
    return result
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
    print(io, "(", arc.start, ", ", arc.stop, " ", name(head(arc)))
    arguments = rhs(rule(arc))
    for i in eachindex(arguments)
        if length(arguments) > 1
            print(io, "\n", repeat(" ", indentation + 2))
        else
            print(io, " ")
        end
        if i > num_completions(arc)
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
    print(io, " -> ", output(arc))
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

function initial_chart(tokens, grammar, ::BottomUp)
    chart = Chart(length(tokens))
end


function initial_agenda(tokens, grammar, ::BottomUp)
    agenda = Arc[]

    for (i, token) in enumerate(tokens)
        push!(agenda, Arc(i - 1, i, Token() => (), [], String(token)))
    end
    agenda
end

function initial_chart(tokens, grammar, ::TopDown)
    chart = Chart(length(tokens))
    for (i, token) in enumerate(tokens)
        push!(chart, Arc(i - 1, i, Token() => (), [], String(token)))
    end
    chart
end

function initial_agenda(tokens, grammar, ::TopDown)
    agenda = Arc[]
    for rule in grammar.productions
        if lhs(rule) == Clue()  # TODO get start symbol from grammar
            push!(agenda, Arc(0, 0, rule))
        end
    end
    agenda
end


const Agenda = Vector{Arc}

function parse(tokens, grammar, strategy::AbstractStrategy)
    @assert length(tokens) == 3 "need to generalize combinations"
    chart = initial_chart(tokens, grammar, strategy)
    agenda = initial_agenda(tokens, grammar, strategy)

    while !isempty(agenda)
        candidate = popfirst!(agenda)
        @show candidate
        update!(chart, agenda, candidate, grammar, strategy)
        # readline(stdin) == "q" && break
    end
    chart
end

function update!(chart::Chart, agenda::Agenda, candidate::Arc, grammar::Grammar, strategy::AbstractStrategy)
    push!(chart, candidate)

    for mate in mates(chart, candidate)
        println("trying to combine: $mate and $candidate")
        for combined in combinations(candidate, mate)
            @show combined
            if combined ∉ chart
                pushfirst!(agenda, combined)
            end
        end
        println("done")
    end
    predict!(agenda, chart, candidate, grammar, strategy)
    # @show agenda
end

function predict!(agenda::Agenda, chart::Chart, candidate::Arc, grammar::Grammar, ::BottomUp)
    if !isactive(candidate)
        for rule in grammar.productions
            if first(rhs(rule)) == head(candidate)
                hypothesis = Arc(candidate.start,
                                 candidate.start,
                                 rule)
                if hypothesis ∉ chart
                    pushfirst!(agenda, hypothesis)
                end
            end
        end
    end
end

function predict!(agenda::Agenda, chart::Chart, candidate::Arc, grammar::Grammar, ::TopDown)
    if isactive(candidate)
        for rule in grammar.productions
            if lhs(rule) == next_needed(candidate)
                hypothesis = Arc(candidate.stop, candidate.stop, rule)
                @show hypothesis
                if hypothesis ∉ chart
                    pushfirst!(agenda, hypothesis)
                end
            end
        end
    end
end

