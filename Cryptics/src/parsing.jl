abstract type AbstractStrategy end
struct BottomUp <: AbstractStrategy end
struct TopDown <: AbstractStrategy end

const RuleID = Pair{UInt, Vector{UInt}}
rule_id(rule::Rule) = RuleID(objectid(lhs(rule)), collect(objectid.(rhs(rule))))


struct Arc
    start::Int
    stop::Int
    rule::Rule
    rule_id::RuleID
    constituents::SFCVector{4, Arc}
    output::String

    function Arc(start::Integer, stop::Integer, rule::Rule, rule_id::RuleID, constituents=Constituents(), output="")
        new(start, stop, rule, rule_id, constituents, output)
    end
end

const Constituents = SFCVector{4, Arc}
const Agenda = Vector{Arc}

# function Base.pop!(agenda::Agenda)
#     pop!(agenda.list)
# end

# function Base.push!(agenda::Agenda, arc::Arc)
#     if arc ∉ agenda.set
#         push!(agenda.set, arc)
#         push!(agenda.list, arc)
#     end
# end

# Base.isempty(agenda::Agenda) = isempty(agenda.list)

# Agenda() = Agenda([], Set())

@generated function _apply(head::GrammaticalSymbol,
                           args::Tuple{Vararg{GrammaticalSymbol, N}},
                           constituents::Constituents) where {N}
    quote
        apply(head, args, $(Expr(:tuple, [:(constituents[$i].output) for i in 1:N]...)))
    end
end

function apply(rule::Rule,
                constituents::Constituents)
    _apply(lhs(rule), rhs(rule), constituents)
end


rule(arc::Arc) = arc.rule
rule_id(arc::Arc) = arc.rule_id
head(arc::Arc) = lhs(rule_id(arc))
num_arguments(arc::Arc) = length(rhs(rule_id(arc)))
num_completions(arc::Arc) = length(arc.constituents)
isactive(arc::Arc) = num_completions(arc) < num_arguments(arc)
constituents(arc::Arc) = arc.constituents
output(arc::Arc) = arc.output
function next_needed(arc::Arc)
    @assert isactive(arc)
    rhs(rule_id(arc))[num_completions(arc) + 1]
end

function Base.hash(arc::Arc, h::UInt)
    h = hash(arc.start, h)
    h = hash(arc.stop, h)
    h = hash(arc.rule_id, h)
    for c in arc.constituents
        h = hash(objectid(c), h)
    end
    h = hash(arc.output, h)
    h
end

function Base.:(==)(a1::Arc, a2::Arc)
    a1.start == a2.start || return false
    a1.stop == a2.stop || return false
    a1.rule_id == a2.rule_id || return false
    length(a1.constituents) == length(a2.constituents) || return false
    for i in eachindex(a1.constituents)
        a1.constituents[i] === a2.constituents[i] || return false
    end
    a1.output == a2.output || return false
    true
end

function _combine(start, stop, rule, rule_id, constituents, outputs)
    [Arc(start, stop, rule, rule_id, constituents, output) for output in outputs]
end

function combined_arcs(a1::Arc, a2::Arc)::Vector{Arc}
    if !isactive(a1) && isactive(a2)
        return combined_arcs(a2, a1)
    elseif isactive(a1) && !isactive(a2)
        new_constituents = push(a1.constituents, a2)
        if num_completions(a1) + 1 == num_arguments(a1)
            # then the combined arc will be complete, so we should solve it
            outputs = apply(a1.rule, new_constituents)
        else
            outputs = [""]
        end
        return _combine(a1.start, a2.stop, a1.rule, a1.rule_id, new_constituents, outputs)
    else
        error("Exactly one of a1 or a2 must be active")
    end
    return result
end

function Base.show(io::IO, arc::Arc)
    expand(io, arc, 0)
end

name(s::GrammaticalSymbol) = typeof(s).name.name

function expand(io::IO, arc::Arc, indentation=0)
    print(io, "(", arc.start, ", ", arc.stop, " ", name(lhs(rule(arc))))
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

const ChartStorage = Vector{Arc}

struct Chart
    num_tokens::Int
    active::Dict{UInt, Vector{ChartStorage}} # organized by next needed constituent then by stop
    inactive::Dict{UInt, Vector{ChartStorage}} # organized by head then by start
end

num_tokens(chart::Chart) = chart.num_tokens

Chart(num_tokens) = Chart(num_tokens,
                          Dict{UInt, Vector{ChartStorage}}(),
                          Dict{UInt, Vector{ChartStorage}}())

function storage(chart::Chart, active::Bool, symbol::UInt, node::Integer)
    if active
        d = chart.active
    else
        d = chart.inactive
    end
    v = get!(d, symbol) do
        [ChartStorage() for _ in 0:num_tokens(chart)]
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

# TODO: generalize start token
complete_parses(chart::Chart) = filter(storage(chart, false, objectid(Clue()), 0)) do arc
    arc.stop == num_tokens(chart)
end

struct Grammar
    productions::Vector{Pair{Rule, RuleID}}
end

function Grammar(rules::AbstractVector{<:Rule})
    Grammar(Pair{Rule, RuleID}[rule => rule_id(rule) for rule in rules])
end

function initial_chart(tokens, grammar, ::BottomUp)
    chart = Chart(length(tokens))
end


function initial_agenda(tokens, grammar, ::BottomUp)
    agenda = Agenda()

    rule = Token() => ()
    id = rule_id(rule)
    for (i, token) in enumerate(tokens)
        push!(agenda, Arc(i - 1, i, rule, id, Constituents(), String(token)))
    end
    agenda
end

function initial_chart(tokens, grammar, ::TopDown)
    chart = Chart(length(tokens))
    rule = Token() => ()
    id = rule_id(rule)
    for (i, token) in enumerate(tokens)
        push!(chart, Arc(i - 1, i, rule, id, Constituents(), String(token)))
    end
    chart
end

function initial_agenda(tokens, grammar, ::TopDown)
    agenda = Agenda()
    for (rule, rule_id) in grammar.productions
        if lhs(rule) == Clue()  # TODO get start symbol from grammar
            push!(agenda, Arc(0, 0, rule, rule_id))
        end
    end
    agenda
end

function parse(tokens, grammar, strategy::AbstractStrategy)
    chart = initial_chart(tokens, grammar, strategy)
    agenda = initial_agenda(tokens, grammar, strategy)
    predictions = Set{Tuple{UInt, Int}}()

    while !isempty(agenda)
        candidate = pop!(agenda)
        # @show candidate
        update!(chart, agenda, candidate, grammar, predictions, strategy)
        # readline(stdin) == "q" && break
    end
    chart
end

function update!(chart::Chart, agenda::Agenda, candidate::Arc, grammar::Grammar, predictions::Set{Tuple{UInt, Int}}, strategy::AbstractStrategy)
    # if candidate in chart
    #     @show candidate
    #     error("duplicate candidate")
    # end
    # @show candidate
    push!(chart, candidate)

    for mate in mates(chart, candidate)
        for combined in combined_arcs(candidate, mate)
            # @show combined
            # if combined in chart
            #     @show combined
            #     error("duplicate combined")
            # end
            # if combined in agenda
            #     @show combined
            #     error("duplicate combined")
            # end
            # if combined ∉ chart
                push!(agenda, combined)
            # end
        end
    end
    predict!(agenda, chart, candidate, grammar, predictions, strategy)
    # @show agenda
end

function predict!(agenda::Agenda, chart::Chart, candidate::Arc, grammar::Grammar, predictions::Set{Tuple{UInt, Int}}, ::BottomUp)
    if !isactive(candidate)
        key = (head(candidate), candidate.start)
        if key ∉ predictions
            push!(predictions, key)
            for (rule, rule_id) in grammar.productions
                if first(rhs(rule_id)) == head(candidate)
                    hypothesis = Arc(candidate.start,
                                     candidate.start,
                                     rule,
                                     rule_id)
                    # if hypothesis in chart
                    #     @show hypothesis
                    #     error("duplicate hypothesis")
                    # end
                    # if hypothesis in agenda
                    #     @show hypothesis
                    #     error("duplicate hypothesis")
                    # end
                    # if hypothesis ∉ chart
                        push!(agenda, hypothesis)
                    # end
                end
            end
        end
    end
end

function predict!(agenda::Agenda, chart::Chart, candidate::Arc, grammar::Grammar, predictions::Set{Tuple{UInt, Int}}, ::TopDown)
    if isactive(candidate)
        key = (next_needed(candidate), candidate.stop)
        if key ∉ predictions
            push!(predictions, key)
            for (rule, rule_id) in grammar.productions
                if lhs(rule_id) == next_needed(candidate)
                    hypothesis = Arc(candidate.stop, candidate.stop, rule, rule_id)
                    # if hypothesis in chart
                    #     @show hypothesis
                    #     error("duplicate hypothesis")
                    # end
                    # if hypothesis in agenda
                    #     @show hypothesis
                    #     error("duplicate hypothesis")
                    # end
                    # if hypothesis ∉ chart
                        push!(agenda, hypothesis)
                    # end
                end
            end
        end
    end
end

function solution_quality(arc::Arc)
    @assert lhs(rule(arc)) === Clue() && length(constituents(arc)) == 2
    w1, w2 = output.(constituents(arc))
    if w2 in keys(SYNONYMS) && w1 in SYNONYMS[w2]
        1.0
    else
        0.0
    end
end

function solutions(chart::Chart)
    [p for p in complete_parses(chart) if solution_quality(p) == 1.0]
end

