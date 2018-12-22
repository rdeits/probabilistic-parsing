module Cryptics

using Base.Iterators: product, drop
using Combinatorics: permutations

export Chart, parse, Grammar, expand, complete_parses

include("Synonyms.jl")
using .Synonyms

include("grammar.jl")
include("parsing.jl")

end # module
