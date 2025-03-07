# Plots for paper I

using DataFrames
using EasyFit
using LaTeXStrings
using Mmap
using Plots.PlotMeasures
using Plots
using Serialization
using Statistics

"""
    mrgRst(clr)
Merge the two batches of one chromosome results into one dictionary.
"""
function mrgRst(clr)
    isdir("c01/1") || mkpath("c01/1")
    isdir("c01/4") || mkpath("c01/4")
    ks = collect(keys(clr))
    append!(ks, ["founder", "rand"])
    for r in (1, 4)
        rst = begin
            t1 = deserialize("c01-1/$r/summary.ser")
            t2 = deserialize("c01-2/$r/summary.ser")
            t2.repeat .+= 50
            append!(t1, t2)
            t1
        end
        serialize("c01/$r/summary.ser", rst)
        for i = 1:50
            t1 = lpad(i, 2, '0')
            t2 = lpad(i + 50, 3, '0')
            for k in ks
                for ext in ("xy", "ped")
                    mv("c01-1/$r/$t1-$k.$ext", "c01/$r/0$t1-$k.$ext", force = true)
                    mv("c01-2/$r/$t1-$k.$ext", "c01/$r/$t2-$k.$ext", force = true)
                end
            end
            mv("c01-1/$r/$t1-snp.xy", "c01/$r/0$t1-snp.xy", force = true)
            mv("c01-2/$r/$t1-snp.xy", "c01/$r/$t2-snp.xy", force = true)
            mv("c01-1/$r/$t1-founder.lmp", "c01/$r/0$t1-founder.lmp", force = true)
            mv("c01-2/$r/$t1-founder.lmp", "c01/$r/$t2-founder.lmp", force = true)
        end
        mv("c01-1/$r/BosTau.lmp", "c01/$r/BosTau-1.lmp", force = true)
        mv("c01-2/$r/BosTau.lmp", "c01/$r/BosTau-2.lmp", force = true)
        mv("c01-1/$r/BosTau.xy", "c01/$r/BosTau-1.xy", force = true)
        mv("c01-2/$r/BosTau.xy", "c01/$r/BosTau-2.xy", force = true)
        mv("c01-1/$r/desc.txt", "c01/$r/desc.txt", force = true)
    end
end

function readSup(dir)
    r1 = deserialize(joinpath(dir, "1/summary.ser"))
    r2 = deserialize(joinpath(dir, "4/summary.ser"))

    mpg, vpg = [], []
    for r in (r1, r2)
        r.nprt = r.nsire + r.ndam
        r.logh = log.(1 .- r.iF) * -1
        mps = Dict{String,DataFrame}()
        vps = Dict{String,DataFrame}()
        nrpt = r.repeat[end]
        for grp in groupby(r, :scheme)
            scheme = grp.scheme[1]
            mps[scheme] = combine(
                groupby(grp, :grt),
                Not(:repeat, :scheme) .=> mean .=> Not(:repeat, :scheme),
            )
            tdf = combine(
                groupby(grp, :grt),
                Not(:repeat, :scheme, :grt, :nid) .=>
                    std .=> Not(:repeat, :scheme, :grt, :nid),
            )
            vps[grp.scheme[1]] = select(tdf, Not(:grt)) ./ sqrt(nrpt)
        end
        push!(mpg, mps)
        push!(vpg, vps)
    end

    mpg, vpg # mean and mean standard deviation
end

function readGB(dir)
    c01 = deserialize("$dir/c01/summary.ser")
    c29 = deserialize("$dir/c29/summary.ser")
    m01 = combine(
        groupby(c01, :grt),
        Not(:repeat, :scheme) .=> mean .=> Not(:repeat, :scheme),
    )
    m29 = combine(
        groupby(c29, :grt),
        Not(:repeat, :scheme) .=> mean .=> Not(:repeat, :scheme),
    )
    v01 = combine(
        groupby(c01, :grt),
        Not(:repeat, :scheme, :grt, :nid) .=> std .=> Not(:repeat, :scheme, :grt, :nid),
    ) ./ sqrt(c01.repeat[end])
    v29 = combine(
        groupby(c29, :grt),
        Not(:repeat, :scheme, :grt, :nid) .=> std .=> Not(:repeat, :scheme, :grt, :nid),
    ) ./ sqrt(c29.repeat[end])
    m01, m29, v01, v29
end

"""
    line_clr(dat)
Assign a fixed color to each line in `dat`. The colors are for all the figures.
"""
function line_clr(dat)
    cs = Dict{String,Int}()
    for (i, k) in enumerate(keys(dat))
        cs[k] = i
    end
    cs
end

"""
    xtrm(dat, col)
Get the extrema of the column `col` in all the DataFrames in `dat`. Also add a
2% margin to the extrema.
"""
function xtrm(dat, col)
    x, n = Float64[], length(dat)
    for i = 1:n
        for s in keys(dat[i])
            df = dat[i][s]
            append!(x, extrema(df[!, col]))
        end
    end
    extrema(x)
end

function xtrm(dat, col, rg)
    x, n = Float64[], length(dat)
    for i = 1:n
        for s in keys(dat[i])
            df = dat[i][s]
            append!(x, extrema(df[rg, col]))
        end
    end
    extrema(x)
end

"""
    ord_last(data, col)
Order the legends of the last plot in `data` by the last value of `col` in
reverse order.
"""
function ord_last(data, col)
    ks = collect(keys(data))
    dt = zeros(length(ks))
    for (i, k) in enumerate(ks)
        df = data[k]
        dt[i] = df[!, col][end]
    end
    ks = ks[sortperm(dt, rev = true)]
end

function fig_covdq(mpg, vpg, clr; c = 1)
    ylm = begin
        t = xtrm(mpg, :covdq2)
        d = t[2] - t[1]
        (t[1] - 0.02d, t[2] + 0.05d)
    end
    ax, ay = -5, ylm[2] - 0.02(ylm[2] - ylm[1])
    A, B, ch = c == 1 ? ("A: ", "B: ", L"C_1") : ("C: ", "D: ", L"C_{29}")
    fs, n = [], length(mpg)
    for i = 1:n
        fig = plot(dpi = 300, ylim = ylm, size = (600, 400))
        ks = ord_last(mpg[i], :covdq2)
        for s in ks
            df = mpg[i][s]
            plot!(
                fig,
                df.grt .- 5,
                df.covdq2,
                fillalpha = 0.2,
                ribbon = vpg[i][s].covdq2,
                label = uppercase(s[1:2]),
                foreground_color_legend = nothing,
                background_color_legend = nothing,
                color = clr[s],
            )
        end
        push!(fs, fig)
    end
    annotate!(fs[1], ax, ay, text(A * ch * L"F_{0.5\%}", 8, :left))
    annotate!(fs[2], ax, ay, text(B * ch * L"F_{1\%}", 8, :left))
    fs
end

"""
    fig_mtbv(mpg, vpg, clr; c = 1)
Plot the mean total breeding value of each generation of each scheme in `mpg`.
The shaded areas are the standard errors.
Each scheme is plotted in a fixed color defined in `clr`.
"""
function fig_mtbv(mpg, vpg, clr; c = 1)
    ylm = begin
        t = xtrm(mpg, :mtbv)
        d = 0.01(t[2] - t[1])
        (t[1] - d, t[2] + d)
    end
    fs, n = [], length(mpg)
    ch = c == 1 ? L"C_{1}" : L"C_{29}"
    A, B = c == 1 ? ('A', 'B') : ('C', 'D')
    for i = 1:n
        fig = plot(dpi = 300, ylim = ylm)
        ks = ord_last(mpg[i], :mtbv)
        for s in ks
            df = mpg[i][s]
            plot!(
                fig,
                df.grt .- 5,
                df.mtbv,
                fillalpha = 0.2,
                ribbon = vpg[i][s].mtbv,
                label = uppercase(s[1:2]),
                legend = :bottomright,
                foreground_color_legend = nothing,
                background_color_legend = nothing,
                color = clr[s],
            )
        end
        push!(fs, fig)
    end
    p = ylm[2]
    annotate!(fs[1], -1.5, p, text("$A: " * ch * L"F_{0.5\%}", 8, :top))
    annotate!(fs[2], -1.5, p, text("$B: " * ch * L"F_{1\%}", 8, :top))
    fs
end

"""
    fig_nprt(mpg, vpg, clr; p = 0, c = 1)
Plot the number of parents of each generation of each scheme in `mpg`. The
shaded areas are the standard errors. Each scheme is plotted in a fixed color
defined in `clr`. The solid lines are the number of sires and the dashed lines
are the number of dams. Legends are in two columns. They read column by column.
"""
function fig_nprt(mpg, vpg, clr; c = 1)
    fs, n, rg = [], length(mpg), 7:36
    ylm = xtrm(mpg, :nprt, rg)
    A, B, ch = c == 1 ? ("A: ", "B: ", L"C_1") : ("C: ", "D: ", L"C_{29}")
    for i = 1:n
        fig = plot(dpi = 300, ylim = ylm, legend = :outerbottomright)
        ks = ord_last(mpg[i], :nprt)
        for s in ks
            df = mpg[i][s]
            vf = vpg[i][s]
            plot!(
                fig,
                df.grt[rg] .- 5,
                df.nprt[rg],
                fillalpha = 0.2,
                ribbon = vf.nprt[rg],
                label = uppercase(s[1:2]),
                foreground_color_legend = nothing,
                background_color_legend = nothing,
                color = clr[s],
                )
        end
        push!(fs, fig)
    end
    plot!(fs[1], title = A * ch * L"F_{0.5\%}", titleloc = :left, titlefontsize = 8)
    plot!(fs[2], title = B * ch * L"F_{1\%}", titleloc = :left, titlefontsize = 8)
    c ==2 && xlabel!(fs[2], "Generation")
    fs
end

"""
    fig_vg(mpg, vpg, clr)
Plot the genic and genetic variance of each generation of each scheme in `mpg`.
The genic variances were shaded with their mean standard deviation. Each scheme
is plotted in a fixed color defined in `clr`. The solid lines are the genic var
and the dashed lines are genetic variances. Legends are in the bottom left
corner.
"""
function fig_vg(mpg, vpg, clr; c = 1)
    ylm = begin
        t = collect(xtrm(mpg, :vtbv))
        append!(t, xtrm(mpg, :genicv))
        x = extrema(t)
        d = 0.01(x[2] - x[1])
        (x[1] - d, x[2] + 10d)
    end
    fs, n = [], length(mpg)
    A, B, ch = c == 1 ? ('A', 'B', L"C_1") : ('C', 'D', L"C_{29}")
    for i = 1:n
        fig = plot(dpi = 300, ylim = ylm)
        ks = ord_last(mpg[i], :genicv)
        for s in ks
            df = mpg[i][s]
            plot!(
                fig,
                df.grt .- 5,
                df.genicv,
                fillalpha = 0.1,
                ribbon = vpg[i][s].genicv,
                label = uppercase(s[1:2]),
                color = clr[s],
            )
            plot!(
                fig,
                df.grt .- 5,
                df.vtbv,
                linestyle = :dash,
                label = false,
                foreground_color_legend = nothing,
                background_color_legend = nothing,
                legend = :outerbottomright,
                color = clr[s],
            )
        end
        push!(fs, fig)
    end
    p = ylm[2]
    annotate!(fs[1], 0, p, text("$A: " * ch * L"F_{0.5\%}", 9, :top))
    annotate!(fs[2], 0, p, text("$B: " * ch * L"F_{1\%}", 9, :top))
    fs
end

function fig_ceiling(mpg, vpg, clr; c = 1)
    ylm = begin
        t = xtrm(mpg, :ceiling)
        d = 0.01(t[2] - t[1])
        (t[1] - d, t[2] + 7d)
    end
    fs, n = [], length(mpg)
    ch = c == 1 ? L"C_1" : L"C_{29}"
    for i = 1:n
        fig = plot(
            dpi = 300,
            ylim = ylm,
            legendfontsize = 6,
            legend = :right,
            foreground_color_legend = nothing,
            background_color_legend = nothing,
        )
        ks = ord_last(mpg[i], :ceiling)
        for s in ks
            df = mpg[i][s]
            plot!(
                fig,
                df.grt .- 5,
                df.ceiling,
                fillalpha = 0.2,
                ribbon = vpg[i][s].ceiling,
                label = uppercase(s[1:2]),
                color = clr[s],
            )
        end
        push!(fs, fig)
    end
    p = ylm[2]
    annotate!(fs[1], -2, p, text("A: " * ch * L"F_{0.5\%}", 8, :top))
    annotate!(fs[2], -2, p, text("B: " * ch * L"F_{1\%}", 8, :top))
    fs
end

"""
    fig_space(mpg, vpg, clr; p = -10, c = 1)
Plot the space limited by breeding ceiling and floor of each generation of each
scheme in `mpg`. The shaded areas are the mean standard deviations. Each scheme
is plotted in a fixed color defined in `clr`. The solid lines are the breeding
ceiling and the dashed lines are breeding floor. Legends are in the bottom left
corner.
"""
function fig_space(mpg, vpg, clr; p = -10, c = 1)
    ylm = begin
        t = collect(xtrm(mpg, :ceiling))
        append!(t, xtrm(mpg, :floor))
        extrema(t)
    end
    fs, n = [], length(mpg)
    ch = c == 1 ? L"C_{1}" : L"C_{29}"
    for i = 1:n
        fig = plot(
            dpi = 300,
            ylim = ylm,
            size = (600, 400),
            legendfontsize = 6,
            foreground_color_legend = nothing,
            background_color_legend = nothing,
        )
        ks = ord_last(mpg[i], :ceiling)
        for s in ks
            df = mpg[i][s]
            plot!(
                fig,
                df.grt .- 5,
                df.ceiling,
                fillalpha = 0.2,
                ribbon = vpg[i][s].ceiling,
                label = uppercase(s[1:2]),
                legend = :left,
                color = clr[s],
            )
        end
        ks = ord_last(mpg[i], :floor)
        for s in ks
            df = mpg[i][s]
            plot!(
                fig,
                df.grt .- 5,
                df.floor,
                linestyle = :dash,
                fillalpha = 0.2,
                ribbon = vpg[i][s].floor,
                label = uppercase(s[1:2]),
                color = clr[s],
            )
        end
        push!(fs, fig)
    end
    annotate!(
        fs[1],
        p,
        ylm[2] * 0.45, #-8 for 3:4
        text("Brd. val.", 10, :left, rotation = 90),
    )
    pp = ylm[2] * 0.9
    annotate!(fs[1], 5, pp, text("A: " * ch * L"F_{0.5\%}", 5))
    annotate!(fs[1], 20, ylm[1] * 0.52, text("Floor", 10, :top))
    annotate!(fs[1], 20, ylm[2] * 0.52, text("Ceiling", 10, :bottom))
    annotate!(fs[2], 25, ylm[1], text("Generation", 10, :bottom))
    annotate!(fs[2], 5, pp, text("B: " * ch * L"F_{1\%}", 5))
    fs
end

"""
    fig_inbreeding(mpg, vpg, clr; c = 1)
Inbreeding:
    - IBD: Identity by descent
    - Pedigree: Pedigree based inbreeding
    - Het.: Heterozygosity
    - Drift: Genetic drift
Plot the inbreeding of each generation of each scheme in `mpg`. The shaded
areas are the mean standard deviations. Each scheme is plotted in a fixed color
defined in `clr`. Legends are in the top left corner.
"""
function fig_inbreeding(mpg, vpg, clr; c = 1)
    ylm = begin
        t = xtrm(mpg, :iF)
        d = 0.01(t[2] - t[1])
        (t[1] - d, t[2] + 5d)
    end
    fs, n = [], length(mpg)
    ch = c == 1 ? L"C_1" : L"C_{29}"
    for i = 1:n
        fig = plot(
            dpi = 300,
            ylim = ylm,
            size = (600, 400),
            foreground_color_legend = nothing,
            background_color_legend = nothing,
            legend = :outerright,
            legendfontsize = 6,
        )
        ks = ord_last(mpg[i], :iF)
        for s in ks
            df = mpg[i][s]
            plot!(
                fig,
                df.grt .- 5,
                df.iF,
                fillalpha = 0.2,
                ribbon = vpg[i][s].iF,
                label = uppercase(s[1:2]),
                color = clr[s],
            )
        end
        #i == 2 && annotate!(fig, 15, ylm[2], text("IBD", 10))
        push!(fs, fig)
        continue
    end
    #=
    p = ylm[2] * 0.85
    CS = 'A':'Z'
    for i = 1:6
        j = i + 12 * (c - 1)
        annotate!(fs[i], 15, p, text(CS[j] * ": " * ch * L"F_{0.5\%}", 5))
    end
    for i = 7:12
        j = i + 12 * (c - 1)
        annotate!(fs[i], 15, p, text(CS[j] * ": " * ch * L"F_{1\%}", 5))
    end
    =#
    A, B = c == 1 ? ('A', 'B') : ('C', 'D')
    annotate!(fs[1], 0, ylm[2], text("$A: " * ch * L"F_{0.5\%}", 9, :top))
    annotate!(fs[2], 0, ylm[2], text("$B: " * ch * L"F_{1\%}", 9, :top))
    fs
end

function fig_inbrd2(mpg, vpg, clr; c = 1)
    ylm = begin
        t = collect(xtrm(mpg, :fped))
        append!(t, xtrm(mpg, :fhet2))
        append!(t, xtrm(mpg, :fdrift2))
        append!(t, xtrm(mpg, :fhet3))
        append!(t, xtrm(mpg, :fdrift3))
        t = extrema(t)
        d = 0.01(t[2] - t[1])
        (t[1] - d, t[2] + 5d)
    end
    fs, n = [], length(mpg)
    ch = c == 1 ? L"C_1" : L"C_{29}"
    for i = 1:2
        fig = plot(
            dpi = 300,
            ylim = ylm,
            size = (600, 400),
            foreground_color_legend = nothing,
            background_color_legend = nothing,
        )
        ks = ord_last(mpg[i], :fped)
        for s in ks
            df = mpg[i][s]
            plot!(
                fig,
                df.grt .- 5,
                df.fped,
                fillalpha = 0.2,
                ribbon = vpg[i][s].fped,
                label = uppercase(s[1:2]),
                legend = :topleft,
                legendfontsize = 6,
                color = clr[s],
            )
        end
        i == 2 && annotate!(fig, 15, ylm[2], text("Pedigree", 10))
        push!(fs, fig)

        fig = plot(
            dpi = 300,
            ylim = ylm,
            size = (600, 400),
            foreground_color_legend = nothing,
            background_color_legend = nothing,
        )
        ks = ord_last(mpg[i], :fdrift2)
        for s in ks
            df = mpg[i][s]
            plot!(
                fig,
                df.grt .- 5,
                df.fdrift2,
                fillalpha = 0.2,
                ribbon = vpg[i][s].fdrift2,
                label = uppercase(s[1:2]),
                legend = :topleft,
                legendfontsize = 6,
                color = clr[s],
            )
        end
        i == 2 && annotate!(fig, 15, ylm[2], text("Drift ref", 10))
        push!(fs, fig)

        fig = plot(
            dpi = 300,
            ylim = ylm,
            size = (600, 400),
            foreground_color_legend = nothing,
            background_color_legend = nothing,
        )
        ks = ord_last(mpg[i], :fdrift3)
        for s in ks
            df = mpg[i][s]
            plot!(
                fig,
                df.grt .- 5,
                df.fdrift3,
                fillalpha = 0.2,
                ribbon = vpg[i][s].fdrift3,
                label = uppercase(s[1:2]),
                legend = :topleft,
                legendfontsize = 6,
                color = clr[s],
            )
        end
        i == 2 && annotate!(fig, 15, ylm[2], text("Drift chip", 10))
        push!(fs, fig)

        fig = plot(
            dpi = 300,
            ylim = ylm,
            size = (600, 400),
            foreground_color_legend = nothing,
            background_color_legend = nothing,
        )
        ks = ord_last(mpg[i], :fhet2)
        for s in ks
            df = mpg[i][s]
            plot!(
                fig,
                df.grt .- 5,
                df.fhet2,
                fillalpha = 0.2,
                ribbon = vpg[i][s].fhet2,
                label = uppercase(s[1:2]),
                legend = :topleft,
                legendfontsize = 6,
                color = clr[s],
            )
        end
        i == 2 && annotate!(fig, 15, ylm[2], text("Het. ref", 10))
        push!(fs, fig)

        fig = plot(
            dpi = 300,
            ylim = ylm,
            size = (600, 400),
            foreground_color_legend = nothing,
            background_color_legend = nothing,
        )
        ks = ord_last(mpg[i], :fhet3)
        for s in ks
            df = mpg[i][s]
            plot!(
                fig,
                df.grt .- 5,
                df.fhet3,
                fillalpha = 0.2,
                ribbon = vpg[i][s].fhet3,
                label = uppercase(s[1:2]),
                legend = :topleft,
                legendfontsize = 6,
                color = clr[s],
            )
        end
        i == 2 && annotate!(fig, 15, ylm[2], text("Het. chip", 10))
        push!(fs, fig)
    end
    fs
end

"""
    fig_fxqtl(mpg, vpg, clr; c = 1)

Plot the number of fixed QTL of each generation of each scheme in `mpg`. The
shaded areas are the mean standard deviations. Each scheme is plotted in a fixed
color defined in `clr`. The solid lines are the number of favorite QTL and the
dashed lines are the number of unfavorite QTL. Legends are in the right side.
"""
function fig_fxqtl(mpg, vpg, clr; c = 1)
    ylm = begin
        t = collect(xtrm(mpg, :xfq))
        append!(t, xtrm(mpg, :xuq))
        extrema(t)
    end
    fs, n = [], length(mpg)
    ch = c == 1 ? L"C_{1}" : L"C_{29}"
    A, B, C, D = c == 1 ? ('A', 'B', 'C', 'D') : ('E', 'F', 'G', 'H')
    for i = 1:n
        fig = plot(
            dpi = 300,
            ylim = ylm,
            size = (600, 400),
            foreground_color_legend = nothing,
            background_color_legend = nothing,
            legendfontsize = 6,
            legend = :outertopright,
        )
        ks = ord_last(mpg[i], :xfq)
        for s in ks
            df = mpg[i][s]
            plot!(
                fig,
                df.grt .- 5,
                df.xfq,
                fillalpha = 0.2,
                ribbon = vpg[i][s].xfq,
                label = uppercase(s[1:2]),
                color = clr[s],
            )
        end
        annotate!(fig, 15, ylm[2] * 0.3, text("Favorite", 8))
        push!(fs, fig)
        fig = plot(
            dpi = 300,
            ylim = ylm,
            size = (600, 400),
            foreground_color_legend = nothing,
            background_color_legend = nothing,
            legendfontsize = 6,
            legend = :outertopright,
        )
        ks = ord_last(mpg[i], :xuq)
        for s in ks
            df = mpg[i][s]
            plot!(
                fig,
                df.grt .- 5,
                df.xuq,
                linestyle = :dash,
                fillalpha = 0.2,
                ribbon = vpg[i][s].xuq,
                label = uppercase(s[1:2]),
                color = clr[s],
            )
        end
        annotate!(fig, 15, ylm[2] * 0.3, text("Unfavorite", 8))
        push!(fs, fig)
    end
    p = ylm[2]
    annotate!(fs[1], 10, p, text("$A: " * ch * L"F_{0.5\%}", 9, :top))
    annotate!(fs[2], 10, p, text("$B: " * ch * L"F_{0.5\%}", 9, :top))
    annotate!(fs[3], 10, p, text("$C: " * ch * L"F_{1\%}", 9, :top))
    annotate!(fs[4], 10, p, text("$D: " * ch * L"F_{1\%}", 9, :top))
    fs
end

"""
    fig_prp_fixed(mpg, vpg, clr; s = 1)
Plot the proportion of loci fixed of each generation of each scheme in `mpg`. The
shaded areas are the mean standard deviations. Each scheme is plotted in a fixed
color defined in `clr`. The solid lines are the proportion of QTL fixed, the
dashed lines are the proportion of reference fixed, and the dotted lines are the
proportion of chip fixed. Legends are in the bottom right corner.
"""
function fig_prp_fixed(mpg, vpg, clr; c = 1)
    tt = c == 1 ? (637, 3184) : (10000, 50000)
    ylm = begin
        t = collect(xtrm(mpg, :xqtl)) ./ tt[1]
        append!(t, xtrm(mpg, :xref) ./ tt[1])
        append!(t, xtrm(mpg, :xchip) ./ tt[2])
        extrema(t)
    end
    fs, n = [], length(mpg)
    ch = c == 1 ? L"C_{1}" : L"C_{29}"

    for i = 1:n
        fig = plot(
            dpi = 300,
            ylim = ylm,
            size = (600, 400),
            foreground_color_legend = nothing,
            background_color_legend = nothing,
        )
        ks = ord_last(mpg[i], :xqtl)
        for s in ks
            df = mpg[i][s]
            plot!(
                fig,
                df.grt .- 5,
                df.xqtl ./ tt[1],
                fillalpha = 0.2,
                ribbon = vpg[i][s].xqtl ./ tt[1],
                label = uppercase(s[1:2]),
                legend = :right,
                legendfontsize = 6,
                color = clr[s],
            )
        end
        annotate!(fig, 10, ylm[2] * 0.4, text("QTL", 8))
        push!(fs, fig)
        fig = plot(
            dpi = 300,
            ylim = ylm,
            size = (600, 400),
            foreground_color_legend = nothing,
            background_color_legend = nothing,
        )
        ks = ord_last(mpg[i], :xref)
        for s in ks
            df = mpg[i][s]
            plot!(
                fig,
                df.grt .- 5,
                df.xref ./ tt[1],
                fillalpha = 0.2,
                ribbon = vpg[i][s].xref ./ tt[1],
                label = uppercase(s[1:2]),
                legend = :right,
                legendfontsize = 6,
                color = clr[s],
            )
        end
        annotate!(fig, 10, ylm[2] * 0.4, text("Ref.", 8))
        push!(fs, fig)
        fig = plot(
            dpi = 300,
            ylim = ylm,
            size = (600, 400),
            foreground_color_legend = nothing,
            background_color_legend = nothing,
        )
        ks = ord_last(mpg[i], :xchip)
        for s in ks
            df = mpg[i][s]
            plot!(
                fig,
                df.grt .- 5,
                df.xchip ./ tt[2],
                fillalpha = 0.2,
                ribbon = vpg[i][s].xchip ./ tt[2],
                label = uppercase(s[1:2]),
                legend = :right,
                legendfontsize = 6,
                color = clr[s],
            )
        end
        annotate!(fig, 10, ylm[2] * 0.4, text("Chip", 8))
        push!(fs, fig)
    end
    annotate!(fs[1], -2.5, ylm[2] * 0.65, text("Prop. loci fixed", 6, :left, rotation = 90))
    p = ylm[2] * 0.93
    CS = 'A':'Z'
    for i = 1:3
        j = i + 6 * (c - 1)
        annotate!(fs[i], 11, p, text(CS[j] * ": " * ch * L"F_{0.5\%}", 5))
    end
    annotate!(fs[6], 20, 0.01, text("Generation", 6, :bottom))
    for i = 4:6
        j = i + 6 * (c - 1)
        annotate!(fs[i], 12, p, text(CS[j] * ": " * ch * L"F_{1\%}", 5))
    end
    fs
end

"""
    sum_frq_evo(clr, dir, file; cls = :chip)
Summarize the evolution of allele frequency changes during the course of
selection. The MAF are categorized into 399 groups. That is the occurrence
number of of segregating allele 1. This is normalized by the total number of
segregating loci. Only the frequencies of generation 1 and 30 are plotted.
"""
function sum_frq_evo(clr, dir, file; cls = :chip)
    frq, ti, nhp = zeros(399, 2), zeros(Int, 3), 14400
    open(file, "w") do bin
        for r in (1, 4)
            rsm = deserialize("$dir/$r/summary.ser")
            nrpt = rsm.repeat[end]
            for k in keys(clr)
                print(' ', k)
                for i = 1:nrpt
                    tag = lpad(i, 3, '0') #ndigits(nrpt), '0')
                    lmp = deserialize("$dir/$r/$tag-founder.lmp")
                    nlc = begin
                        read!("$dir/$r/$tag-$k.xy", ti)
                        ti[2]
                    end
                    xy = mmap("$dir/$r/$tag-$k.xy", Matrix{Int16}, (nlc, nhp), 24)
                    for s in sum(isodd.(xy[lmp[!, cls], 2001:2400]), dims = 2)
                        (s == 0 || s == 400) && continue
                        frq[s, 1] += 1
                    end
                    for s in sum(isodd.(xy[lmp[!, cls], 14001:14400]), dims = 2)
                        (s == 0 || s == 400) && continue
                        frq[s, 2] += 1
                    end
                end
                write(bin, frq)
                frq .= 0
            end
        end
    end
end

function bak_fig_frq_evo(clr, bin, tag)
    frq = zeros(399, length(clr) * 4)
    #cg1 = length(clr) + 1
    read!(bin, frq)
    fs = []
    #ts = sum(frq[:, 1]) / 100 # Total segregating loci, scale by 100
    vs = vec(sum(frq[:, 2:2:12], dims = 1))
    ks = collect(keys(clr))[sortperm(vs, rev = true)]
    vt = frq[200, 2:2:12]
    kt = collect(keys(clr))[sortperm(vt, rev = true)]
    fig = plot(
        dpi = 300,
        size = (600, 400),
        xtickfontsize = 6,
        ytickfontsize = 6,
        legend = :top,
        legendfontsize = 5,
        legend_columns = 2,
        foreground_color_legend = nothing,
        background_color_legend = nothing,
    )
    ch = occursin("01", bin) ? L"C_{1}" : L"C_{29}"
    A, B = occursin("01", bin) ? ('A', 'B') : ('C', 'D')
    for i = 1:length(ks)
        k = ks[i]
        scatter!(
            fig,
            1:399,
            frq[:, 2clr[k]] / ts,
            label = uppercase(k)[1:2],
            markerstrokewidth = 0,
            ms = 0.6,
            color = clr[k],
        )
        k = kt[i]
        ma = moveavg(frq[:, 2clr[k]] / ts, 5)
        plot!(fig, 3:397, ma, color = clr[k], label = uppercase(k)[1:2])
    end
    scatter!(
        fig,
        1:399,
        frq[:, 1] / ts,
        label = L"G_0",
        markerstrokewidth = 0,
        ms = 0.6,
        color = cg1,
    )
    ma = moveavg(frq[1:399, 1] / ts, 5)
    plot!(fig, 3:397, ma, color = cg1, label = false)
    p = maximum(frq[:, 1] / ts) * 0.9
    annotate!(fig, 50, p, text("$A: " * ch * L"F_{0.5\%}" * ' ' * tag, 6))
    annotate!(fig, -35, p * 1.1, text(L"\times 10^{-2}", 6))
    push!(fs, fig)
    ts = sum(frq[:, 13]) / 100
    vs = vec(sum(frq[:, 14:2:24], dims = 1))
    ks = collect(keys(clr))[sortperm(vs, rev = true)]
    vt = frq[200, 14:2:24]
    kt = collect(keys(clr))[sortperm(vt, rev = true)]
    fig = plot(
        dpi = 300,
        size = (600, 400),
        xtickfontsize = 6,
        ytickfontsize = 6,
        legend = :top,
        legendfontsize = 5,
        legend_columns = 2,
        foreground_color_legend = nothing,
        background_color_legend = nothing,
    )
    for i = 1:length(ks)
        k = ks[i]
        scatter!(
            fig,
            1:399,
            frq[:, 2clr[k]+12] / ts,
            label = uppercase(k)[1:2],
            markerstrokewidth = 0,
            ms = 0.6,
            color = clr[k],
        )
        k = kt[i]
        ma = moveavg(frq[:, 2clr[k]+12] / ts, 5)
        plot!(fig, 3:397, ma, color = clr[k], label = uppercase(k)[1:2])
    end
    scatter!(
        fig,
        1:399,
        frq[:, 13] / ts,
        label = L"G_0",
        markerstrokewidth = 0,
        ms = 0.6,
        color = cg1,
    )
    ma = moveavg(frq[:, 13] / ts, 5)
    plot!(fig, 3:397, ma, label = false, color = cg1)
    p = maximum(frq[:, 13] / ts) * 0.9
    annotate!(fig, 50, p, text("$B: " * ch * L"F_{1\%}" * ' ' * tag, 6))
    annotate!(fig, -35, p * 1.1, text(L"\times 10^{-2}", 6))
    push!(fs, fig)
    fs
end

function fig_frq_evo(clr, bin, tag)
    frq = zeros(399, length(clr) * 4)
    read!(bin, frq)
    fs, nma = [], 25
    vs = vec(sum(frq[:, 2:2:12], dims = 1))
    ks = collect(keys(clr))[sortperm(vs, rev = true)]
    vt = frq[200, 2:2:12]
    kt = collect(keys(clr))[sortperm(vt, rev = true)]
    fig = plot(
        dpi = 300,
        xtickfontsize = 6,
        ytickfontsize = 6,
        legend = :top,
        legendfontsize = 5,
        legend_columns = 2,
        foreground_color_legend = nothing,
        background_color_legend = nothing,
    )
    ch = occursin("01", bin) ? L"C_1" : L"C_{29}"
    A, B = occursin("01", bin) ? ('A', 'B') : ('C', 'D')
    for i = 1:length(ks)
        k = ks[i]
        scatter!(
            fig,
            1:399,
            frq[:, 2clr[k]],
            label = uppercase(k)[1:2],
            markerstrokewidth = 0,
            ms = 0.4,
            color = clr[k],
        )
        k = kt[i]
        ma = movavg(frq[:, 2clr[k]], nma)
        plot!(fig, 1:399, ma.x, color = clr[k], label = uppercase(k)[1:2])
    end
    ylm = ylims(fig)
    annotate!(fig, 55, ylm[2], text("$A: " * ch * L"F_{0.5\%}" * ' ' * tag, 8, :top))
    push!(fs, fig)
    vs = vec(sum(frq[:, 14:2:24], dims = 1))
    ks = collect(keys(clr))[sortperm(vs, rev = true)]
    vt = frq[200, 14:2:24]
    kt = collect(keys(clr))[sortperm(vt, rev = true)]
    fig = plot(
        dpi = 300,
        ylim = ylm,
        xtickfontsize = 6,
        ytickfontsize = 6,
        legend = :top,
        legendfontsize = 5,
        legend_columns = 2,
        foreground_color_legend = nothing,
        background_color_legend = nothing,
    )
    for i = 1:length(ks)
        k = ks[i]
        scatter!(
            fig,
            1:399,
            frq[:, 2clr[k]+12],
            label = uppercase(k)[1:2],
            markerstrokewidth = 0,
            ms = 0.4,
            color = clr[k],
        )
        k = kt[i]
        ma = movavg(frq[:, 2clr[k]+12], nma)
        plot!(fig, 1:399, ma.x, color = clr[k], label = uppercase(k)[1:2])
    end
    annotate!(fig, 55, ylm[2], text("$B: " * ch * L"F_{1\%}" * ' ' * tag, 8, :top))
    push!(fs, fig)
    fs
end

function fig_frfe(mpg, clr; c = 1)
    fgs, fre, m = [], zeros(29, 12), 0
    for i = 1:2
        for k in keys(clr)
            m += 1
            iF = mpg[i][k].iF
            nsir = mpg[i][k].nsire
            ndam = mpg[i][k].ndam
            for i = 7:35
                fr = (iF[i+1] - iF[i]) / (1 - iF[i])
                fe = 1 / 8nsir[i] + 1 / 8ndam[i]
                fre[i-6, m] = fr / fe
            end
        end
    end
    ylm = extrema(fre) .* (0.90, 1.1)
    A, B = c == 1 ? ('A', 'B') : ('C', 'D')
    tag = c == 1 ? L"C_{1}" : L"C_{29}"
    for i = 1:2
        dat = i == 1 ? view(fre, :, 1:6) : view(fre, :, 7:12)
        ks = collect(keys(clr))
        ks = ks[sortperm(vec(sum(dat, dims = 1)), rev = true)]
        fig = plot(
            ylim = ylm,
            dpi = 300,
            legendfontsize = 6,
            foreground_color_legend = nothing,
            background_color_legend = nothing,
        )
        for k in ks
            scatter!(
                fig,
                2:30,
                dat[:, clr[k]],
                label = uppercase(k)[1:2],
                ms = 1,
                markerstrokewidth = 0,
                smooth = true,
                color = clr[k],
            )
            plot!(
                fig,
                2:30,
                dat[:, clr[k]],
                ls = :dot,
                lw = 0.4,
                label = false,
                color = clr[k],
            )
        end
        txt = i == 1 ? "$A: " * tag * L"F_{0.5\%}" : "$B: " * tag * L"F_{1\%}"
        annotate!(fig, 15, ylm[2] * 0.9, text(txt, 6, :bottom))
        push!(fgs, fig)
    end
    if c == 2
        annotate!(
            fgs[1],
            -0.6,
            ylm[2] * 0.95,
            text(L"\frac{\Delta F_R}{\Delta F_E}", 6, :bottom),
        )
        annotate!(fgs[2], 28, ylm[1] * 1.1, text("Generation", 6, :bottom))
    end
    fgs
end

function fig_dbv_df(mpg, clr; c = 1)
    fgs, dbvf, m = [], zeros(29, 12), 0
    for i = 1:2
        for k in keys(clr)
            m += 1
            mtbv = mpg[i][k].mtbv
            iF = mpg[i][k].iF
            dbvf[:, m] =
                (mtbv[8:36] - mtbv[7:35]) ./ (iF[8:36] - iF[7:35]) .* (1 .- iF[7:35])
        end
    end
    ylm = extrema(dbvf) .* (0.90, 1.1)
    A, B = c == 1 ? ('A', 'B') : ('C', 'D')
    tag = c == 1 ? L"C_{1}" : L"C_{29}"
    for i = 1:2
        dat = i == 1 ? view(dbvf, :, 1:6) : view(dbvf, :, 7:12)
        ks = collect(keys(clr))
        ks = ks[sortperm(vec(sum(dat, dims = 1)), rev = true)]
        fig = plot(
            dpi = 300,
            legendfontsize = 6,
            legend = :outerbottomright,
            foreground_color_legend = nothing,
            background_color_legend = nothing,
        )
        for k in ks
            scatter!(
                fig,
                2:30,
                dat[:, clr[k]],
                label = false,
                ms = 1,
                markerstrokewidth = 0,
                color = clr[k],
            )
            plot!(
                fig,
                2:30,
                dat[:, clr[k]],
                ls = :dot,
                lw = 0.4,
                label = false,
                color = clr[k],
            )
            ma = movavg(dat[:, clr[k]], 7)
            plot!(fig, 2:30, ma.x, color = clr[k], label = uppercase(k)[1:2],)
        end
        txt = i == 1 ? "$A: " * tag * L"F_{0.5\%}" : "$B: " * tag * L"F_{1\%}"
        _, p = ylims(fig)
        annotate!(fig, 5, p, text(txt, 8, :center))
        push!(fgs, fig)
    end
    fgs
end

function fig_bv_logf(mpg, clr; c = 1)
    ylm = xtrm(mpg, :mtbv)
    xlm = xtrm(mpg, :logh)
    A, B, ch = c == 1 ? ('A', 'B', L"C_1") : ('C', 'D', L"C_{29}")
    fs, n = [], length(mpg)
    for i = 1:n
        fig = plot(
            dpi = 300,
            ylim = ylm,
            xlim = xlm,
            legendfontsize = 6,
            legend = :right,
            foreground_color_legend = nothing,
            background_color_legend = nothing,
        )
        if i == 1 && c == 1
            ks = ["igocs", "iiocs", "ggocs", "aaocs", "hgocs", "hhocs"]
        elseif i == 2 && c == 1
            ks = ["igocs", "iiocs", "ggocs", "hhocs", "hgocs", "aaocs"]
        elseif i == 1 && c == 2
            ks = ["igocs", "iiocs", "ggocs", "aaocs", "hgocs", "hhocs"]
        else
            ks = ["igocs", "iiocs", "ggocs", "hgocs", "hhocs", "aaocs"]
        end
        for k in ks
            plot!(
                fig,
                mpg[i][k].logh,
                mpg[i][k].mtbv,
                label = uppercase(k)[1:2],
                color = clr[k],
            )
        end
        txt = i == 1 ? "$A: " * ch * L"F_{0.5\%}" : "$B: " * ch * L"F_{1\%}"
        annotate!(fig, 0.05, ylm[2], text(txt, 8, :top))
        push!(fs, fig)
    end
    fs
end

"""
    function tbvdf()
Plot dTBV/dF. Depricated.
"""
function tbvdf()
    fs = fig_dbv_df(a, clr; c = 1)
    append!(fs, fig_dbv_df(c, clr; c = 2))
    annotate!(fs[1], -2.5, -8, text(L"\Delta\mathrm{TBV}/{\Delta F}", 8, :bottom, rotation = 90))
    annotate!(fs[2], 18, -3, text("Generation", 8, :bottom))
    plot(fs..., layout = (2, 2), size = (800, 450), left_margin = 15px)
    savefig("dbv-vs-df.pdf")
    savefig("dbv-vs-df.png")
end

function covdq()
end

"""
    function nprt()
Plot the number of parents. Depricated.
"""
function nprt()
    fs = fig_nprt(a, b, clr; c = 1)
    append!(fs, fig_nprt(c, d, clr; c = 2))
    annotate!(fs[1], -4.2, 0, text("Number of parents", 9, :bottom, rotation = 90))
    annotate!(fs[2], 17, -5, text("Generation", 9, :bottom))
    plot(fs..., layout = (2, 2), size = (800, 450), left_margin = 15px)
    savefig("nprt.pdf")
    savefig("nprt.png")
end

function sup_fig(dir)
    a, b = readSup("$dir/c01")
    c, d = readSup("$dir/c29")
    clr = line_clr(a[1]) # Assign a fixed color to each scheme
    m01, m29, v01, v29 = readGB("$dir/gblup")

    #begin # F_r/F_e
    #    fs = fig_frfe(a, clr; c = 1)
    #    append!(fs, fig_frfe(c, clr; c = 2))
    #    plot(fs..., layout = (2, 2), size = (800, 450))
    #    savefig("fr-vs-fe.pdf")
    #    savefig("fr-vs-fe.png")
    #end

    begin # Figure of number of parents
    end

    begin # Figure of mean total breeding value
        fs = fig_mtbv(a, b, clr; c = 1)
        append!(fs, fig_mtbv(c, d, clr; c = 2))
        annotate!(fs[1], -9, -.5, text("Mean breeding value", 9, :bottom, rotation = 90))
        annotate!(fs[2], 15, -1.1, text("Generation", 9, :bottom))
        plot(fs..., layout = (2, 2), size = (800, 450), left_margin = 15px) #, bottom_margin = 15px)
        savefig("mtbv.pdf")
        savefig("mtbv.png")
    end

    # begin # Figure of space between breeding ceiling and floor
    #     fs = fig_space(a, b, clr; p = -11, c = 1)
    #     append!(fs, fig_space(c, d, clr; p = -11, c = 2))
    #     plot(fs..., layout = (2, 2), size = (800, 450))
    #     savefig("space.pdf")
    #     savefig("space.png")
    # end

    begin # figure ceiling
        fs = fig_ceiling(a, b, clr; c = 1)
        append!(fs, fig_ceiling(c, d, clr; c = 2))
        annotate!(fs[1], -10, 13, text("Breeding ceiling", 9, :bottom, rotation = 90))
        annotate!(fs[2], 15, 10, text("Generation", 9, :bottom))
        plot(fs..., layout = (2, 2), size = (800, 450), left_margin = 15px)
        savefig("ceiling.pdf")
        savefig("ceiling.png")
    end

    begin # Figure of genic and genetic variance
        fs = fig_vg(a, b, clr; c = 1)
        append!(fs, fig_vg(c, d, clr; c = 2))
        annotate!(
            fs[1],
            -12.7,
            0.3,
            text("Genic and genetic variance", 9, :top, rotation = 90),
        )
        annotate!(fs[2], 15, 0.227, text("Generation", 9, :bottom))
        plot(fs..., layout = (2, 2), size = (800, 450), left_margin = 15px)
        savefig("vg.pdf")
        savefig("vg.png")
    end

    begin # figure of inbreeding
        fs = fig_inbreeding(a, b, clr; c = 1)
        append!(fs, fig_inbreeding(c, d, clr; c = 2))
        annotate!(fs[1], -12.5, -0.05, text("Inbreeding by IBD loci ratio", 9, :top, rotation = 90))
        annotate!(fs[2], 15, -0.09, text("Generation", 9, :bottom))
        plot(fs..., layout = (2, 2), size = (800, 450), left_margin = 15px)
        savefig("inbreeding.pdf")
        savefig("inbreeding.png")
    end

    begin # Figure of fixed QTL
        fs = fig_fxqtl(a, b, clr; c = 1)
        append!(fs, fig_fxqtl(c, d, clr; c = 2))
        annotate!(fs[1], -29, -25, text("Number of fixed QTL", 9, :top, rotation = 90))
        annotate!(fs[6], 53, -520, text("Generation", 9, :bottom))
        plot(fs..., layout = (2, 4), size = (800, 450), left_margin = 15px)
        savefig("fxqtl.pdf")
        savefig("fxqtl.png")
    end

    # begin # Figure of proportion loci fixed
    #     fs = fig_prp_fixed(a, b, clr; c = 1)
    #     append!(fs, fig_prp_fixed(c, d, clr; c = 2))
    #     plot(fs..., layout = (2, 6), size = (800, 450))
    #     savefig("prp-fixed.pdf")
    #     savefig("prp-fixed.png")
    # end

    begin # Figure of covariance between q0 and qt
        fs = fig_covdq(a, b, clr)
        append!(fs, fig_covdq(c, d, clr; c = 2))
        ylm = xtrm(a, :covdq2)
        yx, yy = -13.8, ylm[2] - 0.5(ylm[2] - ylm[1])
        annotate!(fs[1], yx, -0.37, text(L"\mathrm{Cov}(q_0, q_t)", 10, :top, rotation = 90))
        annotate!(fs[2], 15, -0.38, text("Generation", 9, :bottom))
        plot(fs..., layout = (2, 2), size = (800, 450), left_margin = 15px)
        savefig("covdq.pdf")
        savefig("covdq.png")
        plot!(fs[1], -5:30, m01.covdq2, ls = :dot, color = "black", label = "GB")
        plot!(fs[3], -5:30, m29.covdq2, ls = :dot, color = "black", label = "GB")
        plot(fs..., layout = (2, 2), size = (800, 450), left_margin = 15px)
        savefig("covdq+g.pdf")
        savefig("covdq+g.png")
    end

    begin # Evolution of allele frequency
        fs = []
        cls = ("chip", "dark", "growth")
        tag = ("chip", "ref.", "QTL")
        for cn in ("01", "29")
            for i = 1:3
                isfile("ch-$cn-$(cls[i]).bin") || sum_frq_evo(
                    clr,
                    "$dir/c$cn",
                    "ch-$cn-$(cls[i]).bin";
                    cls = Symbol(cls[i]),
                )
                append!(fs, fig_frq_evo(clr, "ch-$cn-$(cls[i]).bin", tag[i]))
            end
        end
        annotate!(fs[1], -65, -0.5, text("Number of loci", 9, :bottom, rotation = 90))
        annotate!(fs[2], 200, -120, text("Allele 1 frequency of a locus", 8, :bottom))
        plot(fs[[1, 2, 7, 8]]..., layout = (2, 2), size = (800, 400), left_margin = 15px)
        savefig("chip-frq-evo.pdf")
        savefig("chip-frq-evo.png")
        annotate!(fs[3], -60, -0.5, text("Number of loci", 9, :bottom, rotation = 90))
        annotate!(fs[4], 200, -22, text("Allele 1 frequency of a locus", 8, :bottom))
        plot(fs[[3, 4, 9, 10]]..., layout = (2, 2), size = (800, 400), left_margin = 15px)
        savefig("ref-frq-evo.pdf")
        savefig("ref-frq-evo.png")
        annotate!(fs[5], -60, -0.5, text("Number of loci", 9, :bottom, rotation = 90))
        annotate!(fs[6], 200, -25, text("Allele 1 frequency of a locus", 8, :bottom))
        plot(fs[[5, 6, 11, 12]]..., layout = (2, 2), size = (800, 400), left_margin = 15px)
        savefig("qtl-frq-evo.pdf")
        savefig("qtl-frq-evo.png")
    end

    begin # figure of breeding value vs. -log of homozygosity
        fs = fig_bv_logf(a, clr; c = 1)
        append!(fs, fig_bv_logf(c, clr; c = 2))
        annotate!(fs[1], -.045, -0.4, text("Breeding value", 9, :bottom, rotation = 90))
        annotate!(fs[2], 0.27, -1.2, text(L"-\log(1 - F_{\mathrm{IBD}})", 9, :bottom))
        plot(fs..., layout = (2, 2), size = (800, 450), left_margin = 15px)
        savefig("bv-logf.pdf")
        savefig("bv-logf.png")
    end
end

function newfig()
    a, b = readSup("c01")
    c, d = readSup("c29")
    clr = line_clr(a[1]) # Assign a fixed color to each scheme
    m01, m29, v01, v29 = readGB("gblup")

    fs = fig_covdq(a, b, clr)
    append!(fs, fig_covdq(c, d, clr; c = 2))
    ylm = xtrm(a, :covdq2)
    yx, yy = -13.8, ylm[2] - 0.5(ylm[2] - ylm[1])
    annotate!(fs[1], yx, -0.37, text(L"\mathrm{Cov}(q_0, q_t)", 10, :top, rotation = 90))
    annotate!(fs[2], 15, -0.38, text("Generation", 9, :bottom))
    plot(fs..., layout = (2, 2), size = (800, 450), left_margin = 15px)
    savefig("covdq-ref.pdf")
    savefig("covdq-ref.png")
    plot!(fs[1], -5:30, m01.covdq2, ls = :dot, color = "black", label = "GB")
    plot!(fs[3], -5:30, m29.covdq2, ls = :dot, color = "black", label = "GB")
    plot(fs..., layout = (2, 2), size = (800, 450), left_margin = 15px)
    savefig("covdq+g-ref.pdf")
    savefig("covdq+g-ref.png")
end