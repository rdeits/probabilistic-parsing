abstract type GrammaticalSymbol end

struct Synonym <: GrammaticalSymbol end
struct Token <: GrammaticalSymbol end
struct Phrase <: GrammaticalSymbol end
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

# macro passthrough(Head, Arg)
#     quote
#         $(esc(:apply))(H::$(esc(Head)), A::Tuple{$(esc(Arg))}, (word,)) = [word]
#     end
# end

function cryptics_rules()
    Rule[
        Phrase() => (Token(),),
        Phrase() => (Phrase(), Token()),
        AnagramIndicator() => (Phrase(),),
        Wordplay() => (AnagramIndicator(), Phrase()),
        Wordplay() => (Phrase(), AnagramIndicator()),
        ReverseIndicator() => (Phrase(),),
        Wordplay() => (ReverseIndicator(), Phrase()),
        Wordplay() => (Phrase(), ReverseIndicator()),
        # InsertABIndicator() => (Phrase(),),
        # HeadIndicator() => (Phrase(),),
        # StraddleIndicator() => (Phrase(),),
        # Wordplay() => (InsertABIndicator(), Wordplay(), Wordplay()),
        # Wordplay() => (Wordplay(), InsertABIndicator(), Wordplay()),
        # Wordplay() => (Wordplay(), Wordplay(), InsertABIndicator()),
        # Wordplay() => (InsertBAIndicator(), Wordplay(), Wordplay()),
        # Wordplay() => (Wordplay(), InsertBAIndicator(), Wordplay()),
        # Wordplay() => (Wordplay(), Wordplay(), InsertBAIndicator()),
        # Wordplay() => (StraddleIndicator(), Token(), Token()),
        # Wordplay() => (Token(), Token(), StraddleIndicator()),
        Wordplay() => (Token(),),
        # Wordplay() => (Synonym(),),
        Wordplay() => (Wordplay(), Wordplay()),
        # Wordplay() => (HeadIndicator(), Token()),
        # Wordplay() => (Token(), HeadIndicator()),
        # Synonym() => (Phrase(),),
        Definition() => (Phrase(),),
        Clue() => (Wordplay(), Definition()),
        Clue() => (Definition(), Wordplay()),
    ]
end

# @passthrough AnagramIndicator Phrase
# @passthrough HeadIndicator Token
# @passthrough ReverseIndicator Token
# @passthrough InsertABIndicator Token
# @passthrough InsertBAIndicator Token
# @passthrough StraddleIndicator Token
# @passthrough Wordplay Synonym
# @passthrough Wordplay Token
# @passthrough Definition Phrase
# @passthrough Phrase Token

propagate(context::Context, rule::Rule, inputs::AbstractVector{<:AbstractString}) = propagate(context, lhs(rule), rhs(rule), inputs)

# Fallback methods for one-argument rules which just pass
# the context down and the output up
apply(::GrammaticalSymbol, ::Tuple{GrammaticalSymbol}, (word,)) = [word]
propagate(context::Context, head::GrammaticalSymbol, args::Tuple{GrammaticalSymbol}, inputs) = context

apply(::Phrase, ::Tuple{Phrase, Token}, (a, b)) = [string(a, " ", b)]
propagate(context::Context, ::Phrase, ::Tuple{Phrase, Token}, inputs) = propagate_concatenation(context, inputs)

function propagate_concatenation(context, inputs)
    @assert 0 <= length(inputs) <= 1
    if length(inputs) == 0
        Context(1,
                max(0, context.max_length - 1),
                if context.constraint == IsWord || context.constraint == IsPrefix
                    IsPrefix
                else
                    nothing
                end)
    else
        len = length(first(inputs))
        Context(max(0, context.min_length - len),
                max(0, context.max_length - len),
                if context.constraint == IsWord || context.constraint == IsSuffix
                    IsSuffix
                else
                    nothing
                end)
    end
end

function apply(::Wordplay, ::Tuple{AnagramIndicator, Phrase}, (indicator, phrase))
    results = get(Vector{String}, WORDS_BY_ANAGRAM, join(sort(collect(replace(phrase, " " => "")))))
    filter(w -> w != phrase, results)
end
propagate(context::Context, ::Wordplay, ::Tuple{AnagramIndicator, Phrase}, inputs) = propagate_to_argument(context, 2, inputs)
@apply_by_reversing Wordplay Phrase AnagramIndicator
propagate(context::Context, ::Wordplay, ::Tuple{Phrase, AnagramIndicator}, inputs) = propagate_to_argument(context, 1, inputs)

function propagate_to_argument(context, index, inputs)
    if length(inputs) + 1 == index
        context
    else
        unconstrained_context()
    end
end


apply(::Wordplay, ::Tuple{Wordplay, Wordplay}, (a, b)) = [string(a, b)]
propagate(context::Context, ::Wordplay, ::Tuple{Wordplay, Wordplay}, inputs) = propagate_concatenation(context, inputs)

apply(::Clue, ::Tuple{Wordplay, Definition}, (wordplay, definition)) = [wordplay]
propagate(context::Context, ::Clue, ::Tuple{Wordplay, Definition}, inputs) = propagate_to_argument(context, 1, inputs)
@apply_by_reversing Clue Definition Wordplay
propagate(context::Context, ::Clue, ::Tuple{Definition, Wordplay}, inputs) = propagate_to_argument(context, 2, inputs)


apply(::Wordplay, ::Tuple{ReverseIndicator, Phrase}, (indicator, word)) = [reverse(replace(word, " " => ""))]
propagate(context::Context, ::Wordplay, ::Tuple{ReverseIndicator, Phrase}, inputs) = propagate_to_argument(context, 2, inputs)
@apply_by_reversing Wordplay Phrase ReverseIndicator
propagate(context::Context, ::Wordplay, ::Tuple{Phrase, ReverseIndicator}, inputs) = propagate_to_argument(context, 1, inputs)

# """
# All insertions of a into b
# """
# function insertions(a, b)
#     map(2:(length(b) - 1)) do breakpoint
#         string(b[1:breakpoint], a, b[(breakpoint+1):end])
#     end
# end
# # insertions(a, b) = ["insertions of $a into $b"]

# apply(::Wordplay, ::Tuple{InsertABIndicator, Wordplay, Wordplay}, (indicator, a, b)) = insertions(a, b)
# apply(::Wordplay, ::Tuple{Wordplay, InsertABIndicator, Wordplay}, (a, indicator, b)) = insertions(a, b)
# apply(::Wordplay, ::Tuple{Wordplay, Wordplay, InsertABIndicator}, (a, b, indicator)) = insertions(a, b)
# apply(::Wordplay, ::Tuple{InsertBAIndicator, Wordplay, Wordplay}, (indicator, b, a)) = insertions(a, b)
# apply(::Wordplay, ::Tuple{Wordplay, InsertBAIndicator, Wordplay}, (b, indicator, a)) = insertions(a, b)
# apply(::Wordplay, ::Tuple{Wordplay, Wordplay, InsertBAIndicator}, (b, a, indicator)) = insertions(a, b)

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

# function apply(::Wordplay, ::Tuple{StraddleIndicator, Token, Token}, (indicator, w1, w2))
#     straddling_words(w1, w2)
# end
# function apply(::Wordplay, ::Tuple{Token, Token, StraddleIndicator}, (w1, w2, indicator))
#     straddling_words(w1, w2)
# end


# apply(::Wordplay, ::Tuple{HeadIndicator, Token}, (indicator, word)) = [string(word[1])]
# @apply_by_reversing Wordplay Token HeadIndicator

# function apply(::Synonym, ::Tuple{Token}, (word,))
#     if word in keys(SYNONYMS)
#         collect(SYNONYMS[word])
#     else
#         String[]
#     end
# end

        # AnagramIndicator() => (Phrase(),),
        # Wordplay() => (AnagramIndicator(), Phrase()),
        # Wordplay() => (Phrase(), AnagramIndicator()),
        # ReverseIndicator() => (Phrase(),),
        # Wordplay() => (ReverseIndicator(), Phrase()),
        # Wordplay() => (Phrase(), ReverseIndicator()),
        # InsertABIndicator() => (Phrase(),),
        # HeadIndicator() => (Phrase(),),
        # StraddleIndicator() => (Phrase(),),
        # Wordplay() => (InsertABIndicator(), Wordplay(), Wordplay()),
        # Wordplay() => (Wordplay(), InsertABIndicator(), Wordplay()),
        # Wordplay() => (Wordplay(), Wordplay(), InsertABIndicator()),
        # Wordplay() => (InsertBAIndicator(), Wordplay(), Wordplay()),
        # Wordplay() => (Wordplay(), InsertBAIndicator(), Wordplay()),
        # Wordplay() => (Wordplay(), Wordplay(), InsertBAIndicator()),
        # Wordplay() => (StraddleIndicator(), Token(), Token()),
        # Wordplay() => (Token(), Token(), StraddleIndicator()),
        # Wordplay() => (Token(),),
        # Wordplay() => (Synonym(),),
        # Wordplay() => (Wordplay(), Wordplay()),
        # Wordplay() => (HeadIndicator(), Token()),
        # Wordplay() => (Token(), HeadIndicator()),
        # Synonym() => (Phrase(),),
        # Definition() => (Phrase(),),
        # Clue() => (Wordplay(), Definition()),
        # Clue() => (Definition(), Wordplay()),
