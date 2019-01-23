module Benchmarkplotting

using BenchmarkTools
using Gadfly
using DataFrames
using StatsBase
using Statistics

export bcompare, report

function bcompare(criterion :: Function,
                  data :: Vector{Pair{Symbol, Any}},
                  implementations :: Vector{Pair{Symbol, Function}})
    rows = []
    for (impl_name, impl) in implementations
        for (case_name, case) in data
            action = :($impl($case))
            res = criterion(@benchmark $action)
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
                first :: Union{Symbol, Nothing} = nothing,
                layouts...)
    impls = []
    means = []
    priorities = []
    push_priority = first === nothing ?
        function (_)
            push!(priorities, 2)
        end :
        function (x)
            push!(priorities, x === first ? 1 : 2)
        end

    case_names  = collect(Set(result.case))
    for case_name in case_names
        data = result[result[:case] .== case_name, :]
        gmean = geomean(data[field])
        push!(means, gmean)
        push_priority(case_name)
    end

    casemean = DataFrame(case=case_names, geomean=means, priority=priorities)
    benchmarks = join(result, casemean, on=:case)
    sort!(benchmarks, [:priority, :geomean])
    sort!(casemean, [:priority, :geomean])
    ymax = maximum(benchmarks[field])
    plot(benchmarks,
        x = :case,
        y = field,
        color=:implementation,
        layouts...,
        Guide.ylabel(nothing),
        Guide.xlabel(nothing),
        Coord.Cartesian(ymin=0, ymax=ymax),
        Theme(
            guide_title_position = :left,
            colorkey_swatch_shape = :circle,
            minor_label_font = "Consolas",
            major_label_font = "Consolas"
         ),
    ), casemean[:, 1:2]

end

end # module
