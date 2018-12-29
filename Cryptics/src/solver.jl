
function solve(clue::AbstractString, strategy=TopDown())
    rules = Cryptics.cryptics_rules()
    grammar = Cryptics.Grammar(rules)
    tokens = split(clue)
    chart = Cryptics.parse(tokens, grammar, strategy);

    sort(collect(complete_parses(chart)), by=solution_quality, rev=true)
end
