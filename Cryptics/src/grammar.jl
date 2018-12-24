abstract type GrammaticalSymbol end

struct Synonym <: GrammaticalSymbol end
struct Token <: GrammaticalSymbol end
struct Wordplay <: GrammaticalSymbol end
struct Clue <: GrammaticalSymbol end
struct Definition <: GrammaticalSymbol end
struct AnagramIndicator <: GrammaticalSymbol end
struct ReverseIndicator <: GrammaticalSymbol end
struct InsertABIndicator <: GrammaticalSymbol end
struct InsertBAIndicator <: GrammaticalSymbol end
struct HeadIndicator <: GrammaticalSymbol end

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
        Wordplay() => (AnagramIndicator(), Token()),
        Wordplay() => (Token(), AnagramIndicator()),
        ReverseIndicator() => (Token(),),
        Wordplay() => (ReverseIndicator(), Token()),
        Wordplay() => (Token(), ReverseIndicator()),
        InsertABIndicator() => (Token(),),
        HeadIndicator() => (Token(),),
        Wordplay() => (InsertABIndicator(), Wordplay(), Wordplay()),
        Wordplay() => (Wordplay(), InsertABIndicator(), Wordplay()),
        Wordplay() => (Wordplay(), Wordplay(), InsertABIndicator()),
        Wordplay() => (InsertBAIndicator(), Wordplay(), Wordplay()),
        Wordplay() => (Wordplay(), InsertBAIndicator(), Wordplay()),
        Wordplay() => (Wordplay(), Wordplay(), InsertBAIndicator()),
        Wordplay() => (Token(),),
        Wordplay() => (Synonym(),),
        Wordplay() => (Wordplay(), Wordplay()),
        Wordplay() => (HeadIndicator(), Token()),
        Wordplay() => (Token(), HeadIndicator()),
        Synonym() => (Token(),),
        Definition() => (Token(),),
        Clue() => (Wordplay(), Definition()),
        Clue() => (Definition(), Wordplay()),
    ]
end

apply(::Token, ::Tuple{Token, Token}, (a, b)) = [string(a, " ", b)]

apply(::AnagramIndicator, ::Tuple{Token}, (word,)) = [word]
apply(::HeadIndicator, ::Tuple{Token}, (word,)) = [word]

function is_anagram(w1::AbstractString, w2::AbstractString)
    sort(collect(replace(w1, " " => ""))) == sort(collect(replace(w2, " " => "")))
end

function apply(::Wordplay, ::Tuple{AnagramIndicator, Token}, (indicator, word))
    [candidate for candidate in keys(SYNONYMS) if word != candidate && is_anagram(word, candidate)]
end
@apply_by_reversing Wordplay Token AnagramIndicator

apply(::ReverseIndicator, ::Tuple{Token}, (word,)) = [word]
apply(::Wordplay, ::Tuple{ReverseIndicator, Token}, (indicator, word)) = [reverse(replace(word, " " => ""))]
@apply_by_reversing Wordplay Token ReverseIndicator

"""
All insertions of a into b
"""
function insertions(a, b)
    map(2:(length(b) - 1)) do breakpoint
        string(b[1:breakpoint], a, b[(breakpoint+1):end])
    end
end
# insertions(a, b) = ["insertions of $a into $b"]

apply(::InsertABIndicator, ::Tuple{Token}, (word,)) = [word]
apply(::InsertBAIndicator, ::Tuple{Token}, (word,)) = [word]
apply(::Wordplay, ::Tuple{InsertABIndicator, Wordplay, Wordplay}, (indicator, a, b)) = insertions(a, b)
apply(::Wordplay, ::Tuple{Wordplay, InsertABIndicator, Wordplay}, (a, indicator, b)) = insertions(a, b)
apply(::Wordplay, ::Tuple{Wordplay, Wordplay, InsertABIndicator}, (a, b, indicator)) = insertions(a, b)
apply(::Wordplay, ::Tuple{InsertBAIndicator, Wordplay, Wordplay}, (indicator, b, a)) = insertions(a, b)
apply(::Wordplay, ::Tuple{Wordplay, InsertBAIndicator, Wordplay}, (b, indicator, a)) = insertions(a, b)
apply(::Wordplay, ::Tuple{Wordplay, Wordplay, InsertBAIndicator}, (b, a, indicator)) = insertions(a, b)

apply(::Wordplay, ::Tuple{Synonym}, (word,)) = [word]
apply(::Wordplay, ::Tuple{Token}, (word,)) = [word]
apply(::Wordplay, ::Tuple{Wordplay, Wordplay}, (a, b)) = [string(a, b)]

apply(::Wordplay, ::Tuple{HeadIndicator, Token}, (indicator, word)) = [string(word[1])]
@apply_by_reversing Wordplay Token HeadIndicator

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

