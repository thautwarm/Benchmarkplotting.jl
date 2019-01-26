using Benchmarkplotting
using Gadfly
using Statistics

cases = [
    :range100   => 1:100,
    :range10000 => 1:10000,
    :array100   => [(1:100)...],
    :array10000 => [(1:10000)...],
]

implementations = [
    :map       =>
        function (x)
            map(e -> e + 1, x)
        end,
    :list_comp =>
        function (x)
            [e + 1 for e in x]
        end,
    :handwritten_loop =>
        function(x)
            i = 1
            arr = []
            while (iter = iterate(x, i); iter !== nothing)
                e, i = iter
                push!(arr, e + 1)
            end
            arr
        end,
    :handwritten_loop_prealloc =>
        function(x)
            i = 1
            arr = fill(0, length(x))
            while (iter = iterate(x, i); iter !== nothing)
                e, i = iter
                push!(arr, e + 1)
            end
            arr
    end,
    :for_iter =>
        function(x)
            arr = []
            for e in x
                push!(arr, e + 1)
            end
            arr
        end
]

theme = Theme(
    guide_title_position = :left,
    colorkey_swatch_shape = :circle,
    minor_label_font = "Consolas",
    major_label_font = "Consolas",
    point_size=6px
)


criterion(benchmark_result) = (time = mean(benchmark_result.times), )

df = bcompare(criterion, cases, implementations, quiet=false)
res = report(:time, df, Scale.y_log10, theme)
@info res[2]
draw(SVG("example.svg", 9inch, 6inch), res[1])