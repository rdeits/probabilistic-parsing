is_word(x::AbstractString) = x in keys(SYNONYMS)

function straddling_words(w1, w2)
    results = String[]
    combined = w1 * w2
    for i in 2:length(w1)
        for j in length(w1) .+ (1:(length(w2) - 1))
            candidate = combined[i:j]
            if is_word(candidate)
                push!(results, candidate)
            end
        end
    end
    results
end

function is_anagram(w1::AbstractString, w2::AbstractString)
    sort(collect(replace(w1, " " => ""))) == sort(collect(replace(w2, " " => "")))
end

const WORDS = Set{String}(collect(keys(SYNONYMS)))

const WORDS_BY_ANAGRAM = Dict{String, Vector{String}}()

for word in WORDS
    key = join(sort(collect(word)))
    v = get!(Vector{String}, WORDS_BY_ANAGRAM, key)
    push!(v, word)
end


