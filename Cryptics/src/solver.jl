
function solve(clue::AbstractString)
    rules = Cryptics.cryptics_rules()
    grammar = Cryptics.Grammar(rules)
    tokens = split(clue)
    chart = Cryptics.parse(tokens, grammar, Cryptics.TopDown());

    sort(collect(complete_parses(chart)), by=solution_quality, rev=true)
end
