abstract type GrammaticalSymbol end

struct Synonym <: GrammaticalSymbol
end

struct Token <: GrammaticalSymbol
end

struct Wordplay <: GrammaticalSymbol
end

struct Clue <: GrammaticalSymbol
end

struct Definition <: GrammaticalSymbol
end

struct Anagram <: GrammaticalSymbol
end

struct AnagramIndicator <: GrammaticalSymbol
end


const Rule = Pair{<:GrammaticalSymbol, <:Tuple{Vararg{GrammaticalSymbol}}}
lhs(r::Rule) = first(r)
rhs(r::Rule) = last(r)

function cryptics_rules()
    Rule[
        AnagramIndicator() => (Token(),),
        Anagram() => (AnagramIndicator(), Token()),
        Anagram() => (Token(), AnagramIndicator()),
        Clue() => (Wordplay(), Definition()),
        Clue() => (Definition(), Wordplay()),
        Definition() => (Token(),),
        Wordplay() => (Anagram(),),
        Wordplay() => (Synonym(),),
        Wordplay() => (Wordplay(), Wordplay()),
    ]
end

function apply!(output::Vector{String}, ::AnagramIndicator, ::Tuple{Token}, (word,))
    push!(output, word)
end

function apply!(output::Vector{String}, ::Anagram, ::Tuple{AnagramIndicator, Token}, (indicator, word))
    for perm in drop(permutations(collect(word)), 1)
        push!(output, join(perm))
    end
end

function apply!(output::Vector{String}, ::Anagram, ::Tuple{Token, AnagramIndicator}, (word, indicator))
    apply!(output, Anagram(), (AnagramIndicator(), Token()), (indicator, word))
end

function apply!(output::Vector{String}, ::Wordplay, ::Tuple{Anagram}, (word,))
    push!(output, word)
end

function apply!(output::Vector{String}, ::Clue, ::Tuple{Wordplay, Definition}, (wordplay, definition))
    push!(output, "$wordplay means $definition")
end

function apply!(output::Vector{String}, ::Clue, ::Tuple{Definition, Wordplay}, (definition, wordplay))
    push!(output, "$wordplay means $definition")
end

function apply!(output::Vector{String}, ::Definition, ::Tuple{Token}, (def,))
    push!(output, def)
end

function apply!(output::Vector{String}, ::Synonym, ::Tuple{Token}, (word,))
    if word in keys(SYNONYMS)
        append!(output, SYNONYMS[word])
    end
end
