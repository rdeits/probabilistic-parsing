module Cryptics

using Base.Iterators: product, drop
using Combinatorics: permutations
# using OrderedCollections: OrderedSet

export Chart, parse, Grammar, expand, complete_parses

include("Synonyms.jl")
using .Synonyms

include("words.jl")
include("grammar.jl")
include("parsing.jl")
include("solver.jl")

end # module
