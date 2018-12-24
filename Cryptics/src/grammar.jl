abstract type GrammaticalSymbol end

struct Synonym <: GrammaticalSymbol end
struct Token <: GrammaticalSymbol end
struct Wordplay <: GrammaticalSymbol end
struct Clue <: GrammaticalSymbol end
struct Definition <: GrammaticalSymbol end
struct Anagram <: GrammaticalSymbol end
struct AnagramIndicator <: GrammaticalSymbol end
struct Reverse <: GrammaticalSymbol end
struct ReverseIndicator <: GrammaticalSymbol end
struct InsertIndicator <: GrammaticalSymbol end
struct InsertAB <: GrammaticalSymbol end
struct InsertBA <: GrammaticalSymbol end

const Rule = Pair{<:GrammaticalSymbol, <:Tuple{Vararg{GrammaticalSymbol}}}
lhs(r::Rule) = first(r)
rhs(r::Rule) = last(r)

macro apply_by_reversing(Head, Args...)
    quote
        $(esc(:apply))(H::$(esc(Head)), A::Tuple{$(esc.(Args)...)}, words) = $(esc(:apply))(H, reverse(A), reverse(words))
    end
end

function cryptics_rules()
    Rule[
        Token() => (Token(), Token()),
        AnagramIndicator() => (Token(),),
        Anagram() => (AnagramIndicator(), Token()),
        Anagram() => (Token(), AnagramIndicator()),
        ReverseIndicator() => (Token(),),
        Reverse() => (ReverseIndicator(), Token()),
        Reverse() => (Token(), ReverseIndicator()),
        # InsertIndicator() => (Token(),),
        # InsertAB() => (InsertIndicator(), Wordplay(), Wordplay()),
        # InsertAB() => (Wordplay(), InsertIndicator(), Wordplay()),
        # InsertAB() => (Wordplay(), Wordplay(), InsertIndicator()),
        # InsertBA() => (InsertIndicator(), Wordplay(), Wordplay()),
        # InsertBA() => (Wordplay(), InsertIndicator(), Wordplay()),
        # InsertBA() => (Wordplay(), Wordplay(), InsertIndicator()),
        # Wordplay() => (InsertAB(),),
        # Wordplay() => (InsertBA(),),
        Wordplay() => (Token(),),
        Wordplay() => (Anagram(),),
        Wordplay() => (Reverse(),),
        Wordplay() => (Synonym(),),
        # Wordplay() => (Wordplay(), Wordplay()),
        Synonym() => (Token(),),
        Definition() => (Token(),),
        Clue() => (Wordplay(), Definition()),
        Clue() => (Definition(), Wordplay()),
    ]
end

apply(::Token, ::Tuple{Token, Token}, (a, b)) = [string(a, " ", b)]

apply(::AnagramIndicator, ::Tuple{Token}, (word,)) = [word]

function is_anagram(w1::AbstractString, w2::AbstractString)
    sort(collect(replace(w1, " " => ""))) == sort(collect(replace(w2, " " => "")))
end

function apply(::Anagram, ::Tuple{AnagramIndicator, Token}, (indicator, word))
    [candidate for candidate in keys(SYNONYMS) if word != candidate && is_anagram(word, candidate)]
    # result = String[]
    # for perm in drop(permutations(collect(replace(word, " " => ""))), 1)
    #     @show perm
    #     candidate = join(perm)
    #     if candidate in keys(SYNONYMS)
    #         push!(result, candidate)
    #     end
    # end
    # result
end
@apply_by_reversing Anagram Token AnagramIndicator

apply(::ReverseIndicator, ::Tuple{Token}, (word,)) = [word]
apply(::Reverse, ::Tuple{ReverseIndicator, Token}, (indicator, word)) = [reverse(replace(word, " " => ""))]
@apply_by_reversing Reverse Token ReverseIndicator

"""
All insertions of a into b
"""
function insertions(a, b)
    map(2:(length(b) - 1)) do breakpoint
        string(b[1:breakpoint], a, b[(breakpoint+1):end])
    end
end
# insertions(a, b) = ["insertions of $a into $b"]

apply(::InsertIndicator, ::Tuple{Token}, (word,)) = [word]
apply(::InsertAB, ::Tuple{InsertIndicator, Wordplay, Wordplay}, (indicator, a, b)) = insertions(a, b)
apply(::InsertAB, ::Tuple{Wordplay, InsertIndicator, Wordplay}, (a, indicator, b)) = insertions(a, b)
apply(::InsertAB, ::Tuple{Wordplay, Wordplay, InsertIndicator}, (a, b, indicator)) = insertions(a, b)
apply(::InsertBA, ::Tuple{InsertIndicator, Wordplay, Wordplay}, (indicator, b, a)) = insertions(a, b)
apply(::InsertBA, ::Tuple{Wordplay, InsertIndicator, Wordplay}, (b, indicator, a)) = insertions(a, b)
apply(::InsertBA, ::Tuple{Wordplay, Wordplay, InsertIndicator}, (b, a, indicator)) = insertions(a, b)

apply(::Wordplay, ::Tuple{Anagram}, (word,)) = [word]
apply(::Wordplay, ::Tuple{Reverse}, (word,)) = [word]
apply(::Wordplay, ::Tuple{Synonym}, (word,)) = [word]
apply(::Wordplay, ::Tuple{Token}, (word,)) = [word]

apply(::Wordplay, ::Tuple{Wordplay, Wordplay}, (a, b)) = [string(a, b)]

apply(::Clue, ::Tuple{Wordplay, Definition}, (wordplay, definition)) = ["\"$wordplay\" means \"$definition\""]

@apply_by_reversing Clue Definition Wordplay

apply(::Definition, ::Tuple{Token}, (def,)) = [def]

function apply(::Synonym, ::Tuple{Token}, (word,))
    if word in keys(SYNONYMS)
        collect(SYNONYMS[word])
    else
        String[]
    end
end

