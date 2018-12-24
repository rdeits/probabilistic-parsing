using Pkg
pkg"activate ."

using Cryptics

clue = "spin broken shingle"
rules = Cryptics.cryptics_rules()
grammar = Cryptics.Grammar(rules)
tokens = split(clue)
chart = Cryptics.parse(tokens, grammar, Cryptics.TopDown());

println("======================================")

for p in Cryptics.complete_parses(chart)
    println(p)
end
