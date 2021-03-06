# Stable Dictionary
# =================

mutable struct StableDict{K,V} <: Associative{K,V}
    slots::Vector{Int}
    keys::Vector{K}
    vals::Vector{V}
    used::Int
    nextidx::Int

    function (::Type{StableDict{K,V}}){K,V}()
        size = 16
        slots = zeros(Int, size)
        keys = Vector{K}(size)
        vals = Vector{V}(size)
        return new{K,V}(slots, keys, vals, 0, 1)
    end

    function (::Type{StableDict}){K,V}(dict::StableDict{K,V})
        copy = StableDict{K,V}()
        for (k, v) in dict
            copy[k] = v
        end
        return copy
    end
end

function StableDict{K,V}(kvs::Pair{K,V}...)
    dict = StableDict{K,V}()
    for (k, v) in kvs
        dict[k] = v
    end
    return dict
end

function (::Type{StableDict{K,V}}){K,V}(kvs)
    dict = StableDict{K,V}()
    for (k, v) in kvs
        dict[k] = v
    end
    return dict
end

function StableDict(kvs)
    return StableDict([Pair(k, v) for (k, v) in kvs]...)
end

function StableDict()
    return StableDict{Any,Any}()
end

function Base.convert{K,V}(::Type{StableDict{K,V}}, dict::Associative)
    newdict = StableDict{K,V}()
    for (k, v) in dict
        newdict[k] = v
    end
    return newdict
end

function Base.copy(dict::StableDict)
    return StableDict(dict)
end

function Base.length(dict::StableDict)
    return dict.used
end

function Base.haskey(dict::StableDict, key)
    _, j = indexes(dict, convert(keytype(dict), key))
    return j > 0
end

function Base.getindex(dict::StableDict, key)
    _, j = indexes(dict, convert(keytype(dict), key))
    if j == 0
        throw(KeyError(key))
    end
    return dict.vals[j]
end

function Base.get!(dict::StableDict, key, default)
    if haskey(dict, key)
        return dict[key]
    end
    val = convert(valtype(dict), default)
    dict[key] = val
    return val
end

function Base.get!(f::Function, dict::StableDict, key)
    if haskey(dict, key)
        return dict[key]
    end
    val = convert(valtype(dict), f())
    dict[key] = val
    return val
end

function Base.setindex!(dict::StableDict, val, key)
    k = convert(keytype(dict), key)
    v = convert(valtype(dict), val)
    @label index
    i, j = indexes(dict, k)
    if j == 0
        if dict.nextidx > endof(dict.keys)
            expand!(dict)
            @goto index
        end
        dict.keys[dict.nextidx] = k
        dict.vals[dict.nextidx] = v
        dict.slots[i] = dict.nextidx
        dict.used += 1
        dict.nextidx += 1
    else
        dict.slots[i] = j
        dict.keys[j] = k
        dict.vals[j] = v
    end
    return dict
end

function Base.delete!(dict::StableDict, key)
    k = convert(keytype(dict), key)
    i, j = indexes(dict, k)
    if j > 0
        dict.slots[i] = -j
        dict.used -= 1
    end
    return dict
end

function Base.pop!(dict::StableDict)
    if isempty(dict)
        throw(ArgumentError("empty"))
    end
    i = dict.slots[indmax(dict.slots)]
    key = dict.keys[i]
    val = dict.vals[i]
    delete!(dict, key)
    return key => val
end

function Base.start(dict::StableDict)
    if dict.used == dict.nextidx - 1
        keys = dict.keys[1:dict.used]
        vals = dict.vals[1:dict.used]
    else
        idx = sort!(dict.slots[dict.slots .> 0])
        @assert length(idx) == length(dict)
        keys = dict.keys[idx]
        vals = dict.vals[idx]
    end
    return 1, keys, vals
end

function Base.done(dict::StableDict, st)
    return st[1] > length(st[2])
end

function Base.next(dict::StableDict, st)
    i = st[1]
    return (st[2][i] => st[3][i]), (i + 1, st[2], st[3])
end

function hashindex(key, sz)
    return (reinterpret(Int, hash(key)) & (sz-1)) + 1
end

function indexes(dict, key)
    sz = length(dict.slots)
    h = hashindex(key, sz)
    i = 0
    while i < sz
        j = mod1(h + i, sz)
        k = dict.slots[j]
        if k == 0
            return j, k
        elseif k > 0 && isequal(dict.keys[k], key)
            return j, k
        end
        i += 1
    end
    return 0, 0
end

function expand!(dict)
    sz = length(dict.slots)
    newsz = sz * 2
    newslots = zeros(Int, newsz)
    resize!(dict.keys, newsz)
    resize!(dict.vals, newsz)
    for i in 1:sz
        j = dict.slots[i]
        if j > 0
            k = hashindex(dict.keys[j], newsz)
            while newslots[mod1(k, newsz)] != 0
                k += 1
            end
            newslots[mod1(k, newsz)] = j
        end
    end
    dict.slots = newslots
    return dict
end
