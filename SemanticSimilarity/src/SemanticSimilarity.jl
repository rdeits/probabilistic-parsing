module SemanticSimilarity

using WordNet
using ProgressMeter

const db = Ref{WordNet.DB}()

const synsets = Dict{String, Vector{SynsetVertex}}()

function wu_palmer_similarity(w1::AbstractString, w2::AbstractString)
    if !(w1 in keys(synsets)) || !(w2 in keys(synsets))
        0.0
    else
        maximum(wu_palmer_similarity(db[], s1, s2) for s1 in synsets[w1], s2 in synsets[w2])::Float64
    end
end

function wu_palmer_similarity(db::DB, v1::SynsetVertex, v2::SynsetVertex)
    ancestor_depth = common_ancestor_depth(db, v1, v2)
    2 * ancestor_depth / (v1.depth + v2.depth)
end

function common_ancestor_depth(db::DB, v1::SynsetVertex, v2::SynsetVertex)
    s1 = v1.synset
    d1 = v1.depth
    s2 = v2.synset
    d2 = v2.depth
    while true
        if (d1 == 1 || d2 == 1) || (d1 == d2 && s1 == s2)
            return d1
        end
        if d1 >= d2
            s1 = hypernyms(db, s1)
            d1 -= 1
        end
        if d2 > d1
            s2 = hypernyms(db, s2)
            d2 -= 1
        end
    end
end

function depth(db::DB, synset::Synset)
    depth = 1
    while synset != WordNet.∅
        synset = hypernyms(db, synset)
        depth += 1
        if depth > 100
            # @info "Possible cycle detected involving synset: $synset"
            return nothing
        end
    end
    depth
end

function cache_synsets!()
    empty!(synsets)
    for (pos, part_of_speech_synsets) in db[].synsets
        for synset in values(part_of_speech_synsets)
            d = depth(db[], synset)
            if d !== nothing
                for word in words(synset)
                    v = get!(Vector{SynsetVertex}, synsets, word)
                    push!(v, SynsetVertex(synset, d))
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
