using DataFrames
using Serialization
using Statistics

function trial()
    nsir, ndam, noff, ng, nrpt = 25, 50, 100, 25, 40
    Ne = 2 / mean(x -> 1/x, [nsir, ndam])
    ΔF = 1 / 2Ne
    eF = 1 .- (1 - ΔF) .^ (0:ng-1)
    df = DataFrame(Fe = repeat(eF, outer = nrpt))
    Fr, F1d, F2d, F4d, Fb = Float64[], Float64[], Float64[], Float64[], Float64[]
    for irpt in 1:nrpt
        println("==========> Repeat: $irpt / $nrpt <==========")
        append!(Fr, random_mate(nsir, ndam, ng))
        append!(F1d, hierarchical_mate(nsir, ndam, noff, ng))
        append!(F2d, hierarchical_mate(nsir, ndam, 2noff, ng))
        append!(F4d, hierarchical_mate(nsir, ndam, 4noff, ng))
        append!(Fb, balanced_mate(nsir, ndam, ng))
    end
    df.Fr, df.F1d, df.F2d, df.F4d, df.Fb = Fr, F1d, F2d, F4d, Fb
    serialize("deltaF.ser", df)
end
