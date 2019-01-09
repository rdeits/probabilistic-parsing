
function solve(clue::AbstractString, context::Context, strategy=TopDown())
    rules = Cryptics.cryptics_rules()
    grammar = Cryptics.Grammar(rules)
    tokens = split(clue)
    chart = Cryptics.parse(tokens, grammar, context, strategy);

    sort(collect(complete_parses(chart)), by=solution_quality, rev=true)
end
