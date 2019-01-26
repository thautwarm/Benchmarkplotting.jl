module Benchmarkplotting

using BenchmarkTools
using Gadfly
using DataFrames
using Printf
using StatsBase
using Statistics

export bcompare, report

get_names(::NamedTuple{Names, T}) where {Names, T} = Names

function bcompare(criterion :: Function,
                  data :: Vector{Pair{Symbol, T}},
                  implementations :: Vector{Pair{Symbol, Function}};
                  repeat :: Int = 2,
                  quiet :: Bool = false) where T
    rows = []
    for (impl_name, impl) in implementations
        for (case_name, case) in data
            # avoid the evaluation of case(if it's of AST types)
            @inline function action()
                impl(case)
            end
            if !quiet
                @info impl_name case_name action()
            end
            fst_test = criterion(@benchmark $action())
            fields = get_names(fst_test)
            repeats = [criterion(@benchmark $action) for _ in 1:repeat]
            res = Dict([field => fst_test[field] for field in fields])
            for field in fields
                res[field] = (res[field] + sum([it[field] for it in repeats])) ./ (1 + repeat)
            end
            row = (implementation = impl_name,
                   case = case_name,
                   res...)
            push!(rows, row)
        end
    end
    DataFrame(rows)
end

function report(field :: Symbol,
                result :: DataFrame,
                layouts...)
    result = copy(result)
    impls = []
    means = []

    case_names  = unique(result.case)
    case_names_with_unit = Dict()
    for case_name in case_names
        idx = result[:case] .== case_name
        tmp = result[idx, field]
        minval = minimum(tmp)
        tmp = tmp ./ minval
        result[idx, field] = tmp
        gmean = geomean(tmp)
        push!(means, gmean)
        minval_repr = @sprintf "%.3f" minval
        case_names_with_unit[case_name] = Symbol(case_name, "(min: $minval_repr)")
    end

    casemean = DataFrame(case=case_names, geomean=means)
    benchmarks = join(result, casemean, on=:case)

    benchmarks[:, :case] = map(x -> case_names_with_unit[x], benchmarks[:, :case])
    casemean[:, :case] = map(x -> case_names_with_unit[x], casemean[:, :case])

    plot(benchmarks,
        x = :case,
        y = field,
        color=:implementation,
        Guide.ylabel(nothing),
        Guide.xlabel(nothing),
        Theme(
            guide_title_position = :left,
            colorkey_swatch_shape = :circle,
            minor_label_font = "Consolas",
            major_label_font = "Consolas"
         ),
         layouts...,
    ), casemean[:, 1:2]

end

end # module