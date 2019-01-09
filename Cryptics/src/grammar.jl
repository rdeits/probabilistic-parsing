abstract type GrammaticalSymbol end

struct Synonym <: GrammaticalSymbol end
struct Token <: GrammaticalSymbol end
struct Phrase <: GrammaticalSymbol end
struct Wordplay <: GrammaticalSymbol end
struct Clue <: GrammaticalSymbol end
struct Definition <: GrammaticalSymbol end

abstract type AbstractIndicator <: GrammaticalSymbol end
struct AnagramIndicator <: AbstractIndicator end
struct ReverseIndicator <: AbstractIndicator end
struct InsertABIndicator <: AbstractIndicator end
struct InsertBAIndicator <: AbstractIndicator end
struct HeadIndicator <: AbstractIndicator end
struct StraddleIndicator <: AbstractIndicator end

const Rule = Pair{<:GrammaticalSymbol, <:Tuple{Vararg{GrammaticalSymbol}}}
lhs(r::Pair) = first(r)
rhs(r::Pair) = last(r)

macro apply_by_reversing(Head, Args...)
    quote
        $(esc(:apply))(H::$(esc(Head)), A::Tuple{$(esc.(Args)...)}, words) = $(esc(:apply))(H, reverse(A), reverse(words))
    end
end

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
        HeadIndicator() => (Phrase(),),
        Wordplay() => (HeadIndicator(), Token()),
        Wordplay() => (Token(), HeadIndicator()),
        InsertABIndicator() => (Phrase(),),
        InsertBAIndicator() => (Phrase(),),
        Wordplay() => (InsertABIndicator(), Wordplay(), Wordplay()),
        Wordplay() => (Wordplay(), InsertABIndicator(), Wordplay()),
        Wordplay() => (Wordplay(), Wordplay(), InsertABIndicator()),
        Wordplay() => (InsertBAIndicator(), Wordplay(), Wordplay()),
        Wordplay() => (Wordplay(), InsertBAIndicator(), Wordplay()),
        Wordplay() => (Wordplay(), Wordplay(), InsertBAIndicator()),
        StraddleIndicator() => (Phrase(),),
        Wordplay() => (StraddleIndicator(), Token(), Token()),
        Wordplay() => (Token(), Token(), StraddleIndicator()),
        Wordplay() => (Token(),),
        Wordplay() => (Synonym(),),
        Wordplay() => (Wordplay(), Wordplay()),
        Synonym() => (Phrase(),),
        Definition() => (Phrase(),),
        Clue() => (Wordplay(), Definition()),
        Clue() => (Definition(), Wordplay()),
    ]
end

propagate(context::Context, rule::Rule, inputs::AbstractVector) = propagate(context, lhs(rule), rhs(rule), inputs)

# Fallback methods for one-argument rules which just pass
# the context down and the output up
apply(::GrammaticalSymbol, ::Tuple{GrammaticalSymbol}, (word,)) = [word]
propagate(context::Context, head::GrammaticalSymbol, args::Tuple{GrammaticalSymbol}, inputs) = context
propagate(context::Context, head::AbstractIndicator, args::Tuple{GrammaticalSymbol}, inputs) = unconstrained_context()

apply(::Phrase, ::Tuple{Phrase, Token}, (a, b)) = [string(a, " ", b)]
propagate(context::Context, ::Phrase, ::Tuple{Phrase, Token}, inputs) = propagate_concatenation(context, inputs)

function propagate_concatenation(context, inputs)
    @assert 0 <= length(inputs) <= 1
    if length(inputs) == 0
        Context(1,
                context.max_length - 1,
                if context.constraint == IsWord || context.constraint == IsPrefix
                    IsPrefix
                else
                    nothing
                end)
    else
        len = num_letters(output(first(inputs)))
        Context(max(1, context.min_length - len),
                context.max_length - len,
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
propagate(context::Context, ::Wordplay, ::Tuple{AnagramIndicator, Phrase}, inputs) = propagate_to_argument(context, 2, inputs, nothing)
@apply_by_reversing Wordplay Phrase AnagramIndicator
propagate(context::Context, ::Wordplay, ::Tuple{Phrase, AnagramIndicator}, inputs) = propagate_to_argument(context, 1, inputs, nothing)

function propagate_to_argument(context, index, inputs, constraint=context.constraint)
    if length(inputs) + 1 == index
        Context(context.min_length, context.max_length, constraint)
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
propagate(context::Context, ::Wordplay, ::Tuple{ReverseIndicator, Phrase}, inputs) = propagate_to_argument(context, 2, inputs, nothing)
@apply_by_reversing Wordplay Phrase ReverseIndicator
propagate(context::Context, ::Wordplay, ::Tuple{Phrase, ReverseIndicator}, inputs) = propagate_to_argument(context, 1, inputs, nothing)

apply(::Wordplay, ::Tuple{HeadIndicator, Token}, (indicator, word)) = [string(word[1])]
propagate(context::Context, ::Wordplay, ::Tuple{HeadIndicator, Token}, inputs) =
    length(inputs) == 1 ? Context(2, context.max_length, nothing) : unconstrained_context()

@apply_by_reversing Wordplay Token HeadIndicator
propagate(context::Context, ::Wordplay, ::Tuple{Token, HeadIndicator}, inputs) =
    length(inputs) == 0 ? Context(2, context.max_length, nothing) : unconstrained_context()

function apply(::Synonym, ::Tuple{Phrase}, (word,))
    if word in keys(SYNONYMS)
        collect(SYNONYMS[word])
    else
        String[]
    end
end
propagate(context::Context, ::Synonym, ::Tuple{Phrase}, inputs) = unconstrained_context()


"""
All insertions of a into b
"""
function insertions(a, b)
    map(1:(length(b) - 1)) do breakpoint
        string(b[1:breakpoint], a, b[(breakpoint+1):end])
    end
end

function propagate_to_insertion(context::Context, arg1::Integer, arg2::Integer, inputs)
    if length(inputs) + 1 == arg1
        Context(1,
                context.max_length - 1,
                nothing)
    elseif length(inputs) + 1 == arg2
        len = num_letters(output(inputs[arg1]))
        Context(max(1, context.min_length - len),
                context.max_length - len,
                nothing)
    else
        unconstrained_context()
    end
end

apply(::Wordplay, ::Tuple{InsertABIndicator, Wordplay, Wordplay}, (indicator, a, b)) = insertions(a, b)
propagate(c::Context, ::Wordplay, ::Tuple{InsertABIndicator, Wordplay, Wordplay}, inputs) =
    propagate_to_insertion(c, 2, 3, inputs)

apply(::Wordplay, ::Tuple{Wordplay, InsertABIndicator, Wordplay}, (a, indicator, b)) = insertions(a, b)
propagate(c::Context, ::Wordplay, ::Tuple{Wordplay, InsertABIndicator, Wordplay}, inputs) =
    propagate_to_insertion(c, 1, 3, inputs)

apply(::Wordplay, ::Tuple{Wordplay, Wordplay, InsertABIndicator}, (a, b, indicator)) = insertions(a, b)
propagate(c::Context, ::Wordplay, ::Tuple{Wordplay, Wordplay, InsertABIndicator}, inputs) =
    propagate_to_insertion(c, 1, 2, inputs)

apply(::Wordplay, ::Tuple{InsertBAIndicator, Wordplay, Wordplay}, (indicator, b, a)) = insertions(a, b)
propagate(c::Context, ::Wordplay, ::Tuple{InsertBAIndicator, Wordplay, Wordplay}, inputs) =
    propagate_to_insertion(c, 2, 3, inputs)

apply(::Wordplay, ::Tuple{Wordplay, InsertBAIndicator, Wordplay}, (b, indicator, a)) = insertions(a, b)
propagate(c::Context, ::Wordplay, ::Tuple{Wordplay, InsertBAIndicator, Wordplay}, inputs) =
    propagate_to_insertion(c, 1, 3, inputs)

apply(::Wordplay, ::Tuple{Wordplay, Wordplay, InsertBAIndicator}, (b, a, indicator)) = insertions(a, b)
propagate(c::Context, ::Wordplay, ::Tuple{Wordplay, Wordplay, InsertBAIndicator}, inputs) =
    propagate_to_insertion(c, 1, 2, inputs)

apply(::Wordplay, ::Tuple{StraddleIndicator, Token, Token}, (indicator, w1, w2)) = straddling_words(w1, w2)
function propagate(context::Context, ::Wordplay, ::Tuple{StraddleIndicator, Token, Token}, inputs)
    if length(inputs) == 1
        Context(2,
                typemax(Int),
                nothing)
    elseif length(inputs) == 2
        Context(max(2, context.min_length - num_letters(output(inputs[2])) + 2),
                typemax(Int),
                nothing)
    else
        unconstrained_context()
    end
end
apply(::Wordplay, ::Tuple{Token, Token, StraddleIndicator}, (w1, w2, indicator)) = straddling_words(w1, w2)
function propagate(context::Context, ::Wordplay, ::Tuple{Token, Token, StraddleIndicator}, inputs)
    if length(inputs) == 0
        Context(2,
                typemax(Int),
                nothing)
    elseif length(inputs) == 1
        Context(max(2, context.min_length - num_letters(output(inputs[1])) + 2),
                typemax(Int),
                nothing)
    else
        unconstrained_context()
    end
end