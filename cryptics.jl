using Pkg
pkg"activate ."

using Cryptics

# clue = "initially babies are naked"
# rules = Cryptics.cryptics_rules()
# grammar = Cryptics.Grammar(rules)
# tokens = split(clue)
# chart = Cryptics.parse(tokens, grammar, Cryptics.TopDown());

# clue = "male done mixing drink"
clue = "absmoo thief straddle drink"
rules = Cryptics.cryptics_rules()
grammar = Cryptics.Grammar(rules)
tokens = split(clue)
context = Cryptics.Context(8, 8, Cryptics.IsWord)
chart = Cryptics.parse(tokens, grammar, context, Cryptics.TopDown());

@show length(Cryptics.complete_parses(chart))

println("======================================")

for p in Cryptics.complete_parses(chart)
    println(p)
end

println("--------------------------------------")

for p in Cryptics.solutions(chart)
    println(p)
end

using ProfileView
using Profile
Profile.clear()
# clue = "initially babies are naked"
# clue = "spin broken shingle"
# clue = "healthy competent boy nearly died"
@profile Cryptics.solve(clue, context, Cryptics.TopDown())
@time solutions = Cryptics.solve(clue, context, Cryptics.TopDown())
@show first(solutions)
Profile.clear()
@profile Cryptics.solve(clue, context, Cryptics.TopDown())
ProfileView.view()

