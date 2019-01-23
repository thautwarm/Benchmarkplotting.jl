module Benchmarkplotting

using BenchmarkTools
using Gadfly
using DataFrames
using Printf
using StatsBase
using Statistics

export bcompare, report

function bcompare(criterion :: Function,
                  data :: Vector{Pair{Symbol, T}},
                  implementations :: Vector{Pair{Symbol, Function}}, quiet :: Bool = false) where T
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
            res = criterion(@benchmark $action())
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
                layouts...
                ; first :: Union{Symbol, Nothing} = nothing)
    result = copy(result)
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
        push_priority(case_name)
    end

    casemean = DataFrame(case=case_names, geomean=means, priority=priorities)
    benchmarks = join(result, casemean, on=:case)

    benchmarks[:, :case] = map(x -> case_names_with_unit[x], benchmarks[:, :case])
    casemean[:, :case] = map(x -> case_names_with_unit[x], casemean[:, :case])

    sort!(benchmarks, [:priority, :geomean])
    sort!(casemean, [:priority, :geomean])
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