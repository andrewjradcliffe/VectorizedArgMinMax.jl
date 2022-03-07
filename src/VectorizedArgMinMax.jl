module VectorizedArgMinMax

using Polyester
using LoopVectorization
import LoopVectorization.length_one_axis

export vargmax, vargmin, vtargmax, vtargmin

include("vargmax.jl")

export vfindmax, vfindmin, vtfindmax, vtfindmin

include("vfindmax.jl")

end
