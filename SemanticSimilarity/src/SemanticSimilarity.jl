module SemanticSimilarity

using WordNet
using ProgressMeter

const db = Ref{WordNet.DB}()
const Path = Vector{Synset}
const paths = Dict{String, Vector{Path}}()

function wu_palmer_similarity(w1::AbstractString, w2::AbstractString)
    if !(w1 in keys(paths)) || !(w2 in keys(paths))
        0.0
    else
        s = 0.0
        for p1 in paths[w1]
            for p2 in paths[w2]
                s = max(s, wu_palmer_similarity(p1, p2))
            end
        end
        s
    end
end

function wu_palmer_similarity(p1::Path, p2::Path)
    2 * common_ancestor_depth(p1, p2) / (length(p1) + length(p2))
end

function common_ancestor_depth(p1::Path, p2::Path)
    max_depth = min(length(p1), length(p2))
    for i in 1:max_depth
        if p1[i] != p2[i]
            return i - 1
        end
    end
    return max_depth
end

function path_to_synset(db::DB, synset::Synset)
    result = [synset]
    while synset != WordNet.∅
        synset = hypernyms(db, synset)
        push!(result, synset)
        if length(result) > 50
            return nothing
        end
    end
    reverse!(result)
    result
end

function cache_synsets!()
    empty!(paths)
    for (pos, part_of_speech_synsets) in db[].synsets
        for synset in values(part_of_speech_synsets)
            path = path_to_synset(db[], synset)
            if path !== nothing
                for word in words(synset)
                    v = get!(Vector{Path}, paths, word)
                    push!(v, path)
                end
            end
        end
    end
end

function __init__()
    db[] = DB()
    # cache_synsets!()
end

end # module
