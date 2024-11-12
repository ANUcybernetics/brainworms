defmodule BrainwormsTest do
  use ExUnit.Case

  doctest Brainworms

  test "end-to-end test" do
    model = Brainworms.Model.new([4])
    {inputs, targets} = Brainworms.Train.training_set()
    params = Brainworms.Train.run(model, inputs, targets)

    dense_0_sum = Map.get(params, :data)["dense_0"]["kernel"] |> Nx.sum()
    dense_1_sum = Map.get(params, :data)["dense_1"]["kernel"] |> Nx.sum()

    assert dense_0_sum != 0.0
    assert dense_1_sum != 0.0
  end
end
