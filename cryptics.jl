using Pkg
pkg"activate ."

using Cryptics

# clue = "initially babies are naked"
# rules = Cryptics.cryptics_rules()
# grammar = Cryptics.Grammar(rules)
# tokens = split(clue)
# chart = Cryptics.parse(tokens, grammar, Cryptics.TopDown());

# println("======================================")

# for p in Cryptics.complete_parses(chart)
#     println(p)
# end

# println("--------------------------------------")

# for p in Cryptics.solutions(chart)
#     println(p)
# end

using ProfileView
using Profile
Profile.clear()
@profile Cryptics.solve("spin broken shingle")
@time Cryptics.solve("spin broken shingle")
Profile.clear()
@profile Cryptics.solve("spin broken shingle")
ProfileView.view()
