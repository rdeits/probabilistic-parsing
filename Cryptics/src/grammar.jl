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
struct StraddleIndicator <: GrammaticalSymbol end

const Rule = Pair{<:GrammaticalSymbol, <:Tuple{Vararg{GrammaticalSymbol}}}
lhs(r::Pair) = first(r)
rhs(r::Pair) = last(r)

macro apply_by_reversing(Head, Args...)
    quote
        $(esc(:apply))(H::$(esc(Head)), A::Tuple{$(esc.(Args)...)}, words) = $(esc(:apply))(H, reverse(A), reverse(words))
    end
end

macro passthrough(Head, Arg)
    quote
        $(esc(:apply))(H::$(esc(Head)), A::Tuple{$(esc(Arg))}, (word,)) = [word]
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
        StraddleIndicator() => (Token(),),
        Wordplay() => (InsertABIndicator(), Wordplay(), Wordplay()),
        Wordplay() => (Wordplay(), InsertABIndicator(), Wordplay()),
        Wordplay() => (Wordplay(), Wordplay(), InsertABIndicator()),
        Wordplay() => (InsertBAIndicator(), Wordplay(), Wordplay()),
        Wordplay() => (Wordplay(), InsertBAIndicator(), Wordplay()),
        Wordplay() => (Wordplay(), Wordplay(), InsertBAIndicator()),
        Wordplay() => (StraddleIndicator(), Token(), Token()),
        Wordplay() => (Token(), Token(), StraddleIndicator()),
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

@passthrough AnagramIndicator Token
@passthrough HeadIndicator Token
@passthrough ReverseIndicator Token
@passthrough InsertABIndicator Token
@passthrough InsertBAIndicator Token
@passthrough StraddleIndicator Token
@passthrough Wordplay Synonym
@passthrough Wordplay Token
@passthrough Definition Token

apply(::Token, ::Tuple{Token, Token}, (a, b)) = [string(a, " ", b)]

function apply(::Wordplay, ::Tuple{AnagramIndicator, Token}, (indicator, word))
    get(Vector{String}, WORDS_BY_ANAGRAM, join(sort(collect(word))))
end
@apply_by_reversing Wordplay Token AnagramIndicator

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

apply(::Wordplay, ::Tuple{InsertABIndicator, Wordplay, Wordplay}, (indicator, a, b)) = insertions(a, b)
apply(::Wordplay, ::Tuple{Wordplay, InsertABIndicator, Wordplay}, (a, indicator, b)) = insertions(a, b)
apply(::Wordplay, ::Tuple{Wordplay, Wordplay, InsertABIndicator}, (a, b, indicator)) = insertions(a, b)
apply(::Wordplay, ::Tuple{InsertBAIndicator, Wordplay, Wordplay}, (indicator, b, a)) = insertions(a, b)
apply(::Wordplay, ::Tuple{Wordplay, InsertBAIndicator, Wordplay}, (b, indicator, a)) = insertions(a, b)
apply(::Wordplay, ::Tuple{Wordplay, Wordplay, InsertBAIndicator}, (b, a, indicator)) = insertions(a, b)

# function interior_substrings(word::AbstractString, words_only=true, min_length=2, max_length=(length(word) - 2))
#     results = String[]
#     for i in 2:(length(word) - 1)
#         for j in (i + min_length - 1):min(i + max_length - 1, length(word) - 1)
#             candidate = word[i:j]
#             if !words_only || is_word(candidate)
#                 push!(results, word[i:j])
#             end
#         end
#     end
#     results
# end

function apply(::Wordplay, ::Tuple{StraddleIndicator, Token, Token}, (indicator, w1, w2))
    straddling_words(w1, w2)
end
function apply(::Wordplay, ::Tuple{Token, Token, StraddleIndicator}, (w1, w2, indicator))
    straddling_words(w1, w2)
end

apply(::Wordplay, ::Tuple{Wordplay, Wordplay}, (a, b)) = [string(a, b)]

apply(::Wordplay, ::Tuple{HeadIndicator, Token}, (indicator, word)) = [string(word[1])]
@apply_by_reversing Wordplay Token HeadIndicator

apply(::Clue, ::Tuple{Wordplay, Definition}, (wordplay, definition)) = ["\"$wordplay\" means \"$definition\""]
@apply_by_reversing Clue Definition Wordplay

function apply(::Synonym, ::Tuple{Token}, (word,))
    if word in keys(SYNONYMS)
        collect(SYNONYMS[word])
    else
        String[]
    end
end

